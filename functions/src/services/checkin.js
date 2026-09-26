"use strict";

const { CODES, httpError } = require("../util/errors");
const { assertObject, assertGeo, assertRequestId, assertDateKey } =
  require("../util/validation");
const { Timestamp } = require("../firebase");
const identity = require("../identity");
const sessionMachine = require("../domain/sessionMachine");
const core = require("./attendance_core");

/**
 * attendance.checkIn — initiate: server resolves the day's windows, opens (or
 * reopens) the session as checkInPending, and returns the deterministic
 * evidence upload target. Idempotent by requestId.
 */
async function checkInHandler(deps, context, data) {
  assertObject(data, "payload");
  const person = await identity.requireStudent(deps.db, context);
  const dateKey = core.dateFromPayload(data, "date");
  assertRequestId(data.requestId);
  const requestId = String(data.requestId).slice(0, 64);
  if (data.geo != null) assertGeo(data.geo);

  const assignment = await identity.readAssignment(deps.db, person.entityId);
  const windows = core.planWindows(assignment, dateKey);
  if (windows.length === 0) {
    throw httpError(
      CODES.INVALID_ARGUMENT,
      `No shift window is scheduled for ${dateKey}.`
    );
  }

  const uploadTarget = core.evidencePathFor(person.uid, dateKey, requestId, "checkin");
  const initSession = core.buildInitSession(person.entityId, dateKey, windows);

  const { replay, data: result } = await core.runSessionOp(
    { db: deps.db, uid: person.uid, dateKey, requestId, kind: "checkIn" },
    async (tx, opRef) => {
      const sref = core.sessionRef(deps.db, person.entityId, dateKey);
      const snap = await tx.get(sref);
      let session;
      if (!snap.exists) {
        session = { ...initSession, createdAt: Timestamp.now() };
      } else {
        session = snap.data();
        const open = [
          sessionMachine.SessionStatus.scheduled,
          sessionMachine.SessionStatus.checkInPending,
        ];
        if (!open.includes(session.status)) {
          throw httpError(
            CODES.FAILED_PRECONDITION,
            `Session is ${session.status}; check-in is not applicable.`
          );
        }
      }
      const requested = sessionMachine.requestCheckIn(session, new Date());
      await tx.set(sref, {
        ...requested,
        windows: windows.map((w) => ({ startMin: w.startMin, endMin: w.endMin })),
        updatedAt: Timestamp.now(),
      });
      core.finishTxOp(tx, opRef, {
        kind: "checkIn",
        sessionId: dateKey,
        method: "initiate",
        requestId,
        dateKey,
        result: { sessionId: dateKey, requestId, uploadTarget },
      });
      return { sessionId: dateKey, requestId, uploadTarget };
    }
  );
  return { replay, ...result };
}

/**
 * attendance.confirmCheckIn — server validates selfie + GPS evidence and, when
 * valid, verifies the check-in (scheduled → checkInPending → working). Failed
 * evidence keeps the session pending; the client may retry.
 */
async function confirmCheckInHandler(deps, context, data) {
  assertObject(data, "payload");
  const person = await identity.requireStudent(deps.db, context);
  const dateKey = String(data.sessionId);
  assertDateKey(dateKey, "sessionId");
  const requestId = String(data.requestId);
  assertRequestId(requestId);
  const uploadPath = String(data.uploadPath);
  const geo = data.geo;
  assertGeo(geo);

  const assignment = await identity.readAssignment(deps.db, person.entityId);
  if (core.planWindows(assignment, dateKey).length === 0) {
    throw httpError(CODES.INVALID_ARGUMENT, `No shift scheduled for ${dateKey}.`);
  }
  const location = await identity.readLocation(deps.db, assignment.locationId);
  if (!location) {
    throw httpError(CODES.NOT_FOUND, `Location ${assignment.locationId} not found.`);
  }

  // Read-only evidence checks run before the transaction.
  await core.assertValidEvidence({
    bucket: deps.storage.bucket(),
    location,
    uid: person.uid,
    dateKey,
    requestId,
    kind: "checkin",
    uploadPath,
    geo,
  });

  const { replay, data: result } = await core.runSessionOp(
    { db: deps.db, uid: person.uid, dateKey, requestId, kind: "confirmCheckIn" },
    async (tx, opRef) => {
      const sref = core.sessionRef(deps.db, person.entityId, dateKey);
      const snap = await tx.get(sref);
      if (!snap.exists) {
        throw httpError(CODES.FAILED_PRECONDITION, "No pending check-in to confirm.");
      }
      const session = snap.data();
      if (session.status !== sessionMachine.SessionStatus.checkInPending) {
        throw httpError(
          CODES.FAILED_PRECONDITION,
          `Session is ${session.status}; expected checkInPending.`
        );
      }
      const verifiedAt = Timestamp.now();
      const working = sessionMachine.completeCheckIn(session, {
        verifiedAt: verifiedAt.toDate(),
        evidenceOk: true,
      });
      await tx.set(sref, {
        ...working,
        evidenceCheckInPath: uploadPath,
        updatedAt: Timestamp.now(),
      });
      core.finishTxOp(tx, opRef, {
        kind: "confirmCheckIn",
        sessionId: dateKey,
        method: "confirm",
        requestId,
        dateKey,
        result: {
          status: sessionMachine.SessionStatus.working,
          checkInVerifiedAt: verifiedAt.toDate().toISOString(),
          geoVerified: true,
        },
      });
      return {
        status: sessionMachine.SessionStatus.working,
        checkInVerifiedAt: verifiedAt.toDate().toISOString(),
        geoVerified: true,
      };
    }
  );
  return { replay, ...result };
}

module.exports = { checkInHandler, confirmCheckInHandler };