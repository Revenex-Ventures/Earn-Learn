"use strict";

const { Timestamp } = require("../firebase");
const sessionMachine = require("../domain/sessionMachine");
const { computeVerifiedHours, windowEndMs } = require("../domain/hours");
const core = require("./attendance_core");

/**
 * Nightly attendance sweep. For every student with a duty on [dateKey]:
 *
 *   scheduled / checkInPending past the last window end  →  missed
 *   working        past the last window end              →  submitted at window
 *                                                          end (auto-finalize)
 *   checkOutPending past the last window end             →  submitted at window
 *                                                          end if evidence is
 *                                                          uploaded, else missed
 *
 * Missing evidence is never auto-verified: sessions with unresolved evidence
 * are marked missed (unattended), never granted hours.
 */
async function sweepAttendance({ db, storage, dateKey }) {
  const target =
    dateKey && /^\d{4}-\d{2}-\d{2}$/.test(dateKey)
      ? dateKey
      : core.utcDateKey(new Date());

  const studentsSnap = await db.collection("students").get();
  const transitions = { missed: 0, submitted: 0, skipped: 0 };
  const report = [];

  for (const studentDoc of studentsSnap.docs) {
    const studentId = studentDoc.id;
    const assignment = await requireAssignmentQuiet(db, studentId);
    if (!assignment) {
      transitions.skipped += 1;
      continue;
    }
    const windows = core.planWindows(assignment, target);
    if (windows.length === 0) {
      transitions.skipped += 1;
      continue;
    }
    const maxEndMin = Math.max(...windows.map((w) => w.endMin));
    const endIso = endOfWindowIso(target, maxEndMin);
    const nowMs = Date.now();
    if (new Date(endIso).getTime() > nowMs) {
      transitions.skipped += 1;
      continue;
    }

    const sref = core.sessionRef(db, studentId, target);
    const snap = await sref.get();
    if (!snap.exists) {
      // No session was ever initiated — the day is unattended.
      await createMissed(db, studentId, target, windows);
      report.push({ studentId, status: "missed" });
      transitions.missed += 1;
      continue;
    }
    const session = snap.data();
    const status = session.status;

    let next = null;
    if (status === sessionMachine.SessionStatus.scheduled) {
      next = sessionMachine.markMissed(session, {
        reason: "Shift window ended without a check-in.",
        now: new Date(),
      });
    } else if (status === sessionMachine.SessionStatus.checkInPending) {
      next = sessionMachine.markMissed(session, {
        reason: "Check-in evidence was never verified by the shift deadline.",
        now: new Date(),
      });
    } else if (status === sessionMachine.SessionStatus.working) {
      const finalised = sessionMachine.autoFinalizeMissedCheckOut(session, {
        windowEnd: endOfWindowIso(target, maxEndMin),
      });
      next = { ...finalised, checkOutVerifiedAt: Timestamp.fromDate(new Date(endIso)) };
    } else if (status === sessionMachine.SessionStatus.checkOutPending) {
      const hasEvidence = await core.assertEvidenceUploaded(
        storage.bucket(),
        session.evidenceCheckOutPath
      );
      if (hasEvidence) {
        const submitted = sessionMachine.completeCheckOut(session, {
          verifiedAt: new Date(endIso),
          evidenceOk: true,
        });
        next = { ...submitted, checkOutVerifiedAt: Timestamp.fromDate(new Date(endIso)) };
      } else {
        next = sessionMachine.markMissed(session, {
          reason: "Check-out evidence was not uploaded before the shift deadline.",
          now: new Date(),
        });
      }
    } else {
      transitions.skipped += 1;
      continue;
    }

    if (next.status === sessionMachine.SessionStatus.submitted) {
      const verifiedHours = computeVerifiedHours({
        dayKey: target,
        checkInVerifiedAt:
          next.checkInVerifiedAt?.toDate?.().toISOString?.() ??
          session.checkInVerifiedAt?.toDate?.().toISOString?.() ??
          null,
        checkOutVerifiedAt: new Date(endIso).toISOString(),
        windows,
      });
      next = { ...next, verifiedHours };
    }

    await sref.set({ ...next, updatedAt: Timestamp.now() }, { merge: true });
    report.push({ studentId, status: next.status });
    transitions[next.status === "missed" ? "missed" : "submitted"] += 1;
  }

  return {
    dateKey: target,
    scanned: studentsSnap.size,
    transitions,
    missed: report.filter((r) => r.status === "missed").map((r) => r.studentId),
    finalized: report.filter((r) => r.status === "submitted").map((r) => r.studentId),
    report,
  };
}

async function createMissed(db, studentId, target, windows) {
  const now = Timestamp.now();
  const session = {
    ...core.buildInitSession(studentId, target, windows),
    status: sessionMachine.SessionStatus.missed,
    reason: "Shift window ended without any activity.",
    createdAt: now,
    updatedAt: now,
  };
  await core.sessionRef(db, studentId, target).set(session);
}

function endOfWindowIso(dateKey, minutes) {
  return new Date(windowEndMs(dateKey, minutes)).toISOString();
}

async function requireAssignmentQuiet(db, studentId) {
  try {
    const snap = await db.doc(`assignments/${studentId}`).get();
    return snap.exists ? { id: studentId, ...snap.data() } : null;
  } catch (_err) {
    return null;
  }
}

module.exports = { sweepAttendance, endOfWindowIso };