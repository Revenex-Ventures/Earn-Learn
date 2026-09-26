"use strict";

const { CODES, httpError } = require("../util/errors");
const {
  assertObject,
  assertDateKey,
  assertFiniteNumber,
  assertString,
} = require("../util/validation");
const { Timestamp } = require("../firebase");
const identity = require("../identity");
const core = require("./attendance_core");
const sessionMachine = require("../domain/sessionMachine");
const { Flags } = require("../domain/flags");

const CORRECTION_ACTIONS = new Set(["resubmit", "adjustHours", "cancel"]);
const RECONCILE_CAP = 250;

/**
 * Deterministic, replay-safe audit doc id. Re-runs of the same request with
 * the same payload land on the same row instead of duplicating.
 */
function auditDocId(action, studentId, dateKey, requestId) {
  const base = [action.replace(/[^A-Za-z0-9_]/g, "_"), studentId, dateKey]
    .filter(Boolean)
    .join("_");
  const extra =
    requestId && /^[A-Za-z0-9_-]{1,64}$/.test(requestId)
      ? requestId
      : `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`;
  return `${base}_${extra}`.slice(0, 180);
}

/**
 * Append-only, server-only audit trail. Every privileged mutation (review,
 * manual correction, reconciliation) records: actor, target, before/after,
 * reason and an idempotency key.
 */
async function writeAudit({ db, tx, data }) {
  const ref = db.collection("auditLogs").doc(
    auditDocId(data.action, data.studentId ?? null, data.dateKey ?? null, data.requestId)
  );
  const doc = { ...data, actorUid: data.actorUid, createdAt: Timestamp.now() };
  if (tx) {
    tx.set(ref, doc);
    return ref.id;
  }
  await ref.set(doc);
  return ref.id;
}

const snapshotOf = (session) => ({
  status: session?.status ?? null,
  review: session?.review ?? null,
  verifiedHours: session?.verifiedHours ?? 0,
  evidenceCheckInPath: session?.evidenceCheckInPath ?? null,
  evidenceCheckOutPath: session?.evidenceCheckOutPath ?? null,
});

/**
 * admin.manualAttendanceCorrection — a documented, audited edge-case fix for
 * one session by an active administrator. Reason is mandatory: every override
 * leaves an audit row explaining the human judgement.
 */
async function manualAttendanceCorrection(deps, context, data) {
  const admin = await identity.requireAdmin(deps.db, context);
  assertObject(data, "payload");

  const studentId = String(data.studentId ?? "").trim();
  const dateKey = String(data.sessionId ?? "");
  assertDateKey(dateKey, "sessionId");
  if (!studentId) {
    throw httpError(CODES.INVALID_ARGUMENT, "studentId is required.");
  }
  const action = String(data.action ?? "");
  if (!CORRECTION_ACTIONS.has(action)) {
    throw httpError(
      CODES.INVALID_ARGUMENT,
      `action must be one of: ${[...CORRECTION_ACTIONS].join(", ")}.`
    );
  }
  assertString(data.reason, "reason", { allowEmpty: false, max: 2000 });
  const reason = String(data.reason).trim();
  const requestId = data.requestId ? String(data.requestId) : null;

  // Validate adjustHours up-front so caller gets a clear error before any write.
  let verifiedHours = null;
  if (action === "adjustHours") {
    assertFiniteNumber(data.verifiedHours, "verifiedHours");
    verifiedHours = Number(data.verifiedHours);
    if (verifiedHours < 0 || verifiedHours > 24) {
      throw httpError(
        CODES.INVALID_ARGUMENT,
        "verifiedHours must be within 0..24."
      );
    }
    verifiedHours = Math.round(verifiedHours * 100) / 100;
  }

  const result = await deps.db.runTransaction(async (tx) => {
    const sref = core.sessionRef(deps.db, studentId, dateKey);
    const snap = await tx.get(sref);
    if (!snap.exists) {
      throw httpError(
        CODES.NOT_FOUND,
        `No attendance session for ${studentId} on ${dateKey}.`
      );
    }
    const session = snap.data();
    const before = snapshotOf(session);
    const now = Timestamp.now();

    let next;
    if (action === "resubmit") {
      next = {
        ...session,
        status: sessionMachine.SessionStatus.submitted,
        review: "pending",
        reason,
        updatedAt: now,
      };
    } else if (action === "cancel") {
      try {
        next = sessionMachine.go(session, sessionMachine.SessionStatus.cancelled, {
          reason,
          now: now.toDate(),
        });
      } catch (_err) {
        next = {
          ...session,
          status: sessionMachine.SessionStatus.cancelled,
          review: "pending",
          reason,
          updatedAt: now,
        };
      }
    } else {
      next = { ...session, verifiedHours, reason, updatedAt: now };
      next.flags = [...new Set([...(next.flags ?? []), Flags.MANUAL_ADJUSTMENT])];
    }

    tx.set(sref, next);
    const auditId = await writeAudit({
      db: deps.db,
      tx,
      data: {
        action: `manual_correction.${action}`,
        actorUid: admin.uid,
        actorRole: admin.role,
        actorEntityId: admin.entityId,
        studentId,
        dateKey,
        requestId,
        before,
        after: snapshotOf(next),
        reason,
      },
    });

    return {
      studentId,
      sessionId: dateKey,
      action,
      requestId,
      status: next.status,
      review: next.review ?? null,
      verifiedHours: next.verifiedHours ?? 0,
      updatedAt: now.toDate().toISOString(),
      auditId,
    };
  });

  return { ok: "applied", ...result };
}

/**
 * admin.reconcileAttendance — a supervisor/admin tool that scans a day's
 * sessions, derives evidence-integrity flags server-side, labels suspect
 * sessions, and records the run in the audit log. Reads-only on sessions;
 * the only mutation is the session's flags + reconciliation stamp.
 */
async function reconcileAttendance(deps, context, data) {
  const admin = await identity.requireAdmin(deps.db, context);
  assertObject(data, "payload");

  const dateKey =
    data.date != null
      ? core.dateFromPayload(data, "date")
      : core.utcDateKey(new Date());
  const scopedStudent = data.studentId ? String(data.studentId).trim() : null;

  const assignments = [];
  if (scopedStudent) {
    const one = await identity.readAssignment(deps.db, scopedStudent);
    if (one) assignments.push(one);
  } else {
    const snap = await deps.db.collection("assignments").get();
    assignments.push(...snap.docs.map((d) => d.data()));
    if (assignments.length > RECONCILE_CAP) {
      assignments.length = RECONCILE_CAP;
    }
  }

  const flagged = [];
  let scanned = 0;
  const runId = `${dateKey}_${Date.now().toString(36)}`;
  const detectedAt = Timestamp.now();
  const nowIso = detectedAt.toDate().toISOString();

  for (const assignment of assignments) {
    const studentId = assignment.studentId;
    const sref = core.sessionRef(deps.db, studentId, dateKey);
    const snap = await deps.db.doc(sref.path).get();
    if (!snap.exists) continue;
    const session = snap.data();
    scanned += 1;

    const flags = [];
    if (!assignment || assignment.status !== "active") {
      flags.push(Flags.INVALID_ASSIGNMENT);
    }
    const location = assignment
      ? await identity.readLocation(deps.db, assignment.locationId)
      : null;
    if (!location || location.status !== "active") {
      flags.push(Flags.INVALID_LOCATION);
    }

    if (session.status === "working" || session.status === "checkOutPending") {
      flags.push(Flags.MISSED_CHECKOUT);
    }
    if (session.status === "approved") {
      const noHours = Number(session.verifiedHours ?? 0) <= 0;
      const noCheckOut =
        !session.evidenceCheckOutPath || !session.evidenceCheckInPath;
      if (noHours || noCheckOut) {
        flags.push(Flags.INCONSISTENT_VERIFICATION);
      }
    }
    if (Array.isArray(assignment.shiftWindows) && assignment.shiftWindows.length) {
      const plannedHrs =
        assignment.shiftWindows.reduce(
          (acc, w) => acc + (w.endMin - w.startMin),
          0
        ) / 60;
      if (plannedHrs > 0 && Number(session.verifiedHours ?? 0) > plannedHrs + 0.25) {
        flags.push(Flags.IMPOSSIBLE_DURATION);
      }
    }

    // Sample-derived evidence: union the per-sample flags observed for the day.
    const sampleSnap = await deps.db
      .collection("attendanceSamples")
      .doc(studentId)
      .collection(dateKey)
      .orderBy("recordedAt", "desc")
      .limit(100)
      .get();
    for (const doc of sampleSnap.docs) {
      const s = doc.data();
      if (Array.isArray(s.flags)) {
        for (const f of s.flags) if (!flags.includes(f)) flags.push(f);
      }
    }

    if (!flags.length) continue;

    const merged = [...new Set([...(session.flags ?? []), ...flags])];
    const now = Timestamp.now();
    await deps.db.doc(sref.path).set(
      {
        flags: merged,
        reconciliation: { runId, detectedAt: now, flags },
        updatedAt: now,
      },
      { merge: true }
    );
    flagged.push({ studentId, sessionId: dateKey, flags, review: session.review ?? null });
  }

  const auditId = await writeAudit({
    db: deps.db,
    data: {
      action: "reconcile.attendance",
      actorUid: admin.uid,
      actorRole: admin.role,
      actorEntityId: admin.entityId,
      studentId: scopedStudent,
      dateKey,
      requestId: runId,
      before: { scannedApplications: scanned },
      after: { flagged: flagged.length },
      reason: "Scheduled evidence-integrity reconciliation run.",
    },
  });

  return {
    runId,
    dateKey,
    scanned,
    flagged,
    clean: scanned - flagged.length,
    detectedAt: nowIso,
    auditId,
  };
}

module.exports = {
  writeAudit,
  manualAttendanceCorrection,
  reconcileAttendance,
  auditDocId,
};