"use strict";

const { CODES, httpError } = require("../util/errors");
const { isWithinLocation } = require("../domain/geo");
const { Timestamp } = require("../firebase");
const idem = require("../util/idempotency");
const sessionMachine = require("../domain/sessionMachine");

/** Session doc key == date key; parent month uses the same string prefix. */
function sessionRef(db, studentId, dateKey) {
  return db.doc(`attendance/${studentId}/${dateKey.slice(0, 7)}/${dateKey}`);
}

function operationRef(db, uid, dateKey, requestId, kind) {
  const opId = kind ? `${kind}_${requestId}` : requestId;
  return db.doc(`operations/${uid}/${dateKey.slice(0, 7)}/${opId}`);
}

function pad(n) {
  return String(n).padStart(2, "0");
}

function utcDateKey(now) {
  const d = now instanceof Date ? now : new Date(now);
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
}

/** Windows active for dateKey per the assignment's effectivity range. */
function planWindows(assignment, dateKey) {
  if (!assignment || !Array.isArray(assignment.shiftWindows)) return [];
  const from = assignment.effectiveFrom;
  const to = assignment.effectiveTo;
  if (typeof from === "string" && dateKey < from) return [];
  if (typeof to === "string" && dateKey > to) return [];
  return assignment.shiftWindows
    .filter(
      (w) =>
        Number.isInteger(w.startMin) &&
        Number.isInteger(w.endMin) &&
        w.endMin > w.startMin
    )
    .map((w) => ({ startMin: w.startMin, endMin: w.endMin }));
}

function evidencePathFor(uid, dateKey, requestId, kind) {
  return `evidence/${uid}/${dateKey}/${requestId}_${kind}.jpg`;
}

function buildInitSession(studentId, dateKey, windows) {
  return {
    studentId,
    date: dateKey,
    windows,
    status: sessionMachine.SessionStatus.scheduled,
    review: "pending",
    verifiedHours: 0,
    checkInRequestedAt: null,
    checkInVerifiedAt: null,
    checkOutRequestedAt: null,
    checkOutVerifiedAt: null,
    reason: null,
    evidenceCheckInPath: null,
    evidenceCheckOutPath: null,
    createdAt: null,
    updatedAt: null,
  };
}

/** Accepts either a YYYY-MM-DD key or any parseable date.
 *  Returns the server-normalized UTC date key. */
function dateFromPayload(data, name) {
  const raw = data[name];
  if (typeof raw === "string" && /^\d{4}-\d{2}-\d{2}$/.test(raw)) return raw;
  if (typeof raw === "string" || typeof raw === "number") {
    const d = new Date(raw);
    if (!Number.isNaN(d.getTime())) return utcDateKey(d);
  }
  throw httpError(CODES.INVALID_ARGUMENT, `${name} must be a YYYY-MM-DD date.`);
}

async function assertEvidenceUploaded(bucket, path) {
  try {
    const [exists] = await bucket.file(path).exists();
    if (!exists) return false;
    const [meta] = await bucket.file(path).getMetadata();
    const size = Number(meta.size || 0);
    const type = String(meta.contentType || "");
    return size > 0 && type.startsWith("image/");
  } catch (_err) {
    return false;
  }
}

/**
 * Both evidence pieces are mandatory and consistent with the idempotency key:
 * the upload path must be the deterministic derived path and the GPS fix must
 * fall inside the assigned location geofence.
 */
async function assertValidEvidence({
  bucket,
  location,
  uid,
  dateKey,
  requestId,
  kind,
  uploadPath,
  geo,
}) {
  const expected = evidencePathFor(uid, dateKey, requestId, kind);
  if (uploadPath !== expected) {
    throw httpError(CODES.INVALID_EVIDENCE, `Evidence must be uploaded to ${expected}.`);
  }
  if (!isWithinLocation(geo, location)) {
    throw httpError(
      CODES.INVALID_EVIDENCE,
      "GPS fix is outside the assigned location geofence."
    );
  }
  const uploaded = await assertEvidenceUploaded(bucket, uploadPath);
  if (!uploaded) {
    throw httpError(
      CODES.INVALID_EVIDENCE,
      "Mandatory identity evidence was not found at the expected path."
    );
  }
}

/**
 * Transactional core: one writer for the op ledger + session doc. Replays a
 * finished request verbatim; in-flight requests abort with CONFLICT.
 */
async function runSessionOp({ db, uid, dateKey, requestId, kind }, fn) {
  const opRef = operationRef(db, uid, dateKey, requestId, kind);
  return db.runTransaction(async (tx) => {
    const opState = await idem.opInsideTransaction(tx, opRef);
    if (opState) return { replay: true, data: opState.result };
    const data = await fn(tx, opRef);
    return { replay: false, data };
  });
}

function finishTxOp(tx, opRef, { kind, sessionId, method, requestId, dateKey, result }) {
  tx.set(opRef, {
    kind,
    sessionId,
    method,
    requestId,
    dateKey,
    createdAt: Timestamp.now(),
    finishedAt: Timestamp.now(),
    result,
  });
}

module.exports = {
  sessionRef,
  operationRef,
  utcDateKey,
  planWindows,
  evidencePathFor,
  buildInitSession,
  dateFromPayload,
  assertEvidenceUploaded,
  assertValidEvidence,
  runSessionOp,
  finishTxOp,
};