"use strict";

const { setGlobalOptions } = require("firebase-functions/v2");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");

const { db, authAdmin, storage } = require("./src/firebase");
const { FunctionError, CODES } = require("./src/util/errors");
const identitySvc = require("./src/identity_svc");
const importRoster = require("./src/services/import_roster");
const checkin = require("./src/services/checkin");
const checkout = require("./src/services/checkout");
const review = require("./src/services/review");
const sweep = require("./src/services/sweep");
const samples = require("./src/services/samples");
const adminOps = require("./src/services/admin_ops");
const { applySeeds } = require("./src/seeds");

setGlobalOptions({ region: "asia-south1" });

const deps = { db, auth: authAdmin, storage };

const GRPC_CODE = {
  [CODES.UNAUTHENTICATED]: "unauthenticated",
  [CODES.UNLINKED]: "failed-precondition",
  [CODES.ACCOUNT_NOT_REGISTERED]: "not-found",
  [CODES.PERMISSIONS]: "permission-denied",
  [CODES.INVALID_ARGUMENT]: "invalid-argument",
  [CODES.INVALID_EVIDENCE]: "invalid-argument",
  [CODES.NOT_FOUND]: "not-found",
  [CODES.FAILED_PRECONDITION]: "failed-precondition",
  [CODES.CONFLICT]: "aborted",
  [CODES.CAPACITY]: "resource-exhausted",
  [CODES.INTERNAL]: "internal",
};

function toHttpsError(err) {
  if (err instanceof FunctionError) {
    const code = GRPC_CODE[err.code] || "internal";
    return new HttpsError(code, err.message, { kind: err.code });
  }
  // eslint-disable-next-line no-console
  console.error("UNCAUGHT", err);
  return new HttpsError("internal", "Internal attendance error.");
}

/**
 * Standard callable envelope: functions return { ok:true, data }; failures
 * surface as HttpsError carrying the stable domain code in details.kind.
 * Callable names are flat and match the Dart gateway's httpsCallable names.
 */
function callable(handler) {
  return onCall(async (request) => {
    try {
      const data = await handler(deps, request, request.data ?? {});
      return { ok: true, data };
    } catch (err) {
      throw toHttpsError(err);
    }
  });
}

// Stage-2B entrypoints.
exports.bootstrapUser = callable(identitySvc.bootstrapUserHandler);
// Stage-2A compatibility alias: the current Flutter auth gate still calls
// completeSignIn; it now resolves through the allowlist like bootstrapUser.
exports.completeSignIn = callable(identitySvc.completeSignInHandler);
exports.importRoster = callable(importRoster.importRosterHandler);

exports.checkIn = callable(checkin.checkInHandler);
exports.confirmCheckIn = callable(checkin.confirmCheckInHandler);
exports.checkOut = callable(checkout.checkOutHandler);
exports.confirmCheckOut = callable(checkout.confirmCheckOutHandler);
exports.review = callable(review.reviewHandler);
exports.myQueue = callable(review.myQueueHandler);
exports.getEvidence = callable(review.getEvidenceHandler);
exports.recordLocationSample = callable(samples.recordLocationSample);
exports.manualAttendanceCorrection = callable(adminOps.manualAttendanceCorrection);
exports.reconcileAttendance = callable(adminOps.reconcileAttendance);

exports.runNightlyAttendance = onSchedule(
  { schedule: "every day 22:00", timeZone: "Asia/Kolkata" },
  async () => {
    if (process.env.DISABLE_SWEEP === "1") {
      return { skipped: true };
    }
    return sweep.sweepAttendance({ db, storage, dateKey: null });
  }
);

// Synthetic emulator fixtures — ONLY available when ALLOW_SEEDS=1 (the
// emulator test npm script). Never registered in live deploys.
if (process.env.ALLOW_SEEDS === "1") {
  exports.seedSyntheticData = callable(async (_deps, _request) => {
    const result = await applySeeds(deps);
    return { ok: true, data: result };
  });
}