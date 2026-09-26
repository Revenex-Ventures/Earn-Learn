#!/usr/bin/env node
"use strict";

/**
 * tools/link_accounts.mjs — dev/admin tool to complete an account link when the
 * institution approves directory linkage. Emulator-only, dry-run by default.
 *
 * INPUT: a JSON mapping (or file path) like
 *   { "auth-stu-001": { "entityId": "STU-9001", "role": "student" } }
 *
 * Flips the users/{uid} doc to status=active with linkedEntityId set. This is
 * authority-granting — it is NOT exposed to any client and never wired into a
 * callable. In production this belongs to a separately reviewed admin process.
 */

import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import admin from "firebase-admin";

const args = process.argv.slice(2);
const apply = args.includes("--apply");
const raw = args.find((a) => !a.startsWith("-")) ?? "links.account.json";

async function main() {
  if (!process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      "Refusing to link accounts without FIRESTORE_EMULATOR_HOST — emulator only."
    );
  }
  let mapping;
  try {
    mapping = JSON.parse(raw);
  } catch (_err) {
    mapping = JSON.parse(await readFile(resolve(raw), "utf8"));
  }

  const expectedRoles = ["student", "supervisor"];
  const errors = [];
  for (const [uid, link] of Object.entries(mapping)) {
    if (!link || typeof link.entityId !== "string" || !link.entityId) {
      errors.push(`${uid}: missing entityId`);
    }
    if (!expectedRoles.includes(link.role)) {
      errors.push(`${uid}: role must be ${expectedRoles.join("|")}`);
    }
  }
  if (errors.length > 0) {
    throw new Error(`link validation failed:\n${errors.join("\n")}`);
  }

  admin.initializeApp();
  const db = admin.firestore();
  const now = new Date().toISOString();

  for (const [uid, link] of Object.entries(mapping)) {
    const ref = db.doc(`users/${uid}`);
    const snap = await ref.get();
    const before = snap.exists ? snap.data() : null;
    const previouslyActive = before?.status === "active";
    console.log(
      `  ${apply ? "WRITE" : "DRY-RUN"} users/${uid}` +
        (previouslyActive ? " (re-link)" : "") +
        ` → role=${link.role} entity=${link.entityId}`
    );
    if (!apply) continue;
    await ref.set(
      {
        role: link.role,
        status: "active",
        linkedEntityId: link.entityId,
        linkedAt: now,
        updatedAt: now,
      },
      { merge: true }
    );
  }

  console.log(
    apply ? "Account links applied." : "Dry-run complete — pass --apply to write."
  );
}

main().then(
  () => process.exit(0),
  (err) => {
    console.error("link_accounts failed:", err.message);
    process.exit(1);
  }
);