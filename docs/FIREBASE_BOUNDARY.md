# Firebase Boundary (Stage 1B)

This document draws the line between what is implemented *today* (contract-only
domain + dev-only local repositories) and what arrives with the Firebase stage.
It is the reference for Stage 2 (Firestore-backed repositories) and for the
reviewer asked "did you actually add ₹150 / earn money anywhere?".

## Status

- **Domain layer** — pure Dart contracts and validated rules. No Flutter.
- **Data layer** — `@DevOnly` local implementations of every repository
  contract, fed entirely by `lib/shared/mock_data/` fixtures.
- **UI** — the three landing screens (student home, supervisor today, admin
  overview) read the repositories through Riverpod providers.
- **No Firebase dependency yet.** The app builds, analyzes, and tests with
  zero network, auth, or database code.

## The hard rule

**Not a single rupee amount is institutional truth.** The workbook seed carries
a `ratePerDay: 150` sample inside `mockCurrentPayroll` / `mockPaymentRecords`
(admin-only demo fixtures). It is **not** used by the domain:

- Stipend math requires a confirmed per-day rate from `PolicyConfig`
  (`defaultRatePerDay`), and `RateNotConfigured` is thrown before any
  calculation when it is absent.
- `PolicyConfig.fromAppPolicy` marks **only `monthlyMaxHours = 40`** as
  confirmed. Every other field (`defaultRatePerDay`, `locationRateTiers`,
  `lateGrace`, `earlyCheckoutGrace`, `minimumAttendancePercent`,
  `leaveNoticeDays`, `maxLeaveDaysPerMonth`, `weeklyWorkingDays`,
  `overnightShiftsAllowed`, `paidHolidayRule`, `payrollApproverRequired`,
  `evidenceRetentionDays`) is `null` / unresolved.
- Student-facing UI shows **hours only** — no currency, no earning text. The
  only ₹ values are demo fixtures already present in `mock_data.dart` for the
  admin payroll screens.

## What lives inside the boundary (Stage 1B)

### Domain (`lib/domain/`)

| Area | File | Contract |
|---|---|---|
| Policy | `policy/policy_config.dart` | `PolicyConfig`, confirmed vs unresolved fields, `PaidHolidayRule` |
| Identity | `identity/account_link.dart`, `identity/identity_resolution.dart` | `AccountLink`, `resolveIdentity` (never assumes an identity when a link is missing) |
| Assignment | `assignment/weekly_recurrence.dart`, `assignment/shift_policy.dart`, `assignment/assignment_resolution.dart` | `WeeklyRecurrence`, window validation, `monthlyPlannedHours`, late/early evaluation, `checkInEligibility`, `MonthlyCapacity`, `resolveAssignmentFor` |
| Calendar | `calendar/day_resolution.dart` | `ScheduledDay`, work / holiday / paid-festival / leave precedence |
| Attendance | `attendance/session.dart`, `session_status.dart`, `session_state_machine.dart`, `attendance_projection.dart` | `Session`, `SessionStatus`, guarded transition table, auto-finalize of missed check-out |
| Payroll | `payroll/payroll_calc.dart` | `eligibleDaysFrom`, `calculateStipend`, `evaluatePayrollApproval`, `RateNotConfigured` |
| Permissions | `permissions/permissions.dart` | Role/zone matrix, `checkPermission`, server-only critical fields |
| Validation | `validation/roster_validation.dart` | `validateRoster` against the real workbook seed |
| Contracts | `repositories/repositories.dart` | Account / Student / Supervisor / Location / Assignment / Attendance / Calendar / Verification / Payroll / Audit / Leave |

### Data (`lib/data/`)

- `dev_only.dart` — the `@DevOnly` annotation that labels every local impl.
- `local/*.dart` — implementations of all 11 repository contracts backed by
  the seed fixtures, plus Riverpod providers (`*RepositoryProvider`,
  `policyConfigProvider`) in `local_repositories.dart`.

## What stays out (Stage 2)

- Firestore collections, security rules, and indexes.
- `google-services.json` / Firebase init.
- Cloud Functions (state machine enforcement, auto-finalize sweeps,
  payroll rollup, audit append).
- Real authentication; `LocalAccountRepository` returns the demo profiles.
- Real evidence upload (zone selfie / desk logs).
- Rate configuration UI and the confirmed `defaultRatePerDay`.

## Repository swap contract

Stage 2 replaces **implementations only**. The interface is:

```dart
abstract class AttendanceRepository {
  Future<AttendanceRecord?> recordForDay({
    required String studentId,
    required DateTime day,
  });
  Future<List<AttendanceRecord>> recordsForMonth({
    required String studentId,
    required DateTime month,
  });
}
```

Attendance write/verification operations (`checkIn`, `confirmCheckIn`, `checkOut`, `confirmCheckOut`, `review`) are handled through `AttendanceGateway`.

A provider change (e.g. `LocalAttendanceRepository(...)` → a
`FirestoreAttendanceRepository`) is the entire diff for a screen. The
state-machine rules in `lib/domain/` are the intended source of truth for any
server-side Function enforcement later.

## Verification for Stage 1B

- `flutter analyze` → no issues.
- `flutter test` → 124 passing (44 legacy + 80 domain/repository).
- `flutter build apk --debug` → builds.
- Student screens render zero currency; domain throws before using any rate
  that is not confirmed in `PolicyConfig`.