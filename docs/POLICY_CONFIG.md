# Earn & Learn — Production Data / Policy Contract (Stage 0)

Status: **DRAFT — awaiting institutional sign-off on Section B.**
Prepared by: application audit (source = `lib/shared/mock_data/avcoe_seed_data.dart`, `test/avcoe_dataset_test.dart`, `lib/core/models/*`, `lib/shared/mock_data/mock_data.dart`).
Note: the college workbook `.xlsx` is **not** present in the repository (no `.xlsx` file, `README.md` is the default Flutter README). The seed file is the only faithful representation of the workbook and is the oracle for every value in Section A.

Legend for Section B status: **CONFIRMED** = established by workbook/seed/audit · **MISSING** = exists nowhere; college must supply · **PLACEHOLDER** = a demo/default value exists that must NOT ship.

---

## A. CONFIRMED / SOURCE-DERIVED VALUES

These are encoded in the seed and asserted by the dataset test. Nothing here is invented; changes require a fresh workbook import, not config edits.

### A.1 Population counts (source: `avcoe_seed_data.dart`, asserted in `avcoe_dataset_test.dart`)

| Value | Count | Notes |
|---|---|---|
| Students (`STU-001` … `STU-068`) | 68 | All with non-null name, `rollNumber`, `department`, `className` |
| Students with explicit `contact: null` | 15 | STU-006, 011, 018, 023, 027, 032, 036, 040, 044, 048, 052, 056, 059, 063, 067 — modeled as null, **not** fabricated |
| Locations (`LOC-01` … `LOC-15`) | 15 | All `LocationStatus.active` |
| Supervisors (`SV-01` … `SV-12`) | 12 | 11 `onDuty`, 1 `offDuty` (SV-10) |
| Assignments (`ASN-001` … `ASN-068`) | 68 | 1:1 with students; all `AssignmentStatus.active`; all `effectiveFrom = start-of-current-month`, **no `effectiveTo`** |

### A.2 Shift representations (source: `avcoe_seed_data.dart` token constants)

Windows are `Duration` from midnight, inclusive on both ends (`contains()` = `minutes >= start && minutes <= end`). No overnight support currently in the model.

| Token | Window | Duration | Encoded on assignments |
|---|---|---|---|
| `shiftEvening3h` | 17:00–20:00 | 3 h | 9 |
| `shiftEvening2h` | 18:00–20:00 | 2 h | 30 |
| `shiftMorning1h` | 07:00–08:00 | 1 h | 7 |
| `shiftAfternoon2h` | 14:00–16:00 | 2 h | 19 |
| Split shift (`shiftMorningSplit` + `shiftEveningSplit`) | 07:00–08:00 **+** 17:00–18:00 | 2 h total | 3 |

Split-shift assignments: **ASN-024, ASN-026, ASN-028**, all at LOC-04 (Play Ground and Gardening). Sum per token = 68 ✓ (`avcoe_dataset_test` also asserts every assignment has `plannedHoursPerDay > 0`).

### A.3 Per-location mapping (student block → shift mix → supervisor)

| Location | Students (IDs) | Supervisor | Encoded shift mix |
|---|---|---|---|
| LOC-08 Library | STU-001…008 | SV-01 | 5× evening3h, 3× evening2h |
| LOC-01 Kalsubai Hostel (Old) | STU-009…014 | SV-02 | 5× evening2h, 1× morning1h |
| LOC-02 Krushnavanti Hostel (New) | STU-015…019 | SV-11 | 4× evening2h, 1× morning1h |
| LOC-03 Study Hall | STU-020…023 | SV-01 | 4× evening3h |
| LOC-04 Play Ground and Gardening | STU-024…029 | SV-07 | 3× split, 2× morning1h, 1× evening2h |
| LOC-05 Harishchandragadh Hostel | STU-030…033 | SV-02 | 3× evening2h, 1× morning1h |
| LOC-06 Sinhagad Hostel | STU-034…037 | SV-12 | 3× evening2h, 1× morning1h |
| LOC-07 Sajjangad Hostel | STU-038…041 | SV-11 | 4× evening2h |
| LOC-09 Civil Lab | STU-042…045 | SV-04 | 4× afternoon2h |
| LOC-10 SDO | STU-046…049 | SV-05 | 4× afternoon2h |
| LOC-11 Gymkhana | STU-050…053 | SV-03 | 4× evening2h |
| LOC-12 Dispensary | STU-054…056 | SV-08 | 3× afternoon2h |
| LOC-13 Incubation | STU-057…060 | SV-06 | 4× afternoon2h |
| LOC-14 Guest House | STU-061…064 | SV-10 | 3× evening2h, 1× morning1h |
| LOC-15 TPO Office | STU-065…068 | SV-09 | 4× afternoon2h |

Aggregate planned duty = 138 h/day across all 68 assignments.

### A.4 Confirmed relationship rules (source: `avcoe_seed_data.dart`, `avcoe_dataset_test.dart`)

- **Student ↔ Assignment: 1:1** (68 = 68).
- **Assignment → Location: exactly one** (`locationId`); **Assignment → Supervisor: exactly one** (`supervisorId`).
- **Supervisor ↔ Locations: M:N** via `assignedLocationIds`: SV-01→[LOC-03,LOC-08], SV-02→[LOC-01,LOC-05], SV-11→[LOC-02,LOC-07]; all other supervisors → 1 location.
- **Location → Supervisors/Students: denormalized** on the `Location` model (`supervisorIds`, `studentIds`), recomputed by `mockLocationsWithCoverage` in today's mock layer — in production this becomes a query, not stored data.
- **Fidelity flag (data-integrity feature, not bug):** SV-10 is `SupervisorStatus.offDuty` yet LOC-14 (Guest House) is assigned to SV-10 (ASN-061…064). Preserve at import; surface in an admin review queue.

### A.5 40-hour ceiling — as currently encoded (NOT policy semantics)

- `Assignment.maxMonthlyHours` default = **40** (`lib/core/models/assignment.dart`), `AppPolicy.monthlyMaxHours` default = **40** (`lib/core/models/app_config.dart`).
- The seed assigns **no explicit `maxMonthlyHours`** on any of the 68 assignments — every row relies on the model default.
- `avcoe_dataset_test.dart` asserts **every** assignment `maxMonthlyHours == 40`.
- **Semantics are unresolved** (hard vs soft, calendar-month vs rolling window, server-side enforcement location) → Section B items 21–22.

### A.6 Institutional calendar rule as recorded (source: `mock_data.dart` comment + `mockMonthCalendar`)

- Recorded institutional context: **"Sundays Off, Paid Festivals, Holidays."**
- Only the **Sunday offDay** generation reflects that rule. The specific "State Holiday" (2nd weekday) and fixed on-the-24th "College Foundation Day" (`isPaid: true`) are **fabricated demo dates** — production must replace them with the real 2026 ledger (Section B items 18–19).

### A.7 Tooling facts that constrict import

- `StudentSeedEntry` columns mirror the workbook allocation sheet verbatim: `name, contact, department, className, time, workAllotted, remark` (`lib/core/seed/student_seed_entry.dart`). `Student.rollNumber` is the only extra carried through.
- `DataQualityReport` reports `missingContactsExplicit / missingDepartmentsExplicit / missingClassesExplicit / splitShiftsCount / unassignedShiftsCount` and asserts `"0 Fabricated Values"` — the import contract: missing cells stay null, nothing is guessed.

---

## B. REQUIRES COLLEGE CONFIRMATION

Every row is an unresolved production value. The "Current known value" column states exactly what exists today; a **PLACEHOLDER** there means it must not reach production.

| # | Item | Current known value | Source | Status | What the college must decide | Where it will be used |
|---|---|---|---|---|---|---|
| 1 | Google login domain / allowed accounts | none | — | MISSING | Allowed Google workspace domain(s); who may log in | Stage 1 Auth allowlist; `users` creation |
| 2 | Final 68-student roster | 68 names/rolls/departments/classes in seed | `avcoe_seed_data.dart` | CONFIRMED (frozen from workbook) | Confirm roster is current for the working year; supply an updated workbook if not | Stage 2 migration; `students` docs |
| 3 | Student Google/email mapping | no student emails anywhere | `avcoe_seed_data.dart`, `mock_data.dart` | MISSING | Per-student email to link to `STU-xxx` | `users.linkedEntityId`; login guard |
| 4 | Supervisor email verification | 12 placeholder emails `*@avcoe.org` constructed from names (e.g. `kj.dhage@avcoe.org`) | `avcoe_seed_data.dart` | PLACEHOLDER | Real supervisor email(s) for login + identity | `supervisors` docs; supervisor login |
| 5 | Real GPS coordinates for all 15 locations | `latitude`/`longitude` null for all 15 | `avcoe_seed_data.dart` + `Location` model | MISSING | Survey-grade lat/lng per location | Stage 3 `locations` GeoPoint; Stage 4 geofence |
| 6 | Geofence radius per location | `radiusMeters = 50` as a **code default**, zero specialization | `lib/core/models/location.dart` | PLACEHOLDER | Acceptance radius per location (and whether multi-point zones needed) | Stage 4 inside/outside verdict |
| 7 | Exact shift times for every student | 5 shift windows (A.2) encoded on seed tokens | `avcoe_seed_data.dart` | CONFIRMED (encoding) | Verify each student's actual per-day duty time matches the token | `assignments.shiftWindows` |
| 8 | Weekly recurrence / working weekdays | none — seed is daily-or-nothing; no weekday pattern | model/seed | MISSING | Which weekdays each assignment is active (Sundays off implied but not per-assignment) | Stage 3 recurrence; day-resolution |
| 9 | Overnight-shift policy | `ShiftWindow.contains` is inclusive same-day; no overnight support; no overnight token | `lib/core/models/shift_window.dart` | MISSING | Are overnight duties ever allowed; if yes, how represented | import rule + session engine |
| 10 | Rate per day | `ratePerDay: 150` in demo payroll records | `mock_data.dart` (fixtures, PAY-2026-09-*) | PLACEHOLDER | Official ₹/day rate | `policy.defaultRatePerDay`; payroll calc |
| 11 | Any location-based rate tier | none | — | MISSING | If rate varies by location/section, list tiers | payroll calc; reports |
| 12 | Late-grace duration | none in code | — | MISSING | Minutes of grace after window start before "late" | session check-in logic |
| 13 | Late/early checkout deduction rule | none in code | — | MISSING | Are late days deducted from eligible payroll days; by what rule | payroll eligible-days calc |
| 14 | Minimum attendance percentage | `94.2` hard-coded in reports demo | `lib/features/supervisor_admin/reports_screen.dart` | PLACEHOLDER | Official eligibility attendance % (e.g. for scheme continuation) | reports; eligibility gate |
| 15 | Leave rules | none (LeaveRequest model exists, no policy) | `lib/core/models/leave_request.dart` | MISSING | Notice window, max days, paid/unpaid, how leave interacts with duty days | leave workflow (Stage 6) |
| 16 | Leave approval authority | none | — | MISSING | Who approves student leave (zone supervisor vs SDO) | leave function ACL |
| 17 | Make-up duty rules | none | — | MISSING | Whether missed duty can be compensated, and caps | attendance reconciliation |
| 18 | Holiday/festival calendar for 2026 | "State Holiday" (2nd weekday) + "Foundation Day 24th" are **fabricated** dates | `mockMonthCalendar` (demo) | MISSING | Official 2026 holiday/festival date list | `calendar` docs (admin-written) |
| 19 | Paid-holiday rules | `isPaid: true` only on fabricated Foundation Day | `mockMonthCalendar` (demo) | PLACEHOLDER | Which holidays count as paid toward hours/days | payroll eligible-days + hours credit |
| 20 | Saturday policy | not modeled (Sundays off only rule) | `mockMonthCalendar` | MISSING | Are Saturdays working days for hostel sections | calendar + recurrence |
| 21 | 40-hour ceiling semantics: hard vs soft | `40` as model default only; test requires each assignment = 40 | `assignment.dart`, `avcoe_dataset_test.dart` | CONFIRMED (value) / semantics MISSING | Hard cap (reject beyond) or soft (flag only)? | Stage 4 check-out enforcer |
| 22 | Whether 40 hours is calendar-month based | none | — | MISSING | Calendar month, or rolling 30-day window? | hours accumulator window |
| 23 | Payroll approver / second authority | none (admin self-approves in demo; `PaymentStatus.approved` fixture exists) | `mock_data.dart` | MISSING | Designated second approver (Dean/Director/SDO) — self-approval allowed? | Stage 8 approval stage |
| 24 | Payroll receipt/signature requirements | `PaymentReceipt` model + "Digital signature by AVCOE / SDO" copy exist; no real signature policy | `lib/core/models/payment_receipt.dart` + UI copy | PLACEHOLDER | Signing authority, signature mechanism, receipt records | payment receipts |
| 25 | Student contact/class visibility/privacy rules | contact/class displayed in mock UI freely | `mock_data.dart`, screens | MISSING (privacy) | Who may see contact/class; explicit consent for PII handling | security rules; UI exposure |
| 26 | Selfie/facial-processing consent | none; "Privacy & Data Retention: Institutional Policy" copy is placeholder | UI copy | MISSING | Written consent for facial capture/processing (and against what) | identity verification (Stage 5) |
| 27 | Evidence retention/deletion period | none | — | MISSING | How long GPS/selfie/audit evidence is kept before deletion | evidence lifecycle |
| 28 | Location permission required only during duty? | no location handling exists | — | MISSING | Is geo verification scoped to duty windows only (battery/privacy) | permission prompts (Stage 4) |
| 29 | Notification/FCM availability expectations | none; static "On" settings tiles | settings UI (demo) | MISSING | Do student devices have Play Services/data; acceptable to require FCM | Stage 7 FCM topics + fallback |
| 30 | Any other value marked CFG/? during audit | saturation: see every row above | audit trail from this file | — | Free-form items the college adds (e.g., working-hour sweep time, duty-swap rules) | affected modules |

### B.1 Hard rules carried from audit (do not convert to defaults)
- ₹150/day, 94.2%, `radiusMeters = 50`, fabricated State Holiday/Foundation Day, `@avcoe.org` placeholder emails and their sequential `+91 98224 11xxx` placeholder phone numbers in the supervisor seed, and demo payroll amounts must **not** be treated as confirmed policy anywhere.
- Missing cells (15 null student contacts) stay null; import never guesses.