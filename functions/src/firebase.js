const { initializeApp } = require("firebase-admin/app");
const {
  getFirestore,
  Timestamp,
  FieldValue,
} = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");

const admin = require("firebase-admin");

const projectId = process.env.GCLOUD_PROJECT || "earnandlearn-2eeea";
const bucketName = process.env.STORAGE_BUCKET || `${projectId}.appspot.com`;

if (!admin.apps.length) {
  initializeApp({
    storageBucket: bucketName,
  });
}

const db = getFirestore();
const authAdmin = getAuth();
const rawStorage = getStorage();

const storage = {
  ...rawStorage,
  bucket: (name) => rawStorage.bucket(name || bucketName),
};

module.exports = { db, authAdmin, storage, Timestamp, FieldValue };