"use strict";

const { CODES, httpError } = require("../util/errors");
const { assertObject, assertGeo, assertDateKey, assertRequestId } =
  require("../util/validation");
const { Timestamp } = require("../firebase");
const identity = require("../identity");
const core = require("./attendance_core");
const { distanceMeters, isWithinLocation } = require("../domain/geo");
const { Flags } = require("../domain/flags");

const STALE_AFTER_MS = 5 * 60 * 1000;
const MAX_SPEED_MPS = 21;

const ACTIVE_STATUSES = new Set([
  "checkInPending",
  "working",
  "checkOutPending",
]);

/**
 * attendance.recordLocationSample — passive GPS samples a student's device
 * sends while a session is open. Each sample is validated (geofence, accuracy,
 * staleness, impossible movement) and persisted under attendanceSamples.
 *
 * Samples are evidence, never authority: they cannot change session status,
 * but they feed supervisors' reconciliation and review flags. Idempotent by
 * requestId.
 */
async function recordLocationSample(deps, context, data) {
  const person = await identity.requireStudent(deps.db, context);

  let state;
  try {
    state = JSON.parse(JSON.stringify(data.state));
  } catch (_err) {
    throw httpError(CODES.INVALID_ARGUMENT, "state must be a JSON object.");
  }
  assertObject(state, "state");

  const { sessionId, sample } = state;
  const dateKey = String(sessionId);
  assertDateKey(dateKey, "sessionId");
  assertObject(sample, "state.sample");
  assertRequestId(sample.requestId);
  if (sample.geo != null) assertGeo(sample.geo);
  if (!sample.geo) {
    throw httpError(
      CODES.INVALID_ARGUMENT,
      "sample.geo is required for location sampling."
    );
  }

  const requestId = String(sample.requestId).slice(0, 64);
  const lat = Number(sample.geo.latitude);
  const lng = Number(sample.geo.longitude);
  const accuracy = sample.geo.accuracyMeters;
  const capturedAtMs = Number.isFinite(sample.geo.timestampMs)
    ? Number(sample.geo.timestampMs)
    : null;

  // Session must exist and be in an active window of its lifecycle.
  const sessionSnap = await deps.db
    .doc(`attendance/${person.entityId}/${dateKey.slice(0, 7)}/${dateKey}`)
    .get();
  if (!sessionSnap.exists) {
    throw httpError(
      CODES.FAILED_PRECONDITION,
      `No attendance session for ${person.entityId} on ${dateKey}.`
    );
  }
  const session = sessionSnap.data();
  if (!ACTIVE_STATUSES.has(session.status)) {
    throw httpError(
      CODES.FAILED_PRECONDITION,
      `Session is ${session.status}; no samples are collected for closed sessions.`
    );
  }

  const assignment = await identity.readAssignment(deps.db, person.entityId);
  const location = assignment
    ? await identity.readLocation(deps.db, assignment.locationId)
    : null;

  const flags = [];
  let validationStatus = "verified";
  let distanceFromWorkZone = null;

  if (!location || location.status !== "active") {
    flags.push(Flags.LOCATION_REQUIRED);
    validationStatus = "unverified";
  } else if (
    Number.isFinite(location.latitude) &&
    Number.isFinite(location.longitude)
  ) {
    distanceFromWorkZone = distanceMeters(lat, lng, location.latitude, location.longitude);
    const accuracyMax = Number(location.accuracyMaxMeters) || 0;
    if (Number.isFinite(accuracyMax) && accuracyMax > 0 && accuracy > accuracyMax) {
      flags.push(Flags.LOCATION_LOW_ACCURACY);
      validationStatus = "unverified";
    }
    // Same geofence math as the check-in/check-out evidence path (radius plus
    // the device's reported accuracy as tolerance).
    if (!isWithinLocation({ lat, lng, accuracyMeters: accuracy }, location)) {
      flags.push(Flags.LOCATION_OUTSIDE_ZONE);
      validationStatus = "unverified";
    }
  } else {
    flags.push(Flags.LOCATION_REQUIRED);
    validationStatus = "unverified";
  }

  if (capturedAtMs && Date.now() - capturedAtMs > STALE_AFTER_MS) {
    flags.push(Flags.LOCATION_STALE);
    validationStatus = "unverified";
  }

  // Impossible movement vs. the most recent sample from the same day.
  const prevSnap = await deps.db
    .collection("attendanceSamples")
    .doc(person.entityId)
    .collection(dateKey)
    .orderBy("recordedAt", "desc")
    .limit(1)
    .get();
  if (!prevSnap.empty) {
    const prev = prevSnap.docs[0].data();
    const dtMs =
      Timestamp.now().toMillis() - prev.recordedAt.toMillis();
    const dtSec = dtMs / 1000;
    if (dtSec > 0 && dtSec < 600) {
      const travelled = distanceMeters(lat, lng, prev.latitude, prev.longitude);
      if (travelled / dtSec > MAX_SPEED_MPS) {
        flags.push(Flags.IMPOSSIBLE_MOVEMENT);
        validationStatus = "unverified";
      }
    }
  }

  const recordedAt = Timestamp.now();
  const sampleDoc = {
    studentId: person.entityId,
    dateKey,
    requestId,
    recordedAt,
    capturedAt: capturedAtMs ? new Date(capturedAtMs) : null,
    latitude: lat,
    longitude: lng,
    accuracyMeters: Number.isFinite(accuracy) ? accuracy : null,
    provider: typeof sample.provider === "string" ? sample.provider.slice(0, 32) : null,
    distanceFromWorkZone,
    validationStatus,
    flags,
    status: session.status,
  };

  // Deterministic doc id == request id, so a resent packet is a no-op.
  await deps.db
    .collection("attendanceSamples")
    .doc(person.entityId)
    .collection(dateKey)
    .doc(requestId)
    .set(sampleDoc, { merge: true });

  return {
    sampleId: requestId,
    recordedAt: recordedAt.toDate().toISOString(),
    validationStatus,
    distanceFromWorkZone,
    flags,
  };
}

module.exports = { recordLocationSample };