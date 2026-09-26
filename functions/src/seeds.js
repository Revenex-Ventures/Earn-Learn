"use strict";

const { FieldValue } = require("./firebase");

/**
 * Synthetic (clearly fake) emulator-only fixtures for Stage 2A integration
 * tests. Nothing institutional is imported here — real directory data is a
 * college-supplied, separately-validated import (tools/import_directory.mjs).
 *
 * Availability guard: the `seedSyntheticData` callable only exists when
 * ALLOW_SEEDS=1 (set by the emulator test npm script).
 */

const now = new Date().toISOString();
const page = (name, email, pw, opts = {}) => ({
  name,
  email,
  password: pw,
  disabled: false,
  emailVerified: opts.emailVerified !== false,
});

const SEED = {
  locations: {
    "LOC-9001": {
      id: "LOC-9001",
      name: "Synthetic Test Location",
      description: "Emulator-only synthetic site for Stage 2A integration tests.",
      latitude: 19.5,
      longitude: 74.25,
      radiusMeters: 100,
      supervisorIds: ["SV-9001"],
      studentIds: ["STU-9001", "STU-9002"],
      status: "active",
    },
  },
  supervisors: {
    "SV-9001": {
      id: "SV-9001",
      name: "Synthetic Supervisor One",
      uid: "auth-sup-001",
      department: "EXAMPLE",
      email: "synthetic.supervisor@avcoe.example.edu",
      assignedLocationIds: ["LOC-9001"],
      status: "onDuty",
    },
  },
  students: {
    "STU-9001": {
      id: "STU-9001",
      name: "Synthetic Student One",
      rollNumber: "SYN-9001",
      uid: "auth-stu-001",
      email: "synthetic.one@avcoe.example.edu",
      department: "EXAMPLE",
      className: "SYN-A",
      status: "active",
    },
    "STU-9002": {
      id: "STU-9002",
      name: "Synthetic Student Two",
      rollNumber: "SYN-9002",
      uid: "auth-stu-002",
      email: "synthetic.two@avcoe.example.edu",
      department: "EXAMPLE",
      className: "SYN-B",
      status: "active",
    },
  },
  assignments: {
    "STU-9001": {
      studentId: "STU-9001",
      locationId: "LOC-9001",
      supervisorId: "SV-9001",
      workDescription: "Synthetic emulator duty (selfie + GPS verification).",
      shiftWindows: [{ startMin: 16 * 60, endMin: 18 * 60 }],
      effectiveFrom: "2000-01-01",
      effectiveTo: null,
      maxMonthlyHours: 40,
      status: "active",
    },
    "STU-9002": {
      studentId: "STU-9002",
      locationId: "LOC-9001",
      supervisorId: "SV-9001",
      workDescription: "Synthetic emulator duty (selfie + GPS verification).",
      shiftWindows: [{ startMin: 17 * 60, endMin: 19 * 60 }],
      effectiveFrom: "2000-01-01",
      effectiveTo: null,
      maxMonthlyHours: 40,
      status: "active",
    },
  },
  users: {
    "auth-stu-001": { role: "student", status: "active", linkedEntityId: "STU-9001" },
    "auth-stu-002": { role: "student", status: "active", linkedEntityId: "STU-9002" },
    "auth-sup-001": { role: "supervisor", status: "active", linkedEntityId: "SV-9001" },
    "auth-admin-001": { role: "admin", status: "active", linkedEntityId: null },
    "auth-stu-pending": { role: "student", status: "pending", linkedEntityId: null },
  },
  // Stage-2B server-only allowlist, mirroring what a real importRoster write
  // produces. bootstrapUser reads these and provisions users from them.
  accessAllowlist: {
    "synthetic.one@avcoe.example.edu": {
      normalizedEmail: "synthetic.one@avcoe.example.edu",
      email: "synthetic.one@avcoe.example.edu",
      personId: "STU-9001",
      role: "student",
      name: "Synthetic Student One",
      source: "seed",
      sourceRow: 2,
      status: "active",
    },
    "synthetic.two@avcoe.example.edu": {
      normalizedEmail: "synthetic.two@avcoe.example.edu",
      email: "synthetic.two@avcoe.example.edu",
      personId: "STU-9002",
      role: "student",
      name: "Synthetic Student Two",
      source: "seed",
      sourceRow: 3,
      status: "active",
    },
    "synthetic.supervisor@avcoe.example.edu": {
      normalizedEmail: "synthetic.supervisor@avcoe.example.edu",
      email: "synthetic.supervisor@avcoe.example.edu",
      personId: "SV-9001",
      role: "supervisor",
      name: "Synthetic Supervisor One",
      source: "seed",
      sourceRow: 2,
      status: "active",
    },
    "synthetic.admin@avcoe.example.edu": {
      normalizedEmail: "synthetic.admin@avcoe.example.edu",
      email: "synthetic.admin@avcoe.example.edu",
      personId: "ADM-9001",
      role: "admin",
      name: "Synthetic Admin One",
      source: "seed",
      sourceRow: 2,
      status: "active",
    },
    // Approved account whose allowlist is suspended -> bootstrap rejected.
    "synthetic.inactive@avcoe.example.edu": {
      normalizedEmail: "synthetic.inactive@avcoe.example.edu",
      email: "synthetic.inactive@avcoe.example.edu",
      personId: "STU-9003",
      role: "student",
      name: "Inactive Synthetic Student",
      source: "seed",
      sourceRow: 2,
      status: "inactive",
    },
    // Verified-email gate: allowlist exists but the token claims unverified.
    "synthetic.unverified@avcoe.example.edu": {
      normalizedEmail: "synthetic.unverified@avcoe.example.edu",
      email: "synthetic.unverified@avcoe.example.edu",
      personId: "STU-9004",
      role: "student",
      name: "Unverified Synthetic Student",
      source: "seed",
      sourceRow: 2,
      status: "active",
    },
  },
  auth: [
    page("Synthetic Student One", "synthetic.one@avcoe.example.edu", "synthetic-Pw-9001"),
    page("Synthetic Student Two", "synthetic.two@avcoe.example.edu", "synthetic-Pw-9002"),
    page("Synthetic Supervisor One", "synthetic.supervisor@avcoe.example.edu", "synthetic-Pw-9003"),
    page("Synthetic Admin One", "synthetic.admin@avcoe.example.edu", "synthetic-Pw-9004"),
    page("Synthetic Pending Student", "synthetic.pending@avcoe.example.edu", "synthetic-Pw-9005"),
    page("Inactive Synthetic Student", "synthetic.inactive@avcoe.example.edu", "synthetic-Pw-9006"),
    page("Unverified Synthetic Student", "synthetic.unverified@avcoe.example.edu", "synthetic-Pw-9007", { emailVerified: false }),
    page("Unknown Synthetic Account", "synthetic.unknown@avcoe.example.edu", "synthetic-Pw-9008"),
  ],
};

const uidForEmail = {
  "synthetic.one@avcoe.example.edu": "auth-stu-001",
  "synthetic.two@avcoe.example.edu": "auth-stu-002",
  "synthetic.supervisor@avcoe.example.edu": "auth-sup-001",
  "synthetic.admin@avcoe.example.edu": "auth-admin-001",
  "synthetic.pending@avcoe.example.edu": "auth-stu-pending",
  "synthetic.inactive@avcoe.example.edu": "auth-stu-inactive",
  "synthetic.unverified@avcoe.example.edu": "auth-stu-unverified",
  "synthetic.unknown@avcoe.example.edu": "auth-stu-unknown",
};

async function applySeeds({ db, auth }) {
  const written = {
    locations: 0,
    supervisors: 0,
    students: 0,
    assignments: 0,
    users: 0,
    accessAllowlist: 0,
    auth: 0,
  };

  const touch = (data, path) => {
    // eslint-disable-next-line no-console
    console.log(`SEED ${path} ${data.id || path}`);
  };

  const putIfAbsent = async (col, id, data) => {
    const ref = db.doc(`${col}/${id}`);
    const snap = await ref.get();
    if (!snap.exists) {
      await ref.set({ ...data, createdAt: now, updatedAt: now });
      written[col === "users" ? "users" : col] += 1;
      touch({ id }, `${col}/${id}`);
    }
  };

  for (const [id, data] of Object.entries(SEED.locations)) await putIfAbsent("locations", id, data);
  for (const [id, data] of Object.entries(SEED.supervisors)) await putIfAbsent("supervisors", id, data);
  for (const [id, data] of Object.entries(SEED.students)) await putIfAbsent("students", id, data);
  for (const [id, data] of Object.entries(SEED.assignments)) await putIfAbsent("assignments", id, data);
  for (const [uid, data] of Object.entries(SEED.users)) {
    const ref = db.doc(`users/${uid}`);
    const snap = await ref.get();
    if (!snap.exists) {
      await ref.set({ ...data, uid, updatedAt: now, createdAt: now });
      written.users += 1;
    }
  }

  for (const [email, data] of Object.entries(SEED.accessAllowlist)) {
    await putIfAbsent("accessAllowlist", email, data);
  }

  for (const account of SEED.auth) {
    const uid = uidForEmail[account.email];
    try {
      await auth.getUser(uid);
    } catch (_err) {
      await auth.createUser({
        uid,
        email: account.email,
        password: account.password,
        displayName: account.name,
        emailVerified: account.emailVerified !== false,
      });
      written.auth += 1;
    }
  }

  return { written };
}

module.exports = { applySeeds, SEED };