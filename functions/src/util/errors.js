"use strict";

/**
 * Well-formed error codes the callable boundary converts to HttpsError codes.
 * UI + gateway map these names; keep them stable.
 */
const CODES = Object.freeze({
  UNAUTHENTICATED: "unauthenticated",
  UNLINKED: "unlinked",
  ACCOUNT_NOT_REGISTERED: "account-not-registered",
  PERMISSIONS: "permission-denied",
  INVALID_ARGUMENT: "invalid-argument",
  INVALID_EVIDENCE: "invalid-evidence",
  NOT_FOUND: "not-found",
  FAILED_PRECONDITION: "failed-precondition",
  CONFLICT: "aborted",
  CAPACITY: "resource-exhausted",
  INTERNAL: "internal",
});

class FunctionError extends Error {
  constructor(code, message, details) {
    super(message);
    this.name = "FunctionError";
    this.code = code;
    this.details = details;
  }
}

function httpError(code, message, details) {
  return new FunctionError(code, message, details);
}

module.exports = { CODES, FunctionError, httpError };