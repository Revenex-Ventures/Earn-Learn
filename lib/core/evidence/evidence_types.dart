/// Evidence capture domain types shared by the evidence service,
/// the attendance gateway, and the student attendance flow.
library;

/// A selfie captured for identity verification.
class SelfieCapture {
  const SelfieCapture({
    required this.bytes,
    required this.mimeType,
    this.sizeBytes,
    this.capturedAt,
    this.localPath,
  });

  final List<int> bytes;
  final String mimeType;
  final int? sizeBytes;
  final DateTime? capturedAt;
  final String? localPath;

  int get size => sizeBytes ?? bytes.length;
}

/// Thrown when camera permission is denied by the user.
class CameraPermissionDeniedException implements Exception {
  const CameraPermissionDeniedException([this.message = 'Camera permission was denied.']);
  final String message;
  @override
  String toString() => message;
}

/// Thrown when camera permission is permanently denied in system settings.
class CameraPermanentlyDeniedException implements Exception {
  const CameraPermanentlyDeniedException([this.message = 'Camera permission is permanently denied. Please enable in settings.']);
  final String message;
  @override
  String toString() => message;
}

/// Thrown when no camera hardware is available on the device.
class CameraUnavailableException implements Exception {
  const CameraUnavailableException([this.message = 'No camera hardware found on this device.']);
  final String message;
  @override
  String toString() => message;
}

/// Thrown when user cancels the selfie capture prompt.
class SelfieCaptureCancelledException implements Exception {
  const SelfieCaptureCancelledException([this.message = 'Selfie capture was cancelled.']);
  final String message;
  @override
  String toString() => message;
}

/// Thrown when location service is disabled on device.
class LocationServiceDisabledException implements Exception {
  const LocationServiceDisabledException([this.message = 'Location services (GPS) are disabled on your device.']);
  final String message;
  @override
  String toString() => message;
}

/// Thrown when location permission is denied by user.
class LocationPermissionDeniedException implements Exception {
  const LocationPermissionDeniedException([this.message = 'Location permission was denied.']);
  final String message;
  @override
  String toString() => message;
}

/// Thrown when location permission is permanently denied in settings.
class LocationPermanentlyDeniedException implements Exception {
  const LocationPermanentlyDeniedException([this.message = 'Location permission is permanently denied. Please enable in settings.']);
  final String message;
  @override
  String toString() => message;
}

/// Thrown when GPS fix accuracy is too poor for institutional verification.
class PoorLocationAccuracyException implements Exception {
  const PoorLocationAccuracyException({required this.accuracyMeters, this.maxAllowedMeters = 100.0});
  final double accuracyMeters;
  final double maxAllowedMeters;
  @override
  String toString() => 'GPS accuracy too low (±${accuracyMeters.round()}m, required ±${maxAllowedMeters.round()}m). Please move to an open area.';
}

/// Thrown when GPS fix is outside the campus geofence.
class OutsideGeofenceException implements Exception {
  const OutsideGeofenceException({
    required this.distanceMeters,
    required this.geofenceRadiusMeters,
    this.message,
  });

  final double distanceMeters;
  final double geofenceRadiusMeters;
  final String? message;

  @override
  String toString() =>
      message ??
      'Location is outside the campus geofence (${distanceMeters.round()}m from center, '
      'allowed radius: ${geofenceRadiusMeters.round()}m). Please move inside the campus zone.';
}