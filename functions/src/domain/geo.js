"use strict";

/**
 * Geofence math for evidence GPS validation. Pure & unit-testable.
 */

const EARTH_RADIUS_M = 6_371_000;

function toRadians(degrees) {
  return (degrees * Math.PI) / 180;
}

/** Haversine distance in meters between two WGS84 points. */
function distanceMeters(lat1, lng1, lat2, lng2) {
  const dLat = toRadians(lat2 - lat1);
  const dLng = toRadians(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(a)));
}

/**
 * True when the evidence fix falls inside the assigned location's radius
 * (plus a fixed device-accuracy tolerance). [toleranceMeters] defaults to the
 * reported fix accuracy so a reading that just misses the fence is still
 * acceptable for automatic verification.
 */
function isWithinLocation({ lat, lng, accuracyMeters }, location, toleranceMeters) {
  if (location.latitude == null || location.longitude == null) return false;
  const d = distanceMeters(lat, lng, location.latitude, location.longitude);
  const tol = Number.isFinite(toleranceMeters)
    ? toleranceMeters
    : (Number.isFinite(accuracyMeters) ? accuracyMeters : 0);
  return d <= (location.radiusMeters || 0) + tol;
}

module.exports = { distanceMeters, isWithinLocation };