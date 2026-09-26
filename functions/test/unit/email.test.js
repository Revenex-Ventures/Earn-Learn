"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const { normalizeEmail, assertNormalizedEmail } = require("../../src/util/email");
const { FunctionError } = require("../../src/util/errors");

describe("normalizeEmail", () => {
  it("trims and lower-cases", () => {
    assert.equal(normalizeEmail("  Student@AVCOE.Example.Edu "), "student@avcoe.example.edu");
  });

  it("rejects invalid or non-string input", () => {
    assert.equal(normalizeEmail("not-an-email"), null);
    assert.equal(normalizeEmail("a@b"), null);
    assert.equal(normalizeEmail(null), null);
    assert.equal(normalizeEmail(""), null);
  });

  it("assertNormalizedEmail throws a FunctionError for bad emails", () => {
    assert.throws(() => assertNormalizedEmail("X"), FunctionError);
  });

  it("returns the canonical form for valid emails", () => {
    assert.equal(assertNormalizedEmail("A@B.com"), "a@b.com");
  });
});