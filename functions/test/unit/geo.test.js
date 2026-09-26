"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const { distanceMeters, isWithinLocation } = require("../../src/domain/geo");

describe("geo", () => {
  it("haversine distance: known distances", () => {
    // Same point
    assert.ok(distanceMeters(19.5, 74.25, 19.5, 74.25) < 1);
    // ~111km per degree of latitude
    const d = distanceMeters(0, 0, 1, 0);
    assert.ok(d > 110000 && d < 112000, `got ${d}`);
  });

  it("isWithinLocation: inside radius", () => {
    const loc = { latitude: 19.5, longitude: 74.25, radiusMeters: 100 };
    assert.equal(
      isWithinLocation({ lat: 19.5, lng: 74.25, accuracyMeters: 5 }, loc),
      true
    );
    assert.equal(
      isWithinLocation({ lat: 19.5004, lng: 74.25, accuracyMeters: 12 }, loc),
      true
    );
  });

  it("isWithinLocation: outside radius", () => {
    const loc = { latitude: 19.5, longitude: 74.25, radiusMeters: 100 };
    assert.equal(
      isWithinLocation({ lat: 19.51, lng: 74.25, accuracyMeters: 0 }, loc),
      false
    );
  });
});