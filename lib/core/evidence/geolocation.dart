import 'package:geolocator/geolocator.dart' hide LocationServiceDisabledException;

import 'evidence_geo.dart';
import 'evidence_types.dart';

/// Samples the mandatory GPS fix for a check-in/check-out.
abstract class GeoSampler {
  Future<EvidenceGeo?> sample();
}

class GeolocatorSampler implements GeoSampler {
  const GeolocatorSampler({
    this.timeLimit = const Duration(seconds: 15),
    this.maxAccuracyMeters = 150.0,
  });

  static const Duration defaultTimeLimit = Duration(seconds: 15);
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