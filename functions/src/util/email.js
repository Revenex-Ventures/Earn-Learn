"use strict";

const { CODES, httpError } = require("./errors");

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * Canonical email form used everywhere an identity is keyed: trimmed,
 * lower-cased. The authorized roster/allowlist stores emails in this exact
 * form so Google Sign-In and Excel import resolve to the same key.
 */
function normalizeEmail(raw) {
  if (typeof raw !== "string") return null;
  const email = raw.trim().toLowerCase();
  if (!EMAIL_RE.test(email)) return null;
  return email;
}

/** Identity/roster records that share an email are the same person. */
function assertNormalizedEmail(value, name = "email") {
  const email = normalizeEmail(value);
  if (!email) {
    throw httpError(CODES.INVALID_ARGUMENT, `${name} must be a valid email address.`);
  }
  return email;
}

/** True only when the signed-in token carries a verified email claim. */
function assertEmailVerified(context) {
  const emailVerified = context?.auth?.token?.email_verified === true;
  if (!emailVerified) {
    throw httpError(
      CODES.FAILED_PRECONDITION,
      "The Google account email is not verified; verification is required before access."
    );
  }
  return true;
}

module.exports = { normalizeEmail, assertNormalizedEmail, assertEmailVerified, EMAIL_RE };