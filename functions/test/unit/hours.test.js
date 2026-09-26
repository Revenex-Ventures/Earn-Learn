"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const {
  utcStartOfDay,
  dayKeyFor,
  minutesToTime,
  overlapMinutes,
  intersectWindow,
} = require("../../src/domain/hours");

describe("hours (UTC day/window math)", () => {
  it("dayKeyFor is stable in UTC", () => {
    assert.equal(dayKeyFor(new Date("2026-09-19T23:05:00Z")), "2026-09-19");
    assert.equal(dayKeyFor(new Date("2026-09-20T00:00:00Z")), "2026-09-20");
  });

  it("utcStartOfDay floor to midnight", () => {
    const d = utcStartOfDay(new Date("2026-09-19T14:22:10.999Z"));
    assert.equal(d.toISOString(), "2026-09-19T00:00:00.000Z");
  });

  it("minutesToTime renders HH:mm", () => {
    assert.equal(minutesToTime(0), "00:00");
    assert.equal(minutesToTime(16 * 60 + 45), "16:45");
    assert.equal(minutesToTime(25 * 60), "25:00");
  });

  it("overlapMinutes counts intersecting frames", () => {
    // [10:00, 11:00] ∩ [10:30, 12:00] = 30
    assert.equal(overlapMinutes(600, 660, 630, 720), 30);
    // disjoint
    assert.equal(overlapMinutes(600, 660, 720, 780), 0);
    // contained
    assert.equal(overlapMinutes(600, 800, 640, 700), 60);
    // zero-width window
    assert.equal(overlapMinutes(600, 600, 600, 700), 0);
  });

  it("intersectWindow clamps to the window frame", () => {
    assert.deepEqual(intersectWindow(590, 650, 600, 720), { startMin: 600, endMin: 650 });
    assert.deepEqual(intersectWindow(700, 800, 600, 720), { startMin: 700, endMin: 720 });
    assert.equal(intersectWindow(740, 800, 600, 720), null);
  });
});