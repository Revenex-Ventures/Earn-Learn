"use strict";

const { CODES, httpError } = require("../util/errors");
const { assertObject, assertString } = require("../util/validation");
const { normalizeEmail } = require("../util/email");
const identity = require("../identity");
const { Timestamp } = require("../firebase");

const ExcelJS = require("exceljs");

/**
 * importRoster — administrative import of the authoritative Excel roster.
 *
 * The workbook is the source of truth for who is eligible. This handler:
 *   - validates required columns per sheet
 *   - normalizes emails
 *   - detects duplicates (student ids, emails), missing student ids, missing
 *     emails, invalid assignments, missing supervisors, missing locations
 *   - produces a validation report; records blocking a production rollout are
 *     reported, NOT silently skipped
 *   - uses deterministic IDs (the workbook's own ids)
 *   - is idempotent: identical re-imports are no-ops; CONFLICTING records are
 *     reported and never silently overwritten
 *   - writes directory docs + accessAllowlist/{normalizedEmail} entries
 */

const REQUIRED = {
  locations: ["id", "name"],
  supervisors: ["id", "name", "email"],
  students: ["id", "name", "email", "rollNumber"],
  assignments: ["studentId", "locationId", "supervisorId", "shiftWindows"],
};

function sheetRows(sheet, headerRow) {
  const headers = sheet.getRow(headerRow).values; // 1-indexed
  const mapping = {};
  headers.forEach((h, i) => {
    if (i < 1 || h == null) return;
    const key = String(h).trim().toLowerCase();
    mapping[key] = i;
  });
  const rows = [];
  sheet.eachRow((row, rowNumber) => {
    if (rowNumber <= headerRow) return;
    const record = { __row: rowNumber, __sheet: sheet.name };
    let any = false;
    for (const [key, idx] of Object.entries(mapping)) {
      if (idx == null) continue;
      const cell = row.getCell(idx).text?.trim?.() ?? "";
      if (cell !== "") {
        record[key] = cell;
        any = true;
      }
    }
    if (any) rows.push(record);
  });
  return rows;
}

function toShiftWindows(raw) {
  if (raw == null || raw === "") return null;
  // Accept "16:00-18:00" or "960-1080".
  const s = String(raw);
  const m = s.match(/^\s*(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})\s*$/);
  if (m) {
    const startMin = Number(m[1]) * 60 + Number(m[2]);
    const endMin = Number(m[3]) * 60 + Number(m[4]);
    return [{ startMin, endMin }];
  }
  const parts = s.split(/\s*-\s*/);
  if (parts.length === 2) {
    const a = Number(parts[0]);
    const b = Number(parts[1]);
    if (Number.isInteger(a) && Number.isInteger(b) && b > a) {
      return [{ startMin: a, endMin: b }];
    }
  }
  return null;
}

/**
 * Parses an .xlsx buffer into typed roster sections plus a per-row issue map.
 * Pure except for Excel parsing — no database reads.
 */
async function parseRosterWorkbook(buffer) {
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.load(buffer);
  const get = (name) => wb.getWorksheet(name);
  const sections = {
    locations: [],
    supervisors: [],
    students: [],
    assignments: [],
  };

  let sheet = get("locations") || get("Locations");
  if (sheet) for (const r of sheetRows(sheet, 1)) sections.locations.push(r);
  sheet = get("supervisors") || get("Supervisors");
  if (sheet) for (const r of sheetRows(sheet, 1)) sections.supervisors.push(r);
  sheet = get("students") || get("Students");
  if (sheet) for (const r of sheetRows(sheet, 1)) sections.students.push(r);
  sheet = get("assignments") || get("Assignments");
  if (sheet) for (const r of sheetRows(sheet, 1)) sections.assignments.push(r);

  const issues = [];
  let blocksProduction = false;
  const pushIssue = (section, rowNumber, code, message) => {
    issues.push({ section, row: rowNumber, code, message });
    if (code === "MISSING_EMAIL" || code === "MISSING_STUDENT_ID" || code === "INVALID_ASSIGNMENT") {
      blocksProduction = true;
    }
  };

  const seenIds = { locations: new Set(), supervisors: new Set(), students: new Set() };
  const seenEmails = new Set();

  for (const row of sections.locations) {
    const id = row.id;
    if (!id) {
      pushIssue("locations", row.__row, "MISSING_LOCATION_ID", "locations require an id");
      continue;
    }
    if (seenIds.locations.has(id)) {
      pushIssue("locations", row.__row, "DUPLICATE_LOCATION_ID", `duplicate location id ${id}`);
      continue;
    }
    seenIds.locations.add(id);
    row.__id = id;
  }
  for (const row of sections.supervisors) {
    const id = row.id;
    if (!id) {
      pushIssue("supervisors", row.__row, "MISSING_SUPERVISOR_ID", "supervisors require an id");
      continue;
    }
    if (seenIds.supervisors.has(id)) {
      pushIssue("supervisors", row.__row, "DUPLICATE_SUPERVISOR_ID", `duplicate supervisor id ${id}`);
      continue;
    }
    seenIds.supervisors.add(id);
    const email = normalizeEmail(row.email);
    if (!email) {
      pushIssue("supervisors", row.__row, "MISSING_EMAIL", `supervisor ${id} has no valid email`);
      continue;
    }
    if (seenEmails.has(email)) {
      pushIssue("supervisors", row.__row, "DUPLICATE_EMAIL", `email ${email} already used`);
      continue;
    }
    seenEmails.add(email);
    row.__id = id;
    row.__email = email;
  }
  for (const row of sections.students) {
    const id = row.id;
    if (!id) {
      pushIssue("students", row.__row, "MISSING_STUDENT_ID", "students require an id");
      continue;
    }
    if (seenIds.students.has(id)) {
      pushIssue("students", row.__row, "DUPLICATE_STUDENT_ID", `duplicate student id ${id}`);
      continue;
    }
    seenIds.students.add(id);
    const email = normalizeEmail(row.email);
    if (!email) {
      pushIssue("students", row.__row, "MISSING_EMAIL", `student ${id} has no valid email`);
      continue;
    }
    if (seenEmails.has(email)) {
      pushIssue("students", row.__row, "DUPLICATE_EMAIL", `email ${email} already used`);
      continue;
    }
    seenEmails.add(email);
    row.__id = id;
    row.__email = email;
  }
  for (const row of sections.assignments) {
    const studentId = row.studentid || row.student;
    if (!studentId) {
      pushIssue("assignments", row.__row, "INVALID_ASSIGNMENT", "assignments require studentId");
      continue;
    }
    if (!seenIds.students.has(studentId)) {
      pushIssue("assignments", row.__row, "INVALID_ASSIGNMENT", `assignment references missing student ${studentId}`);
      continue;
    }
    if (!seenIds.supervisors.has(row.supervisorid)) {
      pushIssue("assignments", row.__row, "INVALID_ASSIGNMENT", `assignment references missing supervisor ${row.supervisorid}`);
      continue;
    }
    if (!seenIds.locations.has(row.locationid)) {
      pushIssue("assignments", row.__row, "INVALID_ASSIGNMENT", `assignment references missing location ${row.locationid}`);
      continue;
    }
    const windows = toShiftWindows(row.shiftwindows || row.schedule);
    if (!windows) {
      pushIssue("assignments", row.__row, "INVALID_ASSIGNMENT", `assignment ${studentId} has an invalid shift window`);
      continue;
    }
    row.__id = studentId;
    row.__windows = windows;
  }

  return {
    issues,
    blocksProduction,
    sections: {
      locations: sections.locations.filter((r) => r.__id),
      supervisors: sections.supervisors.filter((r) => r.__id),
      students: sections.students.filter((r) => r.__id),
      assignments: sections.assignments.filter((r) => r.__id),
    },
  };
}

async function existingData(db, id) {
  const snap = await db.doc(id).get();
  return snap.exists ? snap.data() : null;
}

function dirDoc(db, kind, id) {
  return db.doc(`${kind}/${id}`);
}

/**
 * Applies parsed roster data to the emulator/DB deterministically and
 * idempotently. Returns the apply report (written / unchanged / conflicts).
 * Conflicting records are never overwritten here.
 */
async function applyRoster(db, parsed, now) {
  const report = { written: 0, unchanged: 0, conflicts: [] };

  const writeIfConsistent = async (kind, id, doc) => {
    const ref = dirDoc(db, kind, id);
    const before = await existingData(db, ref.path);
    if (before) {
      const conflict = Object.keys(doc).some((k) => {
        if (k.startsWith("__") || k === "worked") return false;
        return JSON.stringify(before[k] ?? null) !== JSON.stringify(doc[k] ?? null);
      });
      if (conflict) {
        report.conflicts.push({ kind, id, message: "existing record conflicts — not overwritten" });
        return;
      }
      report.unchanged += 1;
      return;
    }
    await ref.set({ ...doc, createdAt: now, updatedAt: now });
    report.written += 1;
  };

  for (const loc of parsed.sections.locations) {
    await writeIfConsistent("locations", loc.__id, {
      id: loc.__id,
      name: loc.name,
      description: loc.description || null,
      latitude: loc.latitude == null || loc.latitude === "" ? null : Number(loc.latitude),
      longitude: loc.longitude == null || loc.longitude === "" ? null : Number(loc.longitude),
      radiusMeters: loc.radiusmeters == null || loc.radiusmeters === "" ? null : Number(loc.radiusmeters),
      requiresConfiguration: !(loc.latitude != null && loc.latitude !== "" && loc.longitude != null && loc.longitude !== ""),
      status: "active",
    });
  }
  for (const sup of parsed.sections.supervisors) {
    await writeIfConsistent("supervisors", sup.__id, {
      id: sup.__id,
      name: sup.name,
      email: sup.__email,
      emailNormalized: sup.__email,
      department: sup.department || null,
      assignedLocationIds: sup.assignedlocationids
        ? String(sup.assignedlocationids).split(/[,;]/).map((s) => s.trim()).filter(Boolean)
        : [],
      status: "onDuty",
    });
  }
  const studentIds = new Set(parsed.sections.students.map((s) => s.__id));
  for (const stu of parsed.sections.students) {
    await writeIfConsistent("students", stu.__id, {
      id: stu.__id,
      name: stu.name,
      rollNumber: stu.rollnumber || stu.roll,
      email: stu.__email,
      emailNormalized: stu.__email,
      department: stu.department || null,
      className: stu.class || stu.classname || null,
      contact: stu.contact || null,
      uid: null,
      source: stu.__sheet || "roster",
      sourceRow: stu.__row,
      status: "active",
    });
  }

  const allowlistRefs = [];
  for (const sup of parsed.sections.supervisors) {
    allowlistRefs.push({ email: sup.__email, personId: sup.__id, role: "supervisor", name: sup.name, sourceRow: sup.__row });
  }
  const assignedStudentIds = new Set(parsed.sections.assignments.map((a) => a.__id));
  for (const stu of parsed.sections.students) {
    if (assignedStudentIds.has(stu.__id)) {
      allowlistRefs.push({ email: stu.__email, personId: stu.__id, role: "student", name: stu.name, sourceRow: stu.__row });
    }
  }
  for (const entry of allowlistRefs) {
    const ref = db.doc(`accessAllowlist/${entry.email}`);
    const before = await existingData(db, ref.path);
    if (!before) {
      await ref.set({
        normalizedEmail: entry.email,
        email: entry.email,
        personId: entry.personId,
        role: entry.role,
        name: entry.name,
        source: "roster-import",
        sourceRow: entry.sourceRow,
        status: "active",
        importedAt: now,
      });
      report.written += 1;
    } else if (before.personId !== entry.personId || before.role !== entry.role) {
      report.conflicts.push({ kind: "accessAllowlist", id: entry.email, message: "allowlist mapping conflicts — not overwritten" });
    } else {
      report.unchanged += 1;
    }
  }

  for (const asn of parsed.sections.assignments) {
    const ok = studentIds.has(asn.__id);
    const doc = {
      studentId: asn.__id,
      locationId: asn.locationid,
      supervisorId: asn.supervisorid,
      workDescription: asn.dutydescription || asn.description || null,
      shiftWindows: asn.__windows,
      effectiveFrom: asn.effectivefrom || "2000-01-01",
      effectiveTo: asn.effectiveto || null,
      maxMonthlyHours: asn.maxmonthlyhours ? Number(asn.maxmonthlyhours) : 40,
      status: "active",
    };
    if (!ok) {
      report.conflicts.push({ kind: "assignments", id: asn.__id, message: "assignment references a student missing from this roster" });
      continue;
    }
    await writeIfConsistent("assignments", asn.__id, doc);
  }

  return report;
}

/**
 * Callable: importRoster — admin-only. data: { fileName, base64 }.
 * Returns the validation report + apply summary.
 */
async function importRosterHandler(deps, context, data) {
  assertObject(data, "payload");
  await identity.requireAdmin(deps.db, context);
  assertString(data.base64, "base64", { allowEmpty: false, max: 64 * 1024 * 1024 });
  if (data.fileName != null) assertString(data.fileName, "fileName", { allowEmpty: true, max: 200 });

  let buffer;
  try {
    buffer = Buffer.from(data.base64, "base64");
  } catch (_err) {
    throw httpError(CODES.INVALID_ARGUMENT, "base64 workbook payload is not valid base64.");
  }

  const parsed = await parseRosterWorkbook(buffer);
  const now = Timestamp.now();
  const apply = await applyRoster(deps.db, parsed, now);

  const summary = {
    locations: parsed.sections.locations.length,
    supervisors: parsed.sections.supervisors.length,
    students: parsed.sections.students.length,
    assignments: parsed.sections.assignments.length,
    allowlist: parsed.sections.supervisors.length + parsed.sections.students.length,
  };

  return {
    ok: true,
    fileName: data.fileName || null,
    blocksProduction: parsed.blocksProduction,
    summary,
    issues: parsed.issues,
    applied: apply,
    note: parsed.blocksProduction
      ? "Records with missing email/student-id or invalid assignments block production access."
      : "Roster import validated clean.",
  };
}

module.exports = {
  importRosterHandler,
  parseRosterWorkbook,
  applyRoster,
  REQUIRED,
};