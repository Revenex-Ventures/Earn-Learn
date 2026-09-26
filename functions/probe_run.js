"use strict";

const fs = require("node:fs");
const path = require("node:path");
const h = require("./test/helpers/emulator");
const { applySeeds, SEED } = require("./src/seeds");

const OUT = path.join(__dirname, "probe6.json");

async function rawCall(name, idToken, data) {
  const host = process.env.FIREBASE_FUNCTIONS_HOST || "127.0.0.1";
  const port = process.env.FIREBASE_FUNCTIONS_PORT || "5001";
  const project = process.env.GCLOUD_PROJECT || "earn-and-learn";
  const url = `http://${host}:${port}/${project}/asia-south1/${name}`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
    },
    body: JSON.stringify({ data: data ?? {} }),
  });
  const rawText = await res.text();
  let parsed = null;
  try {
    parsed = JSON.parse(rawText);
  } catch (_e) {
    /* keep null */
  }
  return { url, status: res.status, rawText, parsed };
}

async function main() {
  const report = {
    env: {
      GCLOUD_PROJECT: process.env.GCLOUD_PROJECT || null,
      FIRESTORE_EMULATOR_HOST: process.env.FIRESTORE_EMULATOR_HOST || null,
      FIREBASE_AUTH_EMULATOR_HOST: process.env.FIREBASE_AUTH_EMULATOR_HOST || null,
      FIREBASE_STORAGE_EMULATOR_HOST: process.env.FIREBASE_STORAGE_EMULATOR_HOST || null,
      FIREBASE_FUNCTIONS_HOST: process.env.FIREBASE_FUNCTIONS_HOST || null,
      FIREBASE_FUNCTIONS_PORT: process.env.FIREBASE_FUNCTIONS_PORT || null,
      ALLOW_SEEDS: process.env.ALLOW_SEEDS || null,
    },
    seed: null,
    allowlist: null,
    authUser: null,
    bootstrapStudent: null,
    userDocAfter: null,
    negativePaths: {},
    spoofedRole: null,
    err: null,
  };

  try {
    const admin = h.initAdmin();
    const seed = await applySeeds({ db: admin.firestore(), auth: admin.auth() });
    report.seed = { written: seed.written };

    const allowSnap = await admin
      .firestore()
      .doc("accessAllowlist/synthetic.one@avcoe.example.edu")
      .get();
    report.allowlist = allowSnap.exists ? { id: allowSnap.id, ...allowSnap.data() } : null;

    const authUser = await admin.auth().getUser("auth-stu-001");
    report.authUser = {
      uid: authUser.uid,
      email: authUser.email,
      emailVerified: authUser.emailVerified,
      disabled: authUser.disabled,
    };

    const cases = [
      ["unknown", "synthetic.unknown@avcoe.example.edu", "synthetic-Pw-9008"],
      ["unverified", "synthetic.unverified@avcoe.example.edu", "synthetic-Pw-9007"],
      ["inactive", "synthetic.inactive@avcoe.example.edu", "synthetic-Pw-9006"],
      ["student", "synthetic.one@avcoe.example.edu", "synthetic-Pw-9001"],
    ];
    for (const [name, email, pw] of cases) {
      const signin = await h.signIn(email, pw);
      const call = await rawCall("bootstrapUser", signin.idToken, {});
      report.negativePaths[name] = {
        uid: signin.uid,
        signInOk: true,
        status: call.status,
        rawText: call.rawText,
        parsed: call.parsed,
      };
    }

    const stu = await h.signIn("synthetic.two@avcoe.example.edu", "synthetic-Pw-9002");
    const spoofed = await rawCall("bootstrapUser", stu.idToken, {
      role: "admin",
      personId: "HACKED",
      status: "admin",
      email: "attacker@evil.example",
    });
    report.spoofedRole = spoofed;

    const userDocAfter = await admin.firestore().doc("users/auth-stu-001").get();
    report.userDocAfter = userDocAfter.exists ? userDocAfter.data() : null;
  } catch (e) {
    report.err = { name: e.name, message: e.message, stack: e.stack };
  }

  fs.writeFileSync(OUT, JSON.stringify(report, null, 2));
  // eslint-disable-next-line no-console
  console.log(JSON.stringify(report, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    // eslint-disable-next-line no-console
    console.error("PROBE_FATAL", e);
    process.exit(1);
  });