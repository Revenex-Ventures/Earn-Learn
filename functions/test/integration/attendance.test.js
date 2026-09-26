"use strict";

const { describe, it, before } = require("node:test");
const assert = require("node:assert/strict");

const h = require("../helpers/emulator");
const { applySeeds } = require("../../src/seeds");
const sweepSvc = require("../../src/services/sweep");
const { dayKeyFor } = require("../../src/domain/hours");

const RUN = process.env.EMULATOR_INTEGRATION === "1";

const GEO = { lat: 19.5, lng: 74.25, accuracyMeters: 10 };

describe("attendance integration (emulator)", { skip: !RUN }, () => {
  before(async () => {
    const admin = h.initAdmin();
    await applySeeds({ db: admin.firestore(), auth: admin.auth() });
  });

  it("unlinked (pending) account cannot check in", async () => {
    const pending = await h.signIn("synthetic.pending@avcoe.example.edu", "synthetic-Pw-9005");
    await assert.rejects(
      () => h.callFunction("checkIn", pending.idToken, { requestId: "x-1", date: dayKeyFor(new Date()) }),
      (err) => {
        assert.equal(err.status, 400);
        assert.ok(JSON.stringify(err.body).includes("unlinked"), JSON.stringify(err.body));
        return true;
      }
    );
  });

  it("unauthenticated call is rejected", async () => {
    await assert.rejects(
      () => h.callFunction("checkIn", null, { requestId: "x-2" }),
      (err) => {
        assert.equal(err.status, 401);
        return true;
      }
    );
  });

  it("STU-9001 full flow: check-in → working → submitted → supervisor approves", async () => {
    const stu = await h.signIn("synthetic.one@avcoe.example.edu", "synthetic-Pw-9001");
    const sup = await h.signIn("synthetic.supervisor@avcoe.example.edu", "synthetic-Pw-9003");

    const dateKey = dayKeyFor(new Date());
    const rq = `it${Date.now()}`;

    const opened = await h.callFunction("checkIn", stu.idToken, {
      requestId: rq,
      date: dateKey,
      geo: GEO,
    });
    assert.equal(opened.data.sessionId, dateKey);
    assert.ok(opened.data.uploadTarget.startsWith("evidence/auth-stu-001/"));

    const uploadPath = opened.data.uploadTarget;
    await h.bucket().file(uploadPath).save(Buffer.from("selfie-checksum-fake"), {
      contentType: "image/png",
      metadata: { contentType: "image/png", cacheControl: "public, max-age=31536000" },
    });

    const confirmed = await h.callFunction("confirmCheckIn", stu.idToken, {
      sessionId: dateKey,
      requestId: rq,
      uploadPath,
      geo: GEO,
    });
    assert.equal(confirmed.data.status, "working");
    assert.equal(confirmed.data.geoVerified, true);

    const coRq = `it${Date.now()}co`;
    const checkout = await h.callFunction("checkOut", stu.idToken, {
      requestId: coRq,
      sessionId: dateKey,
      geo: GEO,
    });
    assert.equal(checkout.data.sessionId, dateKey);
    await h.bucket().file(checkout.data.uploadTarget).save(Buffer.from("selfie-out-fake"), {
      contentType: "image/png",
      metadata: { contentType: "image/png" },
    });

    const confirmedOut = await h.callFunction("confirmCheckOut", stu.idToken, {
      sessionId: dateKey,
      requestId: coRq,
      uploadPath: checkout.data.uploadTarget,
      geo: GEO,
    });
    assert.equal(confirmedOut.data.status, "submitted");

    const queue = await h.callFunction("myQueue", sup.idToken, {});
    const mine = queue.data.items.find((i) => i.studentId === "STU-9001");
    assert.ok(mine, "STU-9001 session must be in the supervisor queue");

    const evidence = await h.callFunction("getEvidence", sup.idToken, {
      sessionId: dateKey,
      studentId: "STU-9001",
      kind: "checkin",
    });
    assert.ok(evidence.data.url.includes("9199"), evidence.data.url);

    const reviewed = await h.callFunction("review", sup.idToken, {
      sessionId: dateKey,
      studentId: "STU-9001",
      decision: "approved",
      note: "Emulator integration approval.",
    });
    assert.equal(reviewed.data.status, "approved");
    assert.equal(reviewed.data.review, "approved");
  });

  it("confirmCheckIn without uploaded evidence stays pending (resumable)", async () => {
    const stu = await h.signIn("synthetic.two@avcoe.example.edu", "synthetic-Pw-9002");
    const dateKey = dayKeyFor(new Date());
    const rq = `itmissing${Date.now()}`;

    const opened = await h.callFunction("checkIn", stu.idToken, {
      requestId: rq,
      date: dateKey,
    });
    const uploadPath = opened.data.uploadTarget;

    await assert.rejects(
      () =>
        h.callFunction("confirmCheckIn", stu.idToken, {
          sessionId: dateKey,
          requestId: rq,
          uploadPath,
          geo: GEO,
        }),
      (err) => {
        assert.ok(JSON.stringify(err.body).includes("invalid-evidence"), JSON.stringify(err.body));
        return true;
      }
    );

    await h.bucket().file(uploadPath).save(Buffer.from("selfie-retry"), {
      contentType: "image/png",
      metadata: { contentType: "image/png" },
    });
    const retried = await h.callFunction("confirmCheckIn", stu.idToken, {
      sessionId: dateKey,
      requestId: rq,
      uploadPath,
      geo: GEO,
    });
    assert.equal(retried.data.status, "working");
  });

  it("sweep marks pending sessions missed and auto-finalizes open working sessions", async () => {
    const admin = h.initAdmin();
    const db = admin.firestore();
    const yesterday = dayKeyFor(new Date(Date.now() - 24 * 60 * 60 * 1000));
    const month = yesterday.slice(0, 7);

    await db.doc(`attendance/STU-9001/${month}/${yesterday}`).set({
      status: "checkInPending",
      studentId: "STU-9001",
      windows: [{ startMin: 16 * 60, endMin: 18 * 60 }],
      review: "pending",
      verifiedHours: 0,
      checkInRequestedAt: new Date(Date.now() - 25 * 60 * 60 * 1000),
      checkInVerifiedAt: null,
      checkOutRequestedAt: null,
      checkOutVerifiedAt: null,
    });

    await db.doc(`attendance/STU-9002/${month}/${yesterday}`).set({
      status: "working",
      studentId: "STU-9002",
      windows: [{ startMin: 17 * 60, endMin: 19 * 60 }],
      review: "pending",
      verifiedHours: 0,
      checkInRequestedAt: new Date(Date.now() - 26 * 60 * 60 * 1000),
      checkInVerifiedAt: new Date(Date.now() - 25 * 60 * 60 * 1000),
      checkOutRequestedAt: null,
      checkOutVerifiedAt: null,
    });

    const report = await sweepSvc.sweepAttendance({ db, storage: admin.storage(), dateKey: yesterday });
    assert.ok(Array.isArray(report.missed));
    assert.ok(Array.isArray(report.finalized));

    const s1 = (await db.doc(`attendance/STU-9001/${month}/${yesterday}`).get()).data();
    assert.equal(s1.status, "missed");
    assert.ok(s1.reason, "missed sweep reason expected");

    const s2 = (await db.doc(`attendance/STU-9002/${month}/${yesterday}`).get()).data();
    assert.equal(s2.status, "submitted");
  });
});