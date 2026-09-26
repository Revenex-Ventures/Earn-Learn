"use strict";

const { CODES, httpError } = require("./util/errors");

/**
 * Identity & persona resolution. All role/link facts come from the
 * server-owned users/{uid} document — nothing is client-supplied.
 */

function assertAuthenticated(context) {
  const person = context?.auth;
  if (!person || !person.uid) {
    throw httpError(CODES.UNAUTHENTICATED, "Authentication required.");
  }
  return person;
}

async function getProfile(db, uid) {
  const snap = await db.doc(`users/${uid}`).get();
  return snap.exists ? snap.data() : null;
}

function resolveRole(profile) {
  return profile?.role ?? null;
}

function requireLinkedEntity(db, context, { expectedRole }) {
  const person = assertAuthenticated(context);
  const uid = person.uid;
  return getProfile(db, uid).then((profile) => {
    if (!profile) {
      throw httpError(
        CODES.UNLINKED,
        "No directory profile exists for this account yet."
      );
    }
    const role = resolveRole(profile);
    if (role !== expectedRole) {
      throw httpError(CODES.PERMISSIONS, `Account role is ${role}; expected ${expectedRole}.`);
    }
    const entityId = profile.linkedEntityId;
    if (!entityId || profile.status !== "active") {
      throw httpError(
        CODES.UNLINKED,
        "Account is not linked to an active directory entity — no attendance authority."
      );
    }
    return { uid, profile, role, entityId };
  });
}

async function requireStudent(db, context) {
  return requireLinkedEntity(db, context, { expectedRole: "student" });
}

async function requireSupervisor(db, context) {
  return requireLinkedEntity(db, context, { expectedRole: "supervisor" });
}

/**
 * Admin authority: an active server-provisioned administrator. Admins carry
 * no linked directory entity (linkedEntityId is null).
 */
async function requireAdmin(db, context) {
  const person = assertAuthenticated(context);
  const uid = person.uid;
  const profile = await getProfile(db, uid);
  if (!profile) {
    throw httpError(CODES.UNLINKED, "No directory profile exists for this account yet.");
  }
  const role = resolveRole(profile);
  if (role !== "admin") {
    throw httpError(CODES.PERMISSIONS, `Account role is ${role}; expected admin.`);
  }
  if (profile.status !== "active") {
    throw httpError(
      CODES.PERMISSIONS,
      "Admin account is not active — administrative actions are blocked."
    );
  }
  return { uid, profile, role: "admin", entityId: null };
}

async function readAssignment(db, studentId) {
  const snap = await db.doc(`assignments/${studentId}`).get();
  if (!snap.exists) return null;
  return { id: studentId, ...snap.data() };
}

async function readLocation(db, locationId) {
  const snap = await db.doc(`locations/${locationId}`).get();
  if (!snap.exists) return null;
  return { id: locationId, ...snap.data() };
}

module.exports = {
  assertAuthenticated,
  getProfile,
  resolveRole,
  requireStudent,
  requireSupervisor,
  requireAdmin,
  readAssignment,
  readLocation,
};