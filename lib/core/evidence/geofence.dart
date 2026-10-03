/// Geofence utilities for campus location validation.
library;

import 'dart:math' as math;

/// Represents a circular geofence zone.
class Geofence {
  const Geofence({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final double latitude;
  final double longitude;
  final double radiusMeters;

  /// Checks if a given coordinate is within the geofence.
  bool contains(double lat, double lng) {
    return _haversineDistance(latitude, longitude, lat, lng) <= radiusMeters;
  }

  /// Calculates distance from the geofence center to a point in meters.
  double distanceTo(double lat, double lng) {
    return _haversineDistance(latitude, longitude, lat, lng);
  }

  /// Haversine great-circle distance between two points on Earth, in metres.
  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusMeters = 6371000.0;

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final lat1Rad = _toRadians(lat1);
    final lat2Rad = _toRadians(lat2);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) *
            math.sin(dLon / 2) *
            math.cos(lat1Rad) *
            math.cos(lat2Rad);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;
}
