"use strict";

const { CODES, httpError } = require("./errors");

/**
 * Idempotency ledger helper used inside the attendance transaction path.
 *
 * Ledger rows live at operations/{uid}/{yyyy-MM}/{kind}_{requestId} (the
 * `kind_` prefix is applied by attendance_core.operationRef). A finished row
 * means the request completed and its stored result is the authoritative
 * response; an in-flight row aborts with CONFLICT so concurrent duplicates
 * cannot double-verify.
 */

/**
 * Reads an op row inside a Firestore transaction. Returns
 * {result} (possibly null) when a finished row exists, null when the row is
 * absent, and throws CONFLICT for in-flight rows.
 */
async function opInsideTransaction(t, ref) {
  const snap = await t.get(ref);
  if (!snap.exists) return null;
  const data = snap.data();
  if (!data.finishedAt) {
    throw httpError(CODES.CONFLICT, "request already in progress.");
  }
  return { result: data.result ?? null };
}

module.exports = {
  opInsideTransaction,
};