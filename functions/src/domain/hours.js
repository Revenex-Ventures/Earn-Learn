"use strict";

/**
 * Server-authoritative verified-hours computation.
 *
 * verifiedHours = overlap of the server-confirmed interval
 * [checkInVerifiedAt, checkOutVerifiedAt] with the day's shift windows.
 *
 * Day/window times are interpreted in UTC to keep the emulator deterministic
 * (a documented simplification of this stage; local wall-clock time mapping
 * is a Stage 2B calibration item).
 */

/**
 * @param {string} dayKey YYYY-MM-DD
 * @returns {number} minutes from UTC midnight
 */
function minutesOfDayUtc(dayKey, iso) {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return -1;
  return d.getUTCHours() * 60 + d.getUTCMinutes();
}

function windowStartMs(dayKey, startMin) {
  const [y, m, day] = dayKey.split("-").map(Number);
  return Date.UTC(y, m - 1, day, Math.floor(startMin / 60), startMin % 60, 0);
}

function windowEndMs(dayKey, endMin) {
  const [y, m, day] = dayKey.split("-").map(Number);
  return Date.UTC(y, m - 1, day, Math.floor(endMin / 60), endMin % 60, 0);
}

/**
 * Overlap hours of [inIso, outIso] with windows [{startMin,endMin}] on dayKey.
 * Returns raw hours (methods aligned with the shift machine: no deductions).
 */
function computeVerifiedHours({ dayKey, checkInVerifiedAt, checkOutVerifiedAt, windows }) {
  if (!checkInVerifiedAt || !checkOutVerifiedAt) return 0;
  const inMs = new Date(checkInVerifiedAt).getTime();
  const outMs = new Date(checkOutVerifiedAt).getTime();
  if (!Number.isFinite(inMs) || !Number.isFinite(outMs)) return 0;
  if (outMs < inMs) return 0;

  let ms = 0;
  for (const w of windows || []) {
    const s = windowStartMs(dayKey, w.startMin);
    const e = windowEndMs(dayKey, w.endMin);
    // overlapMinutes is unit-agnostic (works for epoch-ms and minute frames).
    if (e > s) ms += overlapMinutes(inMs, outMs, s, e);
  }
  return ms / 3_600_000;
}

function plannedHours(windows) {
  return (windows || []).reduce(
    (sum, w) => sum + Math.max(0, (w.endMin - w.startMin) / 60),
    0
  );
}

function utcStartOfDay(date) {
  const d = date instanceof Date ? date : new Date(date);
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
}

function dayKeyFor(date) {
  const d = utcStartOfDay(date);
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
}

function minutesToTime(minutes) {
  const mins = Math.max(0, Math.round(minutes));
  return `${String(Math.floor(mins / 60)).padStart(2, "0")}:${String(mins % 60).padStart(2, "0")}`;
}

/** Overlap in whole minutes of two [start,end] minute frames. */
function overlapMinutes(aStart, aEnd, bStart, bEnd) {
  const start = Math.max(aStart, bStart);
  const end = Math.min(aEnd, bEnd);
  return Math.max(0, end - start);
}

/** Intersect [start,end] against [bStart,bEnd]; null when disjoint. */
function intersectWindow(start, end, bStart, bEnd) {
  const s = Math.max(start, bStart);
  const e = Math.min(end, bEnd);
  return e > s ? { startMin: s, endMin: e } : null;
}

module.exports = {
  computeVerifiedHours,
  plannedHours,
  windowStartMs,
  windowEndMs,
  minutesOfDayUtc,
  utcStartOfDay,
  dayKeyFor,
  minutesToTime,
  overlapMinutes,
  intersectWindow,
};