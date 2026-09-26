"use strict";

const { CODES, httpError } = require("./errors");

const DATE_KEY_RE = /^\d{4}-\d{2}-\d{2}$/;
const REQUEST_ID_RE = /^[a-zA-Z0-9_]+$/;

function assertObject(value, name) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw httpError(CODES.INVALID_ARGUMENT, `${name} must be an object.`);
  }
}

function assertString(value, name, { allowEmpty = false, max = 1024 } = {}) {
  if (typeof value !== "string" || (!allowEmpty && value.trim().length === 0)) {
    throw httpError(CODES.INVALID_ARGUMENT, `${name} must be a non-empty string.`);
  }
  if (value.length > max) {
    throw httpError(CODES.INVALID_ARGUMENT, `${name} exceeds ${max} characters.`);
  }
}

function assertDateKey(value, name) {
  assertString(value, name);
  if (!DATE_KEY_RE.test(value)) {
    throw httpError(
      CODES.INVALID_ARGUMENT,
      `${name} must be a YYYY-MM-DD date key.`
    );
  }
}

function assertRequestId(value, name = "requestId") {
  assertString(value, name);
  if (!REQUEST_ID_RE.test(value)) {
    throw httpError(
      CODES.INVALID_ARGUMENT,
      `${name} must match [A-Za-z0-9_]{1,64}.`
    );
  }
}

function assertFiniteNumber(value, name) {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw httpError(CODES.INVALID_ARGUMENT, `${name} must be a finite number.`);
  }
}

function assertGeo(value) {
  assertObject(value, "geo");
  assertFiniteNumber(value.lat, "geo.lat");
  assertFiniteNumber(value.lng, "geo.lng");
  assertFiniteNumber(value.accuracyMeters, "geo.accuracyMeters");
  if (value.lat < -90 || value.lat > 90 || value.lng < -180 || value.lng > 180) {
    throw httpError(CODES.INVALID_ARGUMENT, "geo out of valid range.");
  }
}

module.exports = {
  assertObject,
  assertString,
  assertDateKey,
  assertRequestId,
  assertFiniteNumber,
  assertGeo,
};