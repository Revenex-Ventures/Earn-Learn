"use strict";

const { describe, it, before } = require("node:test");
const assert = require("node:assert/strict");
const ExcelJS = require("exceljs");

const h = require("../helpers/emulator");
const { applySeeds } = require("../../src/seeds");

const RUN = process.env.EMULATOR_INTEGRATION === "1";

/**
 * Stage-2B roster import over the emulator. Every workbook row uses synthetic
 * template data (ids, names, emails, coordinates) — no real roster exists.
 */

async function buildWorkbook() {
  const wb = new ExcelJS.Workbook();
  const addSheet = (name, headers, rows) => {
    const ws = wb.addWorksheet(name);
    ws.addRow(headers);
    for (const r of rows) ws.addRow(r);
  };
  addSheet("locations", ["id", "name", "latitude", "longitude", "radiusMeters"], [
    ["LOC-2001", "Roster Location One", 19.5, 74.25, 100],
  ]);
  addSheet("supervisors", ["id", "name", "email", "assignedLocationIds"], [
    ["SV-2001", "Roster Supervisor A", "roster.supervisor.a@avcoe.example.edu", "LOC-2001"],
    ["SV-BAD", "Roster Supervisor B", ""],
  ]);
  addSheet("students", ["id", "name", "email", "rollNumber", "department", "class"], [
    ["STU-2001", "Roster Student A", "roster.student.a@avcoe.example.edu", "RSR-2001", "ECE", "VII"],
    ["STU-BAD", "Roster Student B", ""],
    ["STU-CONF", "Roster Student C", "roster.student.c@avcoe.example.edu", "RSR-2002", "ECE", "VII"],
  ]);
  addSheet("assignments", ["studentId", "locationId", "supervisorId", "shiftWindows", "maxMonthlyHours", "effectiveFrom"], [
    ["STU-2001", "LOC-2001", "SV-2001", "16:00-18:00", 40, "2024-01-01"],
    ["STU-2001", "LOC-MISS", "SV-2001", "16:00-18:00", 40, "2024-01-01"],
    ["STU-NOPE", "LOC-2001", "SV-2001", "16:00-18:00", 40, "2024-01-01"],
  ]);
  return wb;
}

describe("importRoster integration (emulator)", { skip: !RUN }, () => {
  before(async () => {
    const admin = h.initAdmin();
    await applySeeds({ db: admin.firestore(), auth: admin.auth() });
  });

  async function workbookBase64(wb) {
    const buffer = await wb.xlsx.writeBuffer();
    return buffer.toString("base64");
  }

  it("non-admin accounts are denied import authority", async () => {
    const stu = await h.signIn("synthetic.one@avcoe.example.edu", "synthetic-Pw-9001");
    const wb = await buildWorkbook();
    await assert.rejects(
      async () =>
        h.callFunction("importRoster", stu.idToken, {
          fileName: "denied.xlsx",
          base64: await workbookBase64(wb),
        }),
      (err) => {
        assert.equal(err.status, 403);
        assert.ok(JSON.stringify(err.body).includes("permission-denied"), JSON.stringify(err.body));
        return true;
      }
    );
  });

  it("imports a clean workbook: valid records land, issues are reported, blocksProduction", async () => {
    const adm = await h.signIn("synthetic.admin@avcoe.example.edu", "synthetic-Pw-9004");
    const wb = await buildWorkbook();
    const res = await h.callFunction("importRoster", adm.idToken, {
      fileName: "synthetic-roster.xlsx",
      base64: await workbookBase64(wb),
    });

    assert.equal(res.data.ok, true);
    assert.equal(res.data.blocksProduction, true, "missing emails must block production");

    assert.equal(res.data.summary.locations, 1);
    assert.equal(res.data.summary.supervisors, 1, "SV-BAD (no email) excluded");
    assert.equal(res.data.summary.students, 2, "STU-BAD (no email) excluded");
    assert.equal(res.data.summary.assignments, 1, "invalid assignments excluded");

    const i = (code) => res.data.issues.filter((x) => x.code === code).length;
    assert.equal(i("MISSING_EMAIL"), 2);
    assert.equal(i("MISSING_LOCATION_ID"), 0);
    assert.equal(i("INVALID_ASSIGNMENT"), 2);

    const db = h.db();
    const loc = (await db.doc("locations/LOC-2001").get()).data();
    assert.equal(loc.name, "Roster Location One");
    assert.equal(loc.latitude, 19.5);
    assert.equal(loc.requiresConfiguration, false);

    const sup = (await db.doc("supervisors/SV-2001").get()).data();
    assert.equal(sup.emailNormalized, "roster.supervisor.a@avcoe.example.edu");

    const stu = (await db.doc("students/STU-2001").get()).data();
    assert.equal(stu.emailNormalized, "roster.student.a@avcoe.example.edu");
    assert.equal(stu.rollNumber, "RSR-2001");

    const asn = (await db.doc("assignments/STU-2001").get()).data();
    assert.equal(asn.locationId, "LOC-2001");
    assert.equal(asn.supervisorId, "SV-2001");
    assert.equal(asn.shiftWindows[0].startMin, 960);
    assert.equal(asn.shiftWindows[0].endMin, 1080);

    assert.equal(
      (await db.doc("accessAllowlist/roster.student.a@avcoe.example.edu").get()).exists,
      true
    );
    assert.equal(
      (await db.doc("accessAllowlist/roster.supervisor.a@avcoe.example.edu").get()).data().role,
      "supervisor"
    );
    // Records that fail validation must NOT be allowlisted.
    assert.equal((await db.collection("accessAllowlist").get()).size, 2 + Object.keys(require("../../src/seeds").SEED.accessAllowlist).length);
  });

  it("re-import of identical data is idempotent", async () => {
    const adm = await h.signIn("synthetic.admin@avcoe.example.edu", "synthetic-Pw-9004");
    const wb = await buildWorkbook();
    const res = await h.callFunction("importRoster", adm.idToken, {
      base64: await workbookBase64(wb),
    });
    assert.equal(res.data.applied.written, 0);
    assert.ok(res.data.applied.unchanged > 0);
    assert.equal(res.data.applied.conflicts.length, 0);
  });

  it("conflicting existing records are reported and never overwritten", async () => {
    const adm = await h.signIn("synthetic.admin@avcoe.example.edu", "synthetic-Pw-9004");
    await h.db().doc("students/STU-CONF").update({ name: "Changed Outside Roster" });

    const wb = await buildWorkbook();
    const res = await h.callFunction("importRoster", adm.idToken, {
      base64: await workbookBase64(wb),
    });

    const conflict = res.data.applied.conflicts.find(
      (c) => c.kind === "students" && c.id === "STU-CONF"
    );
    assert.ok(conflict, "conflict must be reported");
    assert.equal(
      (await h.db().doc("students/STU-CONF").get()).data().name,
      "Changed Outside Roster",
      "the out-of-band change must be preserved"
    );
  });
});