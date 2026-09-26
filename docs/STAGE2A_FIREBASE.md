# Stage 2A — Attendance Capture V1 · Scope Boundary (Approved Plan)

Status: **APPROVED — build boundary.** This document is the scope reference for the Stage 2A implementation. Anything not listed here is OUT of scope.

Companion docs: `docs/FIREBASE_INFRASTRUCTURE.md`, `docs/FIREBASE_BOUNDARY.md`, `docs/POLICY_CONFIG.md` (unresolved §B values must never be invented).

---

## In scope
- Firebase initialization (emulator-first)
- Firebase Auth / Google Sign-In
- Firestore repositories (provider/flavor swap only)
- Storage evidence service
- Cloud Functions (emulator only — never deployed to live in this stage)
- Attendance state-machine mirror (1:1 port of `lib/domain/attendance/session_state_machine.dart`)
- Check-in / check-out flow
- Selfie + GPS evidence (both mandatory, blocking)
- Supervisor attendance review (zone-scoped)
- Firestore security rules
- Storage security rules
- Idempotency (`operations` ledger + deterministic session doc id + compare-and-set)
- Emulator test infrastructure
- Directory import tooling
- Account-linking tooling

## Out of scope
- Payroll (calculation, reports, payment)
- Leave
- Calendar administration
- Policy administration
- Deploying any live attendance Function or importing real users/data
- Deleting or altering the `@DevOnly` local repositories

## Hard rules
1. **No invented data**: no emails, GPS coordinates, rates, holidays, leave rules, grace periods, or recurrence rules. Unresolved `PolicyConfig` fields stay null; `evaluateLateCheckIn`/`evaluateEarlyCheckOut` use zero grace.
2. **Evidence is mandatory and blocking**: missing/invalid selfie or GPS at check-in keeps the session **checkInPending**; only successful server validation transitions **checkInPending → working**. Same discipline at check-out (**checkOutPending → submitted**).
3. **verifiedHours** is computed **server-side** as overlap of `[checkInVerifiedAt, checkOutVerifiedAt]` with the day's shift windows. No payroll deductions or unconfirmed policy.
4. **Clients must never directly write**: attendance status, `*VerifiedAt`, `verifiedHours`, `review`, `role`, `linkedEntityId`, or any authoritative session field. Functions/Admin SDK have the only write authority (enforced by rules + critical-fields deny).
5. **Storage evidence is immutable**; students upload only under their own UID path; supervisor evidence access goes through the `attendance.getEvidence` Function (signed URL).
6. **Real accounts stay pending/unlinked**: `users.status = pending`, `linkedEntityId = null`, no attendance authority, until the college mapping CSV runs through `tools/link_accounts.mjs` (offline, dry-run default).
7. **Emulator-first**: all validation runs against the local emulator with synthetic users. No production deploy, no production data.

## Authoritative field matrix (server-only writes)
`status`, `review`, `checkInVerifiedAt`, `checkOutVerifiedAt`, `verifiedHours`, `reason`, `createdAt`, `updatedAt`, `checkInEvidence`, `checkInGeo`, `checkOutEvidence`, `checkOutGeo`, `capacityWarning`, `users.role`, `users.linkedEntityId`, `users.status` → Functions/service only.

## Decision log (confirmed during planning)
- Selfie + GPS both always required (a missing piece leaves the session in the pending state, resumable; sweep marks missed at window end).
- Emulator-first with synthetic users; real users start `pending`.
- `verifiedHours` = in-window overlap of verified timestamps.

## Verification gates
- `flutter analyze` — no issues
- `flutter test` — all pass (existing 137 + new)
- `firebase emulators:exec --only auth,firestore,storage,functions` — functions + rules tests pass
- `flutter build apk --debug` — builds