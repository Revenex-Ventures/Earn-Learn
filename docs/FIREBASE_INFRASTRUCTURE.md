# Earn & Learn — Firebase Infrastructure (Stage 1A)

Status: **PARTIAL — billing-blocked.** Project + app registration done; Firestore/Storage/Functions/FCM pending billing enablement.

Last updated: 2026-09-19 · Prepared via Firebase CLI `15.25.1` (authenticated as `prasannamate1754@gmail.com`).

---

## 1. Firebase Project

| Field | Value |
|---|---|
| Project ID | `earnandlearn-2eeea` |
| Display name | EarnAndLearn |
| Project number | `159946200704` |
| Billing plan | No billing account linked — grant **blocked** |
| Default GCP resource region | Not set (services region chosen per-service: `asia-south1`) |

Related local config (created this stage):
- `.firebaserc` → active project `earnandlearn-2eeea` (`firebase use` resolves ✓)
- `firebase.json` → Firestore rules/indexes, Storage rules, Functions config (valid JSON ✓)

## 2. Firestore

| Field | Value |
|---|---|
| Database ID | `(default)` (proposed) |
| Edition | **Enterprise** (architecture decision — PITR required for payroll/audit trails) |
| Region | `asia-south1` (Mumbai) — verified available via `firestore:locations` |
| PITR | `ENABLED` (requested) |
| Delete protection | `ENABLED` (requested) |

**Provisioning: BLOCKED** — `firestore:databases:create` returns `HTTP 403 This API method requires billing`.

Once billing is on, run:
```
firebase firestore:databases:create '(default)' --edition=enterprise --location=asia-south1 --point-in-time-recovery ENABLED --delete-protection ENABLED --project earnandlearn-2eeea
firebase firestore:databases:get '(default)' --project earnandlearn-2eeea
```

## 3. Storage

| Field | Value |
|---|---|
| Bucket (expected) | `earnandlearn-2eeea.appspot.com` — Google's deterministic default (`{projectId}.appspot.com`) |
| Region (expected) | `asia-south1` |
| Rules file | `storage.rules` prepared locally (deny-all skeleton, valid) |

**Provisioning: BLOCKED** — default bucket is created when Cloud Storage is first enabled, which requires billing.
**No evidence or user data uploaded** (as instructed).
Once enabled: `firebase deploy --only storage` deploys the rules skeleton.

## 4. Cloud Functions

| Field | Value |
|---|---|
| Runtime | Node.js 20 (`nodejs20`) |
| Region | `asia-south1` (set via `setGlobalOptions`) |
| Codebase | `earn-and-learn` |
| Source | `functions/` (created this stage) |
| Dependencies | `firebase-admin ^12.7.0`, `firebase-functions ^5.1.0` (stub `index.js` — init + region only) |

**Deployment: BLOCKED** — Cloud Functions requires Blaze billing.
**No attendance/auth/payroll triggers exist or are deployable yet** (as instructed). Runtime environment is prepared offline only.

## 5. Firebase Cloud Messaging

| Field | Value |
|---|---|
| Requirement | FCM for new projects requires a Blaze (billing) project |
| Deliverable | **BLOCKED** by billing. No topics, no senders, no devices registered (as instructed) |
| Post-billing prerequisite | Enable Cloud Messaging API in Firebase Console; APNs key for iOS upload |

## 6. Enabled Firebase services (current state)

| Service | Status |
|---|---|
| App registration (Android/iOS) | **ENABLED** — 2 apps registered (below) |
| Firestore | API reachable (list OK); **no database** — blocked by billing |
| Storage | **Not provisioned** — blocked by billing |
| Cloud Functions | Environment prepared offline; **not deployed** — blocked by billing |
| Cloud Messaging | **Not enabled** — blocked by billing |
| Authentication | **Not touched** (Stage 1B) |
| Hosting | Not in scope |

## 7. Android / iOS app identifiers

| Platform | App ID | Package / Bundle ID | Config file |
|---|---|---|---|
| Android | `1:159946200704:android:6992b8669895780e0cf865` | `com.avcoe.earn_and_learn` (`android/app/build.gradle.kts`) | `android/app/google-services.json` — **not yet downloaded** |
| iOS | `1:159946200704:ios:01f14a7604e34f9d0cf865` | `com.avcoe.earnAndLearn` (`ios/Runner.xcodeproj`) | `ios/Runner/GoogleService-Info.plist` — **not yet downloaded** |

Retrieval (Stage 1B): `firebase apps:sdkconfig ANDROID 1:159946200704:android:6992b8669895780e0cf865` · `firebase apps:sdkconfig IOS 1:159946200704:ios:01f14a7604e34f9d0cf865`

## 8. FlutterFire configuration status

| Item | Status |
|---|---|
| Firebase dependencies (`firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `cloud_functions`, `firebase_messaging`) | **Absent** from `pubspec.yaml` — add in Stage 1B |
| `lib/firebase_options.dart` | **Absent** — to be generated (`flutterfire configure`) in Stage 1B |
| `google-services.json` / `GoogleService-Info.plist` | **Absent** (above) |
| Android build plugin (Google services Gradle) | Not added — Stage 1B |

## 9. CLI / tool versions

| Tool | Version / detail |
|---|---|
| Firebase CLI | `15.25.1` (global install; `npx -y firebase-tools@latest` **fails** on this machine with npm `Invalid Version:` cache error — use global `firebase`) |
| Node.js / npm | `v24.13.0` / `11.6.2` |
| Flutter | `3.47.2-stable` (`C:\Flutter\flutter_windows_3.47.2-stable`) |
| Flutter analyze | `No issues found` |
| Flutter tests | `44/44 passed` |

## 10. Anything still blocked

1. **Billing** — single root blocker for: Firestore Enterprise database (with PITR), Storage bucket, Cloud Functions deployment, and FCM. Enable at `https://console.developers.google.com/billing/enable?project=earnandlearn-2eeea` (link a billing account; plan becomes Blaze).
2. **College data checklist** (`docs/PRODUCTION_DATA_CHECKLIST.md`, `docs/POLICY_CONFIG.md` §B) — login domain, student/supervisor email mapping, coordinates, rate, calendar, payroll approver, consent.
3. **npx/cache** — npm `Invalid Version:` prevents `npx firebase-tools@latest`; workaround: global CLI.

### Re-provision command sequence (after billing)
```
firebase firestore:databases:create '(default)' --edition=enterprise --location=asia-south1 --point-in-time-recovery ENABLED --delete-protection ENABLED --project earnandlearn-2eeea
firebase deploy --only storage
cd functions && npm install && cd ..
firebase deploy --only functions
```
Verify with: `firebase firestore:databases:get '(default)'`, `firebase apps:list`, `firebase use`.