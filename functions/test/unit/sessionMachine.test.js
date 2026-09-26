"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");

const machine = require("../../src/domain/sessionMachine");

const baseSession = (status = "scheduled") => ({
  id: "2026-09-19",
  studentId: "STU-9001",
  windows: [{ startMin: 16 * 60, endMin: 18 * 60 }],
  status,
  review: "pending",
  verifiedHours: 0,
  checkInRequestedAt: null,
  checkInVerifiedAt: null,
  checkOutRequestedAt: null,
  checkOutVerifiedAt: null,
  reason: null,
});

describe("sessionMachine (parity with Dart SessionStateMachine)", () => {
  it("complete happy path: scheduled → checkInPending → working → checkOutPending → submitted", () => {
    let s = baseSession();
    s = machine.requestCheckIn(s, new Date("2026-09-19T10:00:00Z"));
    assert.equal(s.status, "checkInPending");
    assert.equal(s.checkInRequestedAt, "2026-09-19T10:00:00.000Z");

    s = machine.completeCheckIn(s, {
      verifiedAt: new Date("2026-09-19T10:01:00Z"),
      evidenceOk: true,
    });
    assert.equal(s.status, "working");
    assert.equal(s.checkInVerifiedAt.toISOString(), "2026-09-19T10:01:00.000Z");

    s = machine.requestCheckOut(s, new Date("2026-09-19T18:00:00Z"));
    assert.equal(s.status, "checkOutPending");

    s = machine.completeCheckOut(s, {
      verifiedAt: new Date("2026-09-19T18:00:05Z"),
      evidenceOk: true,
    });
    assert.equal(s.status, "submitted");
    assert.equal(s.checkOutVerifiedAt.toISOString(), "2026-09-19T18:00:05.000Z");
  });

  it("rejects invalid transitions with InvalidTransitionError", () => {
    const s = baseSession("scheduled");
    assert.throws(() => machine.requestCheckOut(s, new Date()), (err) => {
      assert.equal(err.name, "InvalidTransitionError");
      assert.equal(err.from, "scheduled");
      assert.equal(err.to, "checkOutPending");
      return true;
    });
  });

  it("completeCheckIn with failed evidence keeps pending (no transition)", () => {
    const s = baseSession("checkInPending");
    assert.throws(() =>
      machine.completeCheckIn(s, { verifiedAt: new Date(), evidenceOk: false })
    );
  });

  it("review path submitted → underReview → approved", () => {
    let s = baseSession("submitted");
    s = machine.startReview(s);
    assert.equal(s.status, "underReview");
    s = machine.approve(s);
    assert.equal(s.status, "approved");
    assert.equal(s.review, "approved");
  });

  it("submitted → flagged directly", () => {
    let s = baseSession("submitted");
    s = machine.flag(s, { reason: "Evidence unclear", now: new Date() });
    assert.equal(s.status, "flagged");
    assert.equal(s.review, "flagged");
    assert.equal(s.reason, "Evidence unclear");
  });

  it("working past window end auto-finalizes to submitted", () => {
    const s = machine.autoFinalizeMissedCheckOut(baseSession("working"), {
      windowEnd: "2026-09-19T18:00:00.000Z",
    });
    assert.equal(s.status, "submitted");
    assert.equal(s.checkOutVerifiedAt, "2026-09-19T18:00:00.000Z");
  });

  it("scheduled → missed / cancelled are allowed; terminal states have no edges", () => {
    assert.equal(machine.markMissed(baseSession("scheduled")).status, "missed");
    const approved = machine.approve(baseSession("underReview"));
    assert.equal(machine.ALLOWED_EDGES[approved.status].size, 0);
  });

  it("guard table mirrors the Dart allowedEdges exactly", () => {
    assert.deepEqual(
      [...machine.ALLOWED_EDGES.working],
      ["checkOutPending", "submitted", "missed"]
    );
    assert.deepEqual(
      [...machine.ALLOWED_EDGES.checkInPending],
      ["working", "missed", "cancelled"]
    );
    assert.deepEqual(
      [...machine.ALLOWED_EDGES.submitted],
      ["underReview", "flagged"]
    );
  });
});