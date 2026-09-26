"use strict";

const { CODES, httpError } = require("../util/errors");
const { assertObject, assertGeo, assertRequestId, assertDateKey } =
  require("../util/validation");
const { Timestamp } = require("../firebase");
const identity = require("../identity");
const sessionMachine = require("../domain/sessionMachine");
const { computeVerifiedHours, plannedHours } = require("../domain/hours");
const core = require("./attendance_core");

/**
 * attendance.checkOut — initiate. The client must hold a verified (working)
 * session; the server moves it to checkOutPending and returns the evidence
 * upload target. Idempotent by requestId.
 */
async function checkOutHandler(deps, context, data) {
  assertObject(data, "payload");
  const person = await identity.requireStudent(deps.db, context);
  const dateKey = String(data.sessionId);
  assertDateKey(dateKey, "sessionId");
  const requestId = String(data.requestId);
  assertRequestId(requestId);
  if (data.geo != null) assertGeo(data.geo);

  const uploadTarget = core.evidencePathFor(person.uid, dateKey, requestId, "checkout");

  const { replay, data: result } = await core.runSessionOp(
    { db: deps.db, uid: person.uid, dateKey, requestId, kind: "checkOut" },
    async (tx, opRef) => {
      const sref = core.sessionRef(deps.db, person.entityId, dateKey);
      const snap = await tx.get(sref);
      if (!snap.exists) {
        throw httpError(CODES.FAILED_PRECONDITION, "No session to check out.");
      }
      const session = snap.data();
      if (session.status !== sessionMachine.SessionStatus.working) {
        throw httpError(
          CODES.FAILED_PRECONDITION,
          `Session is ${session.status}; expected working.`
        );
      }
      const pending = sessionMachine.requestCheckOut(session, new Date());
      await tx.set(sref, {
        ...pending,
        checkOutRequestedAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      });
      core.finishTxOp(tx, opRef, {
        kind: "checkOut",
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
 * attendance.confirmCheckOut — validates evidence, verifies the check-out,
 * and computes server-authoritative `verifiedHours` as the overlap of
 * [checkInVerifiedAt, checkOutVerifiedAt] with the day's windows. No
 * deductions or unconfirmed time is credited.
 */
async function confirmCheckOutHandler(deps, context, data) {
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
  const windows = core.planWindows(assignment, dateKey);
  if (windows.length === 0) {
    throw httpError(CODES.INVALID_ARGUMENT, `No shift scheduled for ${dateKey}.`);
  }
  const location = await identity.readLocation(deps.db, assignment.locationId);
  if (!location) {
    throw httpError(CODES.NOT_FOUND, `Location ${assignment.locationId} not found.`);
  }

  await core.assertValidEvidence({
    bucket: deps.storage.bucket(),
    location,
    uid: person.uid,
    dateKey,
    requestId,
    kind: "checkout",
    uploadPath,
    geo,
  });

  const { replay, data: result } = await core.runSessionOp(
    { db: deps.db, uid: person.uid, dateKey, requestId, kind: "confirmCheckOut" },
    async (tx, opRef) => {
      const sref = core.sessionRef(deps.db, person.entityId, dateKey);
      const snap = await tx.get(sref);
      if (!snap.exists) {
        throw httpError(CODES.FAILED_PRECONDITION, "No pending check-out to confirm.");
      }
      const session = snap.data();
      if (session.status !== sessionMachine.SessionStatus.checkOutPending) {
        throw httpError(
          CODES.FAILED_PRECONDITION,
          `Session is ${session.status}; expected checkOutPending.`
        );
      }
      const verifiedAt = Timestamp.now();
      const submitted = sessionMachine.completeCheckOut(session, {
        verifiedAt: verifiedAt.toDate(),
        evidenceOk: true,
      });
      const checkInIso = session.checkInVerifiedAt?.toDate?.().toISOString?.() ?? null;
      const checkOutIso = verifiedAt.toDate().toISOString();
      const verifiedHours = computeVerifiedHours({
        dayKey: dateKey,
        checkInVerifiedAt: checkInIso,
        checkOutVerifiedAt: checkOutIso,
        windows,
      });
      const capacityWarning = verifiedHours > plannedHours(windows) + 0.006;
      await tx.set(sref, {
        ...submitted,
        evidenceCheckOutPath: uploadPath,
        verifiedHours,
        updatedAt: Timestamp.now(),
      });
      core.finishTxOp(tx, opRef, {
        kind: "confirmCheckOut",
        sessionId: dateKey,
        method: "confirm",
        requestId,
        dateKey,
        result: {
          status: sessionMachine.SessionStatus.submitted,
          verifiedHours,
          capacityWarning,
        },
      });
      return { status: sessionMachine.SessionStatus.submitted, verifiedHours, capacityWarning };
    }
  );
  return { replay, ...result };
}

module.exports = { checkOutHandler, confirmCheckOutHandler };