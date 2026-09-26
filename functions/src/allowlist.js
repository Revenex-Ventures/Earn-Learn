"use strict";

const { httpError, CODES } = require("./util/errors");

/**
 * accessAllowlist — the server-only record of every Google account allowed
 * into the application. It is produced by importRoster from the authoritative
 * Excel roster and is the ONLY source of truth for who may bootstrap.
 *
 * accessAllowlist/{normalizedEmail}:
 *   { normalizedEmail, email, personId, role, name, source, sourceRow,
 *     status: "active" | "inactive", importedAt }
 *
 * Clients have zero access. bootstrapUser (server) is the only reader.
 */

/**
 * Matches a user's normalized email against the roster-derived allowlist.
 * Returns the allowlist entry or null. Never created on the fly — simply
 * matching a Google account is not enough to be provisioned.
 */
async function lookupAllowlist(db, normalizedEmail) {
  const snap = await db.doc(`accessAllowlist/${normalizedEmail}`).get();
  if (!snap.exists) return null;
  const entry = { id: normalizedEmail, ...snap.data() };
  if (entry.normalizedEmail !== normalizedEmail) entry.normalizedEmail = normalizedEmail;
  return entry;
}

/**
 * bootstrap provisions users/{uid} from a matched allowlist entry. The role,
 * personId and status come straight off the allowlist record — a client can
 * never influence them. Directory uid linkage (students/supervisors/{id}.uid)
 * is recorded so client rules can scope reads to the owner.
 */
async function provisionUser(db, { uid, email, emailVerified, entry, now }) {
  const role = entry.role;
  const personId = entry.personId;
  const status = "active";

  const userRef = db.doc(`users/${uid}`);
  let created = false;
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    const prev = snap.exists ? snap.data() : null;
    if (!snap.exists) created = true;
    tx.set(
      userRef,
      {
        uid,
        email,
        emailNormalized: entry.normalizedEmail || email,
        emailVerified: emailVerified === true,
        role,
        personId,
        status,
        linkedEntityId: role === "admin" ? null : personId,
        displayName: prev?.displayName ?? entry.name ?? null,
        photoUrl: prev?.photoUrl ?? null,
        createdAt: prev?.createdAt ?? now,
        updatedAt: now,
        lastLoginAt: now,
      },
      { merge: false }
    );
  });

  const dirTarget = role === "student" ? `students/${personId}` : role === "supervisor" ? `supervisors/${personId}` : null;
  if (dirTarget) {
    const ref = db.doc(dirTarget);
    const snap = await ref.get();
    if (snap.exists) {
      const data = snap.data();
      if (data.uid !== uid || data.emailNormalized !== entry.normalizedEmail) {
        await ref.update({ uid, emailNormalized: entry.normalizedEmail, updatedAt: now });
      }
    }
  }

  return {
    created,
    profile: {
      uid,
      role,
      personId,
      status,
      email: entry.email,
      emailNormalized: entry.normalizedEmail,
    },
  };
}

module.exports = { lookupAllowlist, provisionUser };