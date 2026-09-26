"use strict";

/**
 * 1:1 port of lib/domain/attendance/session_state_machine.dart + the guard
 * table from lib/domain/attendance/session_status.dart. Server timestamps are
 * passed in by callers — the machine never mints them.
 */

const SessionStatus = Object.freeze({
  scheduled: "scheduled",
  checkInPending: "checkInPending",
  working: "working",
  checkOutPending: "checkOutPending",
  submitted: "submitted",
  underReview: "underReview",
  correctionRequested: "correctionRequested",
  approved: "approved",
  flagged: "flagged",
  rejected: "rejected",
  missed: "missed",
  cancelled: "cancelled",
  closed: "closed",
});

const ALLOWED_EDGES = {
  [SessionStatus.scheduled]: new Set([
    SessionStatus.checkInPending,
    SessionStatus.missed,
    SessionStatus.cancelled,
  ]),
  [SessionStatus.checkInPending]: new Set([
    SessionStatus.working,
    SessionStatus.missed,
    SessionStatus.cancelled,
  ]),
  [SessionStatus.working]: new Set([
    SessionStatus.checkOutPending,
    SessionStatus.submitted,
    SessionStatus.missed,
  ]),
  [SessionStatus.checkOutPending]: new Set([SessionStatus.submitted]),
  [SessionStatus.submitted]: new Set([
    SessionStatus.underReview,
    SessionStatus.flagged,
  ]),
  [SessionStatus.underReview]: new Set([
    SessionStatus.approved,
    SessionStatus.flagged,
    SessionStatus.rejected,
    SessionStatus.correctionRequested,
  ]),
  [SessionStatus.flagged]: new Set([
    SessionStatus.approved,
    SessionStatus.rejected,
    SessionStatus.correctionRequested,
  ]),
  [SessionStatus.correctionRequested]: new Set([SessionStatus.submitted]),
  [SessionStatus.approved]: new Set(),
  [SessionStatus.rejected]: new Set(),
  [SessionStatus.missed]: new Set(),
  [SessionStatus.cancelled]: new Set(),
  [SessionStatus.closed]: new Set(),
};

class InvalidTransitionError extends Error {
  constructor(from, to) {
    super(`Session cannot move ${from} → ${to}.`);
    this.name = "InvalidTransitionError";
    this.from = from;
    this.to = to;
  }
}

function assertAllowed(from, to) {
  const allowed = ALLOWED_EDGES[from] || new Set();
  if (!allowed.has(to)) throw new InvalidTransitionError(from, to);
}

/**
 * Pure transition helpers over plain session objects.
 * `now` must be an ISO string or Date; null → caller passed nothing.
 */
function go(session, next, { reason = undefined, now = new Date() } = {}) {
  assertAllowed(session.status, next);
  const ts =
    typeof now === "string" ? now : now instanceof Date ? now.toISOString() : "";
  return {
    ...session,
    status: next,
    reason: reason !== undefined ? reason : session.reason ?? null,
    updatedAt: ts,
  };
}

function requestCheckIn(session, requestedAt) {
  const ts = requestedAt.toISOString ? requestedAt.toISOString() : requestedAt;
  return { ...go(session, SessionStatus.checkInPending), checkInRequestedAt: ts };
}

function completeCheckIn(session, { verifiedAt, evidenceOk }) {
  if (!evidenceOk) {
    throw new InvalidTransitionError(
      session.status,
      SessionStatus.working,
      "Check-in verification failed; session stays pending."
    );
  }
  return {
    ...go(session, SessionStatus.working),
    checkInVerifiedAt: verifiedAt,
  };
}

function requestCheckOut(session, requestedAt) {
  const ts = requestedAt.toISOString ? requestedAt.toISOString() : requestedAt;
  return {
    ...go(session, SessionStatus.checkOutPending),
    checkOutRequestedAt: ts,
  };
}

function completeCheckOut(session, { verifiedAt, evidenceOk }) {
  if (!evidenceOk) {
    throw new InvalidTransitionError(
      session.status,
      SessionStatus.submitted,
      "Check-out verification failed; session stays pending."
    );
  }
  return {
    ...go(session, SessionStatus.submitted),
    checkOutVerifiedAt: verifiedAt,
  };
}

function autoFinalizeMissedCheckOut(session, { windowEnd }) {
  const finalised = {
    ...go(session, SessionStatus.submitted),
    checkOutVerifiedAt: windowEnd,
    reason: "Check-out auto-finalized at window end (no user action).",
  };
  return finalised;
}

function markMissed(session, { reason = "Shift went unattended.", now } = {}) {
  return go(session, SessionStatus.missed, { reason, now });
}

function startReview(session) {
  return go(session, SessionStatus.underReview);
}

function approve(session) {
  return { ...go(session, SessionStatus.approved), review: "approved" };
}

function flag(session, { reason, now }) {
  return { ...go(session, SessionStatus.flagged, { reason, now }), review: "flagged" };
}

function reject(session, { reason, now }) {
  return { ...go(session, SessionStatus.rejected, { reason, now }), review: "rejected" };
}

module.exports = {
  SessionStatus,
  ALLOWED_EDGES,
  InvalidTransitionError,
  go,
  requestCheckIn,
  completeCheckIn,
  requestCheckOut,
  completeCheckOut,
  autoFinalizeMissedCheckOut,
  markMissed,
  startReview,
  approve,
  flag,
  reject,
};