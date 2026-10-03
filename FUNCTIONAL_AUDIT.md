# Earn & Learn — Functional Audit & Build Plan

_K.B.P. Earn & Learn Scheme · AVCOE Sangamner · audit date 2026-09-29_

This is an honest, code-level audit of what **actually works** versus what only **looks** built,
across the Student, Supervisor and Admin/SDO portals. It also lays out the plan to make the app
"deep" — i.e. every button, tab and workflow genuinely functional end to end.

---

## The core finding (why it feels "not deep")

The UI is good and most screens render real seed data. But the **three portals are wired to
separate, disconnected data stores**, so the workflows don't flow into each other:

- A student **checks out** → the app writes it to the student's own in-memory store and advances
  the attendance state machine to `submitted`. Correct so far.
- The supervisor's **review queue**, however, reads from a **static fixture list**
  (`mockVerificationItems`), not from student activity. So the student's real check-out
  **never appears** in the supervisor's queue.
- The admin's payroll/reports numbers are largely **hardcoded fixtures**, not computed from
  attendance.

So each portal works in isolation, but the loop — _student acts → supervisor sees it live →
approves/flags/rejects → result flows back to the student_ — is **not connected**. That
disconnection is exactly the "depth" that's missing.

A second reality: the local build keeps everything **in memory**, so all activity resets when the
app restarts. And there is **no messaging/notification system** and **no add/remove/edit (CRUD)**
for students, supervisors, assignments or shifts anywhere in the code today.

---

## Login IDs available (only 3 wired now)

Currently only **3** demo logins exist (shared password `avcoe@2627`): student `EL2627-001`,
supervisor `SV-01`, admin `sdo@avcoe.edu.in`. The real seed sheet already contains far more that
we can turn into working logins:

- **68 students** — EL2627-001 … EL2627-068
- **10 supervisors** — SV-01 … SV-10
- **15 locations**, 68 assignments (one per student)

So we can wire **67 more student logins and 9 more supervisor logins** straight from the real data.

---

## Student portal — status

**Works:** the whole check-in / check-out flow (real camera selfie, real GPS, evidence submit),
the attendance calendar with month navigation and per-day detail, the state-driven daily action
button (Check-In / Check-Out / Resubmit), the center power FAB (performs the real duty action),
sign-out.

**Only navigates (no real action):** Assignment and Register quick tiles, the "This week" card
(it just repeats today's assignment — not a real future schedule).

**Dead / placeholder:** nav badge counts (never populated), the hero "Zone/Selfie/Supervisor
verified" trust chips and the "selfie matched / sign-off pending" boxes (hardcoded labels, not
bound to real evidence), captured selfies are discarded (no-op uploader).

**Missing:** a student earnings/stipend view (there's a payroll repo but no screen), a
leave/absence request UI, an editable profile, and — most importantly — the submitted check-out
does not reach the supervisor (see core finding).

---

## Supervisor portal — status

**Works:** the review queue list with search + filter, opening a session and choosing
**Approve / Flag / Reject** with a note (advances the state machine, updates the badge) — but only
against the fixture items, and only for the running session (resets on restart). Roster directory
with search, student-detail dossier, sign-out.

**Only navigates:** all bottom-nav tabs, the center check FAB (just opens the Reviews tab —
despite the check icon it performs no action), "View all", quick tiles.

**Dead / placeholder:** "Reports" quick action (snackbar stub), work-zone row taps (snackbar
stub), the evidence pane in the review sheet (static placeholder in local build). Minor bug: the
"Pending" filter chip on the roster does nothing.

**Missing (your explicit requirements):**
- Live view of student check-outs (queue is disconnected from student activity).
- Add a student (form + assign to department/location).
- Remove a student.
- Adjust a student's shift timings (shown as read-only text only).

---

## Admin / SDO portal — status

**Works:** live counts everywhere (students, supervisors, locations, assignments, pending/approved),
full directories with search/filter for students, supervisors, locations, assignments; location and
student detail dossiers; calendar with month navigation; sign-out.

**Only navigates:** all tabs, the center "+" FAB (just opens the Manage hub — creates nothing),
directory rows.

**Dead / placeholder:** Payroll "Export PDF" and "Approve Batch" buttons are **permanently
disabled**; payroll figures (₹224,400, ₹150/day, 21 present days, the 3-row ledger) are hardcoded
fixtures, not computed; the "77 validation issues" health panel is static text; "On duty" and
"Month payout" tiles are literal `—` / `₹—`. Supervisor and Assignment rows aren't even tappable.

**Missing (your explicit requirements):**
- Add / remove supervisors and students.
- Send messages / notifications to supervisors or students (no such subsystem exists at all).
- Manage / adjust shifts for supervisors and students.
- Working reports/payroll export.

---

## Recommended build sequence

To make the app genuinely functional, in priority order:

1. **Connect the portals (the core loop).** Make the supervisor's review queue read from real
   student check-outs so that when a student checks out it appears live for the supervisor, who
   approves/flags/rejects, and the result flows back to the student's screen. This single change
   is what makes the app feel "deep."
2. **Runtime roster store** so add/remove/edit works (the seed is currently read-only constants).
3. **Supervisor powers:** add student (form + assign to location/department), remove student,
   adjust shift timings.
4. **Admin powers:** add/remove supervisors & students, adjust shifts, working payroll
   (computed from attendance) with functional export/approve.
5. **Notifications/messaging** between roles.
6. **More logins** from the real seed (students EL2627-002…068, supervisors SV-02…10).
7. **Clean up dead placeholders** (disabled buttons, snackbar stubs, unbound labels).

---

## Two decisions that shape everything

1. **How "live" and how durable?** In this local (no-Firebase) build, true cross-**device**
   real-time (student's phone → supervisor's phone) is not possible, and data resets on app
   restart. Options: (a) a single-device connected demo where everything works when you switch
   roles, kept in memory; (b) the same but saved on-device so it survives restarts; (c) turn
   Firebase back on for true multi-device real-time (needs your Firebase project + lifts the
   "don't touch backend" rule).
2. **Scope for this pass** — build the full list above, or start with the core loop (#1–#3) and
   iterate.

