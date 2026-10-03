import 'package:geolocator/geolocator.dart' hide LocationServiceDisabledException;

import 'evidence_geo.dart';
import 'evidence_types.dart';
import 'geofence.dart';

/// Samples the mandatory GPS fix for a check-in/check-out.
abstract class GeoSampler {
  Future<EvidenceGeo?> sample();
}

/// Configuration for campus geofence validation.
class CampusGeofenceConfig {
  const CampusGeofenceConfig({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final double latitude;
  final double longitude;
  final double radiusMeters;

  Geofence get geofence => Geofence(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );
}

class GeolocatorSampler implements GeoSampler {
  const GeolocatorSampler({
    this.timeLimit = const Duration(seconds: 15),
    this.maxAccuracyMeters = 150.0,
    this.campusGeofence,
  });

  static const Duration defaultTimeLimit = Duration(seconds: 15);
  final Duration timeLimit;
  final double maxAccuracyMeters;
  final CampusGeofenceConfig? campusGeofence;

  @override
  Future<EvidenceGeo?> sample() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationPermissionDeniedException();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermanentlyDeniedException();
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    ).timeout(timeLimit);

    if (position.accuracy > maxAccuracyMeters) {
      throw PoorLocationAccuracyException(
        accuracyMeters: position.accuracy,
        maxAllowedMeters: maxAccuracyMeters,
      );
    }

    if (campusGeofence != null) {
      final geofence = campusGeofence!.geofence;
      if (!geofence.contains(position.latitude, position.longitude)) {
        final distance = geofence.distanceTo(
          position.latitude,
          position.longitude,
        );
        throw OutsideGeofenceException(
          distanceMeters: distance,
          geofenceRadiusMeters: campusGeofence!.radiusMeters,
        );
      }
    }

    return EvidenceGeo(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      capturedAt: position.timestamp,
    );
  }
}