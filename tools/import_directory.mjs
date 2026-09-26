#!/usr/bin/env node
"use strict";

/**
 * tools/import_directory.mjs — dev/admin importer for institution directory
 * data (students, supervisors, locations, assignments).
 *
 * SAFETY:
 *   - Dry-run by default (use --apply to write).
 *   - Refuses to run unless the Firestore emulator env var is set
 *     (FIRESTORE_EMULATOR_HOST). Real imports are a future, separately
 *     reviewed admin process against production.
 *
 * INPUT: a JSON file like
 *   {
 *     "locations": [{ "id": "LOC-1", "name": "...", "latitude": 0, "longitude": 0, "radiusMeters": 100, "status": "active" }],
 *     "supervisors": [{ "id": "SV-1", "name": "...", "uid": null, "email": "...", "assignedLocationIds": [] }],
 *     "students": [{ "id": "STU-1", "name": "...", "rollNumber": "...", "uid": null, "email": "...", "className": "..." }],
 *     "assignments": [{ "studentId": "STU-1", "locationId": "LOC-1", "supervisorId": "SV-1", "shiftWindows": [{ "startMin": 960, "endMin": 1080 }], "effectiveFrom": "2026-01-01" }]
 *   }
 */

import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import admin from "firebase-admin";

const args = process.argv.slice(2);
const rawPath = args.find((a) => !a.startsWith("-"));
const apply = args.includes("--apply");
const inputPath = rawPath ?? "directory.import.json";

const requiredFields = {
  locations: ["id", "name", "latitude", "longitude", "radiusMeters"],
  supervisors: ["id", "name", "email"],
  students: ["id", "name", "rollNumber"],
  assignments: ["studentId", "locationId", "supervisorId", "shiftWindows"],
};

async function main() {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      "Refusing to import without FIRESTORE_EMULATOR_HOST — this tool targets the emulator only."
    );
  }
  const payload = JSON.parse(await readFile(resolve(inputPath), "utf8"));
  const errors = [];
  for (const [kind, list] of Object.entries(payload)) {
    if (!Array.isArray(list) || list.length === 0) {
      errors.push(`${kind}: must be a non-empty array (use seeds for synthetic data)`);
      continue;
    }
    const fields = requiredFields[kind] ?? [];
    for (const item of list) {
      if (!item || typeof item !== "object") {
        errors.push(`${kind}: entry is not an object`);
        continue;
      }
      for (const f of fields) {
        if (item[f] === undefined || item[f] === null || item[f] === "") {
          errors.push(`${kind}/${item.id ?? "?"}: missing required field "${f}"`);
        }
      }
      if (kind === "students" && item.uid != null && typeof item.uid !== "string") {
        errors.push(`students/${item.id}: uid must be a string or null`);
      }
    }
  }
  if (errors.length > 0) {
    throw new Error(`Directory import validation failed:\n${errors.join("\n")}`);
  }

  admin.initializeApp();
  const db = admin.firestore();
  const counts = { locations: 0, supervisors: 0, students: 0, assignments: 0 };
  const now = new Date().toISOString();

  for (const loc of payload.locations) {
    const touched = await put(
      db, `locations/${loc.id}`, loc, counts, "locations", now
    );
    console.log(`  ${apply ? "WRITE" : "DRY-RUN"} locations/${loc.id}`);
    if (!apply && !touched) console.log("    (unchanged — already present)");
  }
  for (const sup of payload.supervisors) {
    await put(db, `supervisors/${sup.id}`, sup, counts, "supervisors", now);
    console.log(`  ${apply ? "WRITE" : "DRY-RUN"} supervisors/${sup.id}`);
  }
  for (const stu of payload.students) {
    await put(db, `students/${stu.id}`, stu, counts, "students", now);
    console.log(`  ${apply ? "WRITE" : "DRY-RUN"} students/${stu.id}`);
  }
  for (const asn of payload.assignments) {
    await put(db, `assignments/${asn.studentId}`, asn, counts, "assignments", now);
    console.log(`  ${apply ? "WRITE" : "DRY-RUN"} assignments/${asn.studentId}`);
  }

  console.log(apply ? `Imported: ${JSON.stringify(counts)}` : "Dry-run complete — pass --apply to write.");
}

async function put(db, path, doc, counts, kind, now) {
  const ref = db.doc(path);
  const snap = await ref.get();
  if (!apply) return snap.exists;
  await ref.set({ ...doc, createdAt: snap.exists ? undefined : now, updatedAt: now });
  counts[kind] += 1;
  return true;
}

main().then(
  () => process.exit(0),
  (err) => {
    console.error("Directory import failed:", err.message);
    process.exit(1);
  }
);