"use strict";

const { describe, it, before } = require("node:test");
const assert = require("node:assert/strict");

const h = require("../helpers/emulator");
const { applySeeds } = require("../../src/seeds");

const RUN = process.env.EMULATOR_INTEGRATION === "1";

/**
 * Stage-2B identity bootstrap over the emulator. b0b keeps the attendance
 * flow's pre-seeded accounts untouched — these tests only assert the
 * allowlist → users/{uid} provisioning contract.
 */
describe("bootstrapUser integration (emulator)", { skip: !RUN }, () => {
  before(async () => {
    const admin = h.initAdmin();
    await applySeeds({ db: admin.firestore(), auth: admin.auth() });
  });

  it("provisions an approved student from the allowlist", async () => {
    const stu = await h.signIn("synthetic.one@avcoe.example.edu", "synthetic-Pw-9001");
    const res = await h.callFunction("bootstrapUser", stu.idToken, {});
    assert.equal(res.data.registered, true);
    assert.equal(res.data.role, "student");
    assert.equal(res.data.personId, "STU-9001");
    assert.equal(res.data.status, "active");

    const profile = (await h.db().doc("users/auth-stu-001").get()).data();
    assert.equal(profile.role, "student");
    assert.equal(profile.personId, "STU-9001");
    assert.equal(profile.status, "active");
    assert.equal(profile.emailNormalized, "synthetic.one@avcoe.example.edu");
  });

  it("roles a supervisor and an admin from the allowlist", async () => {
    const sup = await h.signIn("synthetic.supervisor@avcoe.example.edu", "synthetic-Pw-9003");
    const sres = await h.callFunction("bootstrapUser", sup.idToken, {});
    assert.equal(sres.data.role, "supervisor");
    assert.equal(sres.data.personId, "SV-9001");

    const adm = await h.signIn("synthetic.admin@avcoe.example.edu", "synthetic-Pw-9004");
    const ares = await h.callFunction("bootstrapUser", adm.idToken, {});
    assert.equal(ares.data.role, "admin");
    assert.equal(ares.data.personId, "ADM-9001");
  });

  it("rejects a Google account not on the roster (account-not-registered)", async () => {
    const unk = await h.signIn("synthetic.unknown@avcoe.example.edu", "synthetic-Pw-9008");
    await assert.rejects(
      () => h.callFunction("bootstrapUser", unk.idToken, {}),
      (err) => {
        assert.equal(err.status, 404);
        assert.ok(JSON.stringify(err.body).includes("account-not-registered"), JSON.stringify(err.body));
        return true;
      }
    );
  });

  it("rejects an unverified Google email", async () => {
    const unv = await h.signIn("synthetic.unverified@avcoe.example.edu", "synthetic-Pw-9007");
    await assert.rejects(
      () => h.callFunction("bootstrapUser", unv.idToken, {}),
      (err) => {
        assert.equal(err.status, 400);
        assert.ok(JSON.stringify(err.body).includes("failed-precondition"), JSON.stringify(err.body));
        return true;
      }
    );
  });

  it("rejects an inactive (suspended) allowlist account", async () => {
    const ina = await h.signIn("synthetic.inactive@avcoe.example.edu", "synthetic-Pw-9006");
    await assert.rejects(
      () => h.callFunction("bootstrapUser", ina.idToken, {}),
      (err) => {
        assert.equal(err.status, 400);
        assert.match(JSON.stringify(err.body), /not approved/i);
        return true;
      }
    );
  });

  it("ignores a client-supplied role — allowlist always wins", async () => {
    const stu = await h.signIn("synthetic.two@avcoe.example.edu", "synthetic-Pw-9002");
    const res = await h.callFunction("bootstrapUser", stu.idToken, {
      role: "admin",
      personId: "HACKED",
      status: "admin",
      email: "attacker@evil.example",
    });
    assert.equal(res.data.role, "student");
    assert.equal(res.data.personId, "STU-9002");

    const profile = (await h.db().doc("users/auth-stu-002").get()).data();
    assert.equal(profile.role, "student");
    assert.equal(profile.personId, "STU-9002");
  });

  it("is idempotent — rebootstrapping the same account keeps identity stable", async () => {
    const stu = await h.signIn("synthetic.one@avcoe.example.edu", "synthetic-Pw-9001");
    const res = await h.callFunction("bootstrapUser", stu.idToken, {});
    assert.equal(res.data.role, "student");
    assert.equal(res.data.personId, "STU-9001");
    assert.equal(typeof res.data.created, "boolean");

    const profile = (await h.db().doc("users/auth-stu-001").get()).data();
    assert.equal(profile.role, "student");
    assert.equal(profile.personId, "STU-9001");
    assert.equal(profile.status, "active");
  });

  it("completeSignIn still resolves through the same allowlist gate", async () => {
    const stu = await h.signIn("synthetic.one@avcoe.example.edu", "synthetic-Pw-9001");
    const res = await h.callFunction("completeSignIn", stu.idToken, {});
    assert.equal(res.data.role, "student");
    assert.equal(res.data.personId, "STU-9001");
  });
});