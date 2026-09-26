"use strict";

const { CODES, httpError } = require("../util/errors");
const { assertObject, assertDateKey, assertString } = require("../util/validation");
const { Timestamp } = require("../firebase");
const identity = require("../identity");
const sessionMachine = require("../domain/sessionMachine");
const core = require("./attendance_core");
const { writeAudit } = require("./admin_ops");

/**
 * attendance.review — supervisor decision (approved / rejected / flagged).
 * Only the student's assigned supervisor may review. The session machine is
 * followed exactly (submitted → underReview before approve/reject; flagged is
 * directly reachable from submitted).
 */
async function reviewHandler(deps, context, data) {
  assertObject(data, "payload");
  const supervisor = await identity.requireSupervisor(deps.db, context);
  const sessionId = String(data.sessionId);
  assertDateKey(sessionId, "sessionId");
  const studentId = String(data.studentId || "");
  if (!studentId) {
    throw httpError(CODES.INVALID_ARGUMENT, "studentId is required.");
  }
  const decision = String(data.decision);
  if (!["approved", "rejected", "flagged"].includes(decision)) {
    throw httpError(CODES.INVALID_ARGUMENT, "decision must be approved|rejected|flagged.");
  }
  const note = typeof data.note === "string" ? data.note.trim() : "";
  assertString(note, "note", { allowEmpty: true, max: 2000 });

  const sref = core.sessionRef(deps.db, studentId, sessionId);

  const outcome = await deps.db.runTransaction(async (tx) => {
    const snap = await tx.get(sref);
    if (!snap.exists) {
      throw httpError(CODES.NOT_FOUND, `Session ${sessionId} not found.`);
    }
    const session = snap.data();

    const assignment = await identity.readAssignment(deps.db, studentId);
    if (!assignment || assignment.supervisorId !== supervisor.entityId) {
      throw httpError(
        CODES.PERMISSIONS,
        "Session belongs to a student outside your assignment."
      );
    }

    const status = session.status;
    const now = new Date();
    let next;
    if (decision === "approved") {
      if (status === sessionMachine.SessionStatus.submitted) {
        next = sessionMachine.approve(sessionMachine.startReview(session));
      } else if (
        status === sessionMachine.SessionStatus.underReview ||
        status === sessionMachine.SessionStatus.flagged
      ) {
        next = sessionMachine.approve(session);
      } else {
        throw httpError(
          CODES.FAILED_PRECONDITION,
          `Cannot approve a ${status} session.`
        );
      }
    } else if (decision === "rejected") {
      if (status === sessionMachine.SessionStatus.submitted) {
        next = sessionMachine.reject(sessionMachine.startReview(session), {
          reason: note || "Rejected by supervisor.",
          now,
        });
      } else if (
        status === sessionMachine.SessionStatus.underReview ||
        status === sessionMachine.SessionStatus.flagged
      ) {
        next = sessionMachine.reject(session, {
          reason: note || "Rejected by supervisor.",
          now,
        });
      } else {
        throw httpError(
          CODES.FAILED_PRECONDITION,
          `Cannot reject a ${status} session.`
        );
      }
    } else {
      if (
        status !== sessionMachine.SessionStatus.submitted &&
        status !== sessionMachine.SessionStatus.underReview &&
        status !== sessionMachine.SessionStatus.flagged
      ) {
        throw httpError(
          CODES.FAILED_PRECONDITION,
          `Cannot flag a ${status} session.`
        );
      }
      next = sessionMachine.flag(session, {
        reason: note || "Flagged for review.",
        now,
      });
    }

    await tx.set(sref, { ...next, updatedAt: now });
    const auditId = await writeAudit({
      db: deps.db,
      tx,
      data: {
        action: `review.${decision}`,
        actorUid: supervisor.uid,
        actorRole: supervisor.role,
        actorEntityId: supervisor.entityId,
        studentId,
        dateKey: sessionId,
        before: {
          status: session.status,
          review: session.review,
          verifiedHours: session.verifiedHours ?? 0,
        },
        after: { status: next.status, review: next.review, verifiedHours: next.verifiedHours ?? 0 },
        reason: note || next.reason || null,
      },
    });
    return {
      status: next.status,
      review: next.review,
      note: note || next.reason || null,
      auditId,
      decidedAt: now.toISOString(),
    };
  });

  return outcome;
}

/**
 * attendance.myQueue — the supervisor's today queue built server-side from
 * submitted / flagged sessions of the supervisor's assigned students. The
 * client can never enumerate other students' sessions.
 */
async function myQueueHandler(deps, context, _data) {
  const supervisor = await identity.requireSupervisor(deps.db, context);
  const now = new Date();
  const todayKey = core.utcDateKey(now);

  const [assignmentsSnap, studentsSnap] = await Promise.all([
    deps.db.collection("assignments").where("supervisorId", "==", supervisor.entityId).get(),
    deps.db.collection("students").get(),
  ]);

  const students = new Map();
  for (const doc of studentsSnap.docs) {
    students.set(doc.id, doc.data().name || doc.id);
  }

  const items = [];
  for (const doc of assignmentsSnap.docs) {
    const assignment = { id: doc.id, ...doc.data() };
    const sref = core.sessionRef(deps.db, doc.id, todayKey);
    const sessionSnap = await deps.db.doc(sref.path).get();
    if (!sessionSnap.exists) continue;
    const session = sessionSnap.data();
    const isQueued =
      session.status === sessionMachine.SessionStatus.submitted ||
      session.status === sessionMachine.SessionStatus.flagged;
    if (!isQueued) continue;

    const location = deps.db.doc(`locations/${assignment.locationId}`).get()
      .then((l) => (l.exists ? l.data().name || l.id : l.id))
      .catch(() => assignment.locationId);

    const type =
      session.status === sessionMachine.SessionStatus.flagged
        ? "attendanceAudit"
        : "checkOut";
    items.push({
      id: todayKey,
      studentId: doc.id,
      studentName: students.get(doc.id) || doc.id,
      location: await location,
      type,
      submittedAt: session.updatedAt?.toDate?.().toISOString?.() ?? now.toISOString(),
      status: session.review === "flagged" ? "flagged" : "pending",
      summary:
        session.reason ||
        (type === "checkOut"
          ? "Duty recorded — verify the check-out (selfie + GPS)."
          : "Supervisor follow-up requested."),
      evidenceTime: session.checkOutVerifiedAt?.toDate?.().toISOString?.() ?? null,
    });
  }

  items.sort((a, b) => (a.submittedAt < b.submittedAt ? 1 : -1));
  return { items };
}

/**
 * attendance.getEvidence — short-lived signed URL for supervisor evidence
 * inspection. Clients never read the evidence bucket directly.
 */
async function getEvidenceHandler(deps, context, data) {
  assertObject(data, "payload");
  const supervisor = await identity.requireSupervisor(deps.db, context);
  const sessionId = String(data.sessionId);
  assertDateKey(sessionId, "sessionId");
  const studentId = String(data.studentId || "");
  if (!studentId) {
    throw httpError(CODES.INVALID_ARGUMENT, "studentId is required.");
  }
  const kind = String(data.kind);
  if (!["checkin", "checkout"].includes(kind)) {
    throw httpError(CODES.INVALID_ARGUMENT, "kind must be checkin|checkout.");
  }

  const sref = core.sessionRef(deps.db, studentId, sessionId);
  const snap = await deps.db.doc(sref.path).get();
  if (!snap.exists) {
    throw httpError(CODES.NOT_FOUND, `Session ${sessionId} not found.`);
  }
  const session = snap.data();

  const assignment = await identity.readAssignment(deps.db, studentId);
  if (!assignment || assignment.supervisorId !== supervisor.entityId) {
    throw httpError(CODES.PERMISSIONS, "Session is outside your assignment.");
  }

  const path =
    kind === "checkin" ? session.evidenceCheckInPath : session.evidenceCheckOutPath;
  if (!path) {
    throw httpError(CODES.NOT_FOUND, `No ${kind} evidence recorded for this session.`);
  }

  let url;
  try {
    const [signed] = await deps.storage.bucket().file(path).getSignedUrl({
      action: "read",
      expires: Date.now() + 15 * 60 * 1000,
    });
    url = signed;
  } catch (_err) {
    const isEmulator = !!(
      process.env.FIREBASE_STORAGE_EMULATOR_HOST ||
      process.env.FIREBASE_FUNCTIONS_EMULATOR === "true" ||
      process.env.EMULATOR_INTEGRATION === "1"
    );
    if (!isEmulator) {
      // Outside the emulator a signed URL is the only safe mechanism (storage
      // rules deny direct reads). Never fall back to a hard-coded URL.
      throw httpError(
        CODES.INTERNAL,
        "Evidence URL signing is unavailable; retry later."
      );
    }
    // Emulator fallback: no service-account creds are available to mint a
    // signed URL, and the emulator serves the object over its REST API.
    const name = deps.storage.bucket().name || "default";
    url = `http://127.0.0.1:9199/${name}/${path.split("/").map(encodeURIComponent).join("/")}?alt=media`;
  }
  return { url, expiresAt: new Date(Date.now() + 15 * 60 * 1000).toISOString() };
}

module.exports = { reviewHandler, myQueueHandler, getEvidenceHandler };