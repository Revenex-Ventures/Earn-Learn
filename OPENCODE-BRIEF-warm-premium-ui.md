# opencode action — Warm-Premium UI build (Earn & Learn)

**Goal:** Implement the approved "warm-premium" visual direction from `ui-preview-batch3.html` into the real Flutter screens. The HTML mockup is the source of truth for look, spacing, icons, and per-screen state. This is a **UI-only, additive** pass.

## Non-negotiable constraints (do not violate)
- **UI only.** Do NOT touch Firebase, Cloud Functions, security rules, auth logic, or the attendance state machine (`SessionStatus`). The UI only *expresses* states.
- **Additive only.** Never delete an existing color token, style, or public API. Add new tokens; retarget widgets to them. Preserve `AvcoeSeedData` public API.
- **Light theme only.**
- **No fabricated data.** Use the real seed (`AvcoeSeedData` / `avcoe_seed_data.dart`) and keep honest gaps: "Not specified", "Not assigned", "Configuration required", "Unassigned", "Submitted · pending review". The 77-issue validator count and `passesCoreChecks = false` are the TRUE state — keep them.
- **Do NOT redraw/recolour** the AVCOE logo or the Karmaveer Bhaurao Patil portrait (reserved slots).
- **Calm, low-glare palette.** No pure-black or near-black surfaces, no fire-bright accents. Everything should be easy on the eyes on first open (this was explicit user feedback).
- **Proper icons, not emoji.** Use a real icon set (Material Icons already in Flutter, or the project's existing icon usage). Never render emoji as UI icons.

## 1. Palette — add softened warm tokens (additive) to `lib/core/design_system/app_colors.dart`
Keep every existing token. Add these NEW tokens and point the redesigned surfaces at them:

```dart
// Warm-premium surfaces
static const Color warmCanvas   = Color(0xFFF6F3EC); // app background
static const Color warmIvory    = Color(0xFFFBF9F3); // sunken/ivory cards
static const Color warmSurface  = Color(0xFFFFFFFF);
static const Color warmLine     = Color(0xFFE9E2D6); // hairline borders
static const Color inkWarm       = Color(0xFF2B2620); // primary text (softer than pure dark)
static const Color inkSoftWarm   = Color(0xFF5E574C);
static const Color slateWarm     = Color(0xFF988F81);

// Muted brand (softened, NOT bright)
static const Color forestSoft    = Color(0xFF2C6A47); // primary green (muted)
static const Color forestSoftBright = Color(0xFF3E8E63);
static const Color forestSoftDeep   = Color(0xFF274E39);
static const Color goldSoftAccent   = Color(0xFFC39A4E); // ochre, not bright yellow
static const Color goldSoftBright   = Color(0xFFD8B570);
static const Color goldSoftDeep     = Color(0xFF8A6A2C);
static const Color goldTint         = Color(0xFFF1E8D4);
static const Color terraSpark       = Color(0xFFBC6A4A); // clay-terracotta; LIVE actions ONLY
static const Color terraTint        = Color(0xFFF2E4DA);
static const Color claySoftReject   = Color(0xFFB0574C);
static const Color clayTint         = Color(0xFFF1E1DC);
static const Color infoSoft         = Color(0xFF3A5488);
```

**Hero gradient (the signature surface)** — add to `app_colors.dart` or `app_elevation.dart`:
```dart
static const LinearGradient heroForest = LinearGradient(
  begin: Alignment.topLeft, end: Alignment.bottomRight,
  colors: [Color(0xFF356249), Color(0xFF274B39)], // muted pine, NOT near-black
);
static const LinearGradient goldSoftGrad = LinearGradient(
  begin: Alignment.topLeft, end: Alignment.bottomRight,
  colors: [Color(0xFFD8B570), Color(0xFFB4914A)],
);
static const LinearGradient terraGrad = LinearGradient(
  begin: Alignment.topLeft, end: Alignment.bottomRight,
  colors: [Color(0xFFC67E5E), Color(0xFFA85D40)],
);
```
Hero foreground text: `Color(0xFFF2EFE8)` (warm off-white), never pure white.

**Shadows — soften.** Cards `rgba(43,38,32,0.055)` blur ~14; hero `rgba(38,62,45,0.20)` blur ~38. No heavy/dark drop shadows.

## 2. Typography (already in project)
- Display/headlines → **Fraunces** serif (`AppTextStyles` serif family), weight 600, slightly tight letter-spacing.
- Body/labels → **Manrope**.
- Numerals/IDs/timers/money → **Space Grotesk** tabular (`--mono` equivalent), weight 700.
Do not change existing text-style names; add serif-display variants if missing.

## 3. Icons
Replace any emoji/glyph icons with proper vector icons. Map (Material Icons shown; use project convention if different):
- settings → `Icons.settings_outlined` · id/badge → `Icons.badge_outlined` · location → `Icons.place_outlined`
- selfie/camera → `Icons.photo_camera_outlined` · shield/verified → `Icons.verified_user_outlined`
- check/approve → `Icons.check_rounded` · reject → `Icons.close_rounded` · flag → `Icons.flag_outlined`
- clock → `Icons.schedule` · star → `Icons.star_rounded` · profile → `Icons.person_outline`
- people → `Icons.group_outlined` · home/overview → `Icons.grid_view_rounded` / `Icons.home_outlined`
- assignment → `Icons.assignment_outlined` · book/library → `Icons.menu_book_outlined` · building → `Icons.apartment_outlined`
- plus → `Icons.add_rounded` · reports → `Icons.bar_chart_rounded` · download → `Icons.download_outlined`
- search → `Icons.search_rounded` · back → `Icons.chevron_left` · chevron → `Icons.chevron_right`
- check-in/on-duty → `Icons.power_settings_new_rounded` · pending/hourglass → `Icons.hourglass_empty` · alert → `Icons.warning_amber_rounded` · info → `Icons.info_outline`
Icon stroke weight should read light; size 18–20 in tiles, 15–16 inline.

## 4. Reusable components (extend existing where present, add where noted)
1. **Hero card** (`student_duty_hero_card.dart` + reuse for supervisor/admin): `heroForest` gradient, warm-off-white text, glass pill (top-left) + gold pill (top-right), giant Space-Grotesk numeral, a 3-cell translucent "strip" (kv stats), and — student only — a **trust triad** (Zone / Selfie / Supervisor, each an icon + 2-line label in a translucent tile).
2. **IdentityRow** (already exists `identity_row.dart`): gradient icon well (use `heroForest`), uppercase eyebrow label, mono value, trailing status badge. Keep.
3. **Badge** `bdg`: pill, 6 tones — green (approved/active), gold (pending), clay (rejected/flag), slate (neutral), terra (live), info. Map to `SessionStatus`.
4. **Left-accent list row** `lr`: rounded card, 4px left accent bar (green/gold/clay/slate), leading tinted icon well, title + subtitle (ellipsis), trailing badge or chevron.
5. **Metric tile** `met .m`: label + big mono value + descriptor. 2-col grid.
6. **Ledger ticket** (payroll showpiece): perforated ticket — ivory card, header band, punched notches + dashed divider, 3-cell ledger row, info lines, mono hash line. Provisional badge.
7. **Duty ring**: circular conic/arc progress (use `CustomPainter` or existing gauge) with muted-green arc over the forest fill, center mono timer + uppercase label.
8. **Soft box** `soft`: tinted status strip (green/gold/clay/neutral) with leading icon.
9. **Bottom nav with center FAB**: 4 nav items + raised center FAB. FAB colour = `terraSpark` for student check-in, `goldSoftGrad` for supervisor sign-off, `heroForest` for admin add. Do not overuse terracotta elsewhere.
10. **Sign-off sheet**: bottom sheet over a dimmed session detail; header + summary strip + 3 actions: **Approve** (filled forest), **Flag** (ghost, gold text), **Reject** (ghost, clay text).

## 5. Per-screen work (match the mockup)
- **Student Home** — hero (39 verified hrs, "1 hr to 40-hr ceiling", 6-day streak), gold "Gold Member" pill, stat strip (13 days / est ₹1,300 / On duty), trust triad, IdentityRow (`EL2627-001`, ACTIVE), 3 quick actions (Check-In=terra, Assignment, Register), "Next shift · Study Hall · Time slot: Not specified", FAB nav.
- **Student Working Session** (`state: working`) — LIVE badge, assignment pill, duty ring live timer, stat strip (check-in 09:13 / Zone Inside / 1.8h), verification soft-boxes (selfie matched, sign-off pending), terracotta **Check Out & Submit**, info note.
- **Payroll** — ledger ticket: Provisional badge, 39.0 hrs / 13 days / ₹1,300, rate ₹100/day, approved 12, pending review 1, **Disbursement: Not scheduled**, hash line w/ hourglass, info note. (Rate/amount are seed-driven; if the seed has no rate, show "Rate: Not specified" — do not invent.)
- **Supervisor Review Queue** — hero (SV-07, 4 awaiting, Study Hall · 8 students, approved-today/flagged/on-duty strip), pending rows (real students, e.g. Rutuja Dhanwate 1.8h EL2627-001), a flagged row (zone mismatch), gold-FAB nav.
- **Supervisor Sign-off** (`state: review → approve/flag/reject`) — check-out selfie panel, detail card (student/location/zone verified), bottom sheet with the three authority actions. This must map to the real supervisor decision transitions — do not add powers the state machine doesn't have.
- **Admin Overview** — hero (68 students, 15 locations / 10 supervisors / 68 assignments, on-duty/pending/payout strip with **₹—** honest), health-check soft-box (**77 validation issues**), metric grid (60 no-contact / 10 no-email / 3 no-slot / 4 unassigned — all real), manage rows, espresso-FAB nav.
- **Locations** — search, filter chips, location rows with real supervisors (Savita Punekar / V.S. Ubale / R.D. Nikam) and honest gaps ("Slot: —", "Supervisor: Not assigned" → Unassigned badge), pin note: **Configuration required** geofence (WI-8 stays dormant).
- **Reports/Calendar** — month calendar (highlight 27 Sep), day-summary metric grid (present/hours/approved/pending), Export CSV button.

## 6. SessionStatus mapping (badge tone + label)
`scheduled`→slate "Scheduled" · `checkIn`→green "Checked in" · `working`→terra "On duty · live" · `checkOut`→slate "Checked out" · `submitted`→gold "Submitted · pending review" · `review`→gold "In review" · `approved`→green "Approved" · `flagged`→gold "Flagged" · `rejected`→clay "Rejected" · `correctionRequested`→info "Correction requested". Centralize this mapping in one helper; don't hardcode per screen.

## 7. Verification (must pass before you report done)
1. `flutter analyze` — clean.
2. `flutter test` — all pass. If `visual_layout_test.dart` breaks, fix the CAUSE (overflow) not the assertion; the login-gate teardown pattern (`AuthSession.signIn/​signOut`) is already in that test.
3. `flutter run -d chrome` (NOTE: `--web-renderer` flag is removed in this Flutter version — do not use it) and eyeball each screen at phone width; confirm no glare, no pure-black surfaces, icons render (no missing-glyph boxes), and honest gaps still show.
4. Commit the currently-untracked new files too (`auth_session.dart`, `credentials.dart`, `login/`, `identity_row.dart`, `app_elevation.dart`, `local_review_store.dart`) so the branch compiles from clean.

## 8. Definition of done
All 8 screens reflect the mockup's warm-premium look with the softened palette, real icons, real seed data + honest gaps, correct `SessionStatus` expression, additive tokens only, light theme, analyze+test green, and a chrome smoke-test screenshot per role.
