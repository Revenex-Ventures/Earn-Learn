"use strict";

const { describe, it, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { initializeTestEnvironment, assertSucceeds, assertFails } =
  require("@firebase/rules-unit-testing");

const h = require("../helpers/emulator");
const RUN = process.env.EMULATOR_INTEGRATION === "1";
const projectId = RUN ? h.projectId() : "demo-earn-and-learn";

let env;

const RUN_DESCRIBE = { skip: !RUN };

before(async () => {
  if (!RUN) return;
  env = await initializeTestEnvironment({
    projectId,
    firestore: { host: "127.0.0.1", port: 8080 },
  });
});

after(async () => {
  if (RUN) await env?.cleanup();
});

describe("firestore rules (Stage 2A)", RUN_DESCRIBE, () => {
  it("clients cannot write authoritative attendance documents", async () => {
    const alice = env.authenticatedContext("alice", {});
    await assertFails(
      alice
        .firestore()
        .doc("attendance/STU-1/2026-09/2026-09-19")
        .set({ status: "working" })
    );
  });

  it("clients cannot write /users role or status", async () => {
    const bob = env.authenticatedContext("bob", {});
    await assertFails(
      bob
        .firestore()
        .doc("users/bob")
        .set({ role: "supervisor", status: "active" })
    );
    await assertFails(
      bob.firestore().doc("users/bob").update({ linkedEntityId: "SV-1" })
    );
  });

  it("clients cannot write directory, assignments, or operations", async () => {
    const c = env.authenticatedContext("carol", {});
    await assertFails(c.firestore().doc("students/STU-1").set({ name: "x" }));
    await assertFails(c.firestore().doc("assignments/STU-1").set({}));
    await assertFails(
      c.firestore().doc("operations/me/2026-09/abc").set({})
    );
    await assertFails(c.firestore().doc("anything/else").set({}));
  });

  it("a student reads their own users doc (rule allows own get)", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("users/alice").set({ uid: "alice", role: "student" });
    });
    const alice = env.authenticatedContext("alice", {});
    const snap = await assertSucceeds(
      alice.firestore().doc("users/alice").get()
    );
    assert.strictEqual(snap.exists, true);
  });

  it("a student cannot read another user's doc", async () => {
    const eve = env.authenticatedContext("eve", {});
    await assertFails(eve.firestore().doc("users/alice").get());
  });

  it("directory is readable by signed-in users", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc("students/STU-9001").set({ name: "synthetic" });
    });
    const dave = env.authenticatedContext("dave", {});
    const snap = await assertSucceeds(
      dave.firestore().doc("students/STU-9001").get()
    );
    assert.strictEqual(snap.data()?.name, "synthetic");
  });
});