import 'package:geolocator/geolocator.dart' hide LocationServiceDisabledException;

import 'evidence_geo.dart';
import 'evidence_types.dart';

/// Samples the mandatory GPS fix for a check-in/check-out.
abstract class GeoSampler {
  Future<EvidenceGeo?> sample();
}

class GeolocatorSampler implements GeoSampler {
  const GeolocatorSampler({
    this.timeLimit = const Duration(seconds: 30),
    // TEMPORARY (until campus coordinates + geofence land): accept any real
    // device fix so location never blocks a check-in. The 150 m accuracy gate
    // used to reject weak/indoor fixes with "GPS signal is weak"; while there
    // are no coordinates to validate against, that strictness only gets in the
    // way. Restore a tighter value (e.g. 150) and add the geofence check once
    // location coordinates are configured.
    this.maxAccuracyMeters = 100000.0,
  });

  static const Duration defaultTimeLimit = Duration(seconds: 30);
  final Duration timeLimit;
  final double maxAccuracyMeters;

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

    return EvidenceGeo(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      capturedAt: position.timestamp,
    );
  }
}