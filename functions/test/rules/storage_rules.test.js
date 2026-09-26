"use strict";

const { describe, it, before, after } = require("node:test");
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
    storage: { host: "127.0.0.1", port: 9199 },
  });
  await env.clearStorage();
});

after(async () => {
  if (RUN) await env?.cleanup();
});

const SELFIE = Buffer.from("fake-image-bytes-for-rules-test");

describe("storage rules (Stage 2A evidence)", RUN_DESCRIBE, () => {
  it("a student may create evidence only in their own path (immutable, once)", async () => {
    const sto = env.authenticatedContext("auth-stu-001", {}).storage();
    const own = sto.ref("evidence/auth-stu-001/2026-09-19/rq1_checkin.jpg");
    await assertSucceeds(own.put(SELFIE, { contentType: "image/png" }));
    // Immutable: a second write to the same path is denied.
    await assertFails(own.put(SELFIE, { contentType: "image/png" }));
  });

  it("a student cannot upload into another user's evidence path", async () => {
    const sto = env.authenticatedContext("auth-stu-001", {}).storage();
    await assertFails(
      sto
        .ref("evidence/auth-stu-002/2026-09-19/rq1_checkin.jpg")
        .put(SELFIE, { contentType: "image/png" })
    );
  });

  it("non-image or oversized evidence is rejected", async () => {
    const sto = env.authenticatedContext("auth-stu-001", {}).storage();
    await assertFails(
      sto
        .ref("evidence/auth-stu-001/2026-09-20/rq2_checkin.jpg")
        .put(Buffer.from("not an image"), { contentType: "text/plain" })
    );
    const huge = Buffer.alloc(9 * 1024 * 1024, 1);
    await assertFails(
      sto
        .ref("evidence/auth-stu-001/2026-09-21/rq3_checkin.jpg")
        .put(huge, { contentType: "image/png" })
    );
  });

  it("clients cannot read evidence directly", async () => {
    const sto = env.authenticatedContext("auth-stu-001", {}).storage();
    const ref = sto.ref("evidence/auth-stu-001/2026-09-19/rq1_checkin.jpg");
    await assertFails(ref.getDownloadURL());
    await assertFails(ref.delete());
  });
});