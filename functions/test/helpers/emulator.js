"use strict";

const admin = require("firebase-admin");

const API_HOST = process.env.FIREBASE_FUNCTIONS_HOST || "127.0.0.1";
const API_PORT = process.env.FIREBASE_FUNCTIONS_PORT || "5001";

let app;

/**
 * Admin SDK instance pointed at the running emulators. `emulators:exec` populates
 * the FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST /
 * FIREBASE_STORAGE_EMULATOR_HOST vars automatically.
 */
function initAdmin() {
  if (app) return app;
  // src/firebase.js (pulled in via seeds/sweep modules) may already have
  // created the admin default app in this process — reuse it instead of
  // re-initializing.
  app =
    admin.apps[0] ||
    admin.initializeApp({ storageBucket: `${projectId()}.appspot.com` });
  return app;
}

function db() {
  return admin.firestore();
}

function auth() {
  return admin.auth();
}

function bucket() {
  return admin.storage().bucket(process.env.STORAGE_BUCKET || `${projectId()}.appspot.com`);
}

function projectId() {
  return process.env.GCLOUD_PROJECT || "earnandlearn-2eeea";
}

function functionsBase() {
  return `http://${API_HOST}:${API_PORT}/${projectId()}/asia-south1`;
}

async function signIn(email, password) {
  const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
  const url = `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=emulator-key`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  if (!res.ok) {
    throw new Error(`signIn failed for ${email}: ${res.status} ${await res.text()}`);
  }
  const body = await res.json();
  return { idToken: body.idToken, uid: body.localId, email: body.email };
}

async function callFunction(name, idToken, data) {
  const res = await fetch(`${functionsBase()}/${name}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
    },
    body: JSON.stringify({ data: data ?? {} }),
  });
  const text = await res.text();
  let body = null;
  try {
    body = JSON.parse(text);
  } catch (_err) {
    /* keep null */
  }
  if (!res.ok) {
    const err = new Error(`callable ${name} failed (${res.status}): ${text}`);
    err.status = res.status;
    err.body = body;
    throw err;
  }
  if (body && typeof body === "object") {
    if ("result" in body) return body.result;
    if ("data" in body) return body.data;
  }
  return body;
}

module.exports = { initAdmin, db, auth, bucket, projectId, signIn, callFunction };