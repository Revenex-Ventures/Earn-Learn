/// Geographic fix captured with evidence.
class EvidenceGeo {
  const EvidenceGeo({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;

  Map<String, Object?> toMap() => {
        'lat': latitude,
        'lng': longitude,
        'accuracyMeters': accuracyMeters,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
      };

  static EvidenceGeo fromMap(Map<String, Object?> map) => EvidenceGeo(
        latitude: (map['lat'] as num?)?.toDouble() ?? 0,
        longitude: (map['lng'] as num?)?.toDouble() ?? 0,
        accuracyMeters: (map['accuracyMeters'] as num?)?.toDouble() ?? 0,
        capturedAt: DateTime.tryParse(map['capturedAt']?.toString() ?? '') ??
            DateTime.now().toUtc(),
      );
}