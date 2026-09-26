"use strict";

const { CODES, httpError } = require("./util/errors");
const { assertObject } = require("./util/validation");
const { assertEmailVerified, normalizeEmail } = require("./util/email");
const identity = require("./identity");
const allowlist = require("./allowlist");
const { Timestamp } = require("./firebase");

/**
 * bootstrapUser — server-authoritative account provisioning for Google
 * Sign-In. Nothing in this handler trusts the client:
 *
 *   1. The Firebase Auth UID is taken from the verified token.
 *   2. The Google email MUST be verified.
 *   3. The normalized email is checked against the roster-derived
 *      accessAllowlist. A matching Google account with no roster entry is
 *      rejected with the account-not-registered state.
 *   4. The user's role and personId are assigned FROM the allowlist; a
 *      client-supplied role/email/displayName can never grant authority.
 *   5. users/{uid} is only created when the account is approved.
 *
 * Inactive allowlist entries are rejected (account not approved). Directory
 * uid linkage is written so client rules scope reads to the owner.
 */
async function bootstrapUserHandler(deps, context, data) {
  assertObject(data, "payload");
  const person = identity.assertAuthenticated(context);
  assertEmailVerified(context);

  const tokenEmail = context.auth.token?.email;
  const rawEmail = typeof tokenEmail === "string" && tokenEmail.length ? tokenEmail : data.email;
  const email = normalizeEmail(rawEmail);
  if (!email) {
    throw httpError(CODES.INVALID_ARGUMENT, "A verified Google email is required.");
  }

  const entry = await allowlist.lookupAllowlist(deps.db, email);
  if (!entry) {
    throw httpError(
      CODES.ACCOUNT_NOT_REGISTERED,
      "This account is not on the approved roster — access is blocked.",
      { kind: CODES.ACCOUNT_NOT_REGISTERED, email }
    );
  }
  if (entry.status !== "active") {
    throw httpError(
      CODES.FAILED_PRECONDITION,
      "This account is not approved for access.",
      { status: entry.status }
    );
  }

  // data.role/data.personId/data.status are deliberately ignored.
  const now = Timestamp.now();
  const { created, profile } = await allowlist.provisionUser(deps.db, {
    uid: person.uid,
    email,
    emailVerified: true,
    entry,
    now,
  });

  return {
    acknowledged: true,
    registered: true,
    created,
    uid: person.uid,
    role: profile.role,
    personId: profile.personId,
    status: profile.status,
  };
}

module.exports = {
  bootstrapUserHandler,
  // Stage-2A compatibility alias: the current Flutter auth gate still calls
  // completeSignIn; it now resolves through the allowlist like bootstrapUser.
  completeSignInHandler: bootstrapUserHandler,
};