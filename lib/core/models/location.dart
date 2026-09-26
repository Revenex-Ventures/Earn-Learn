import 'location_status.dart';

class Location {
  const Location({
    required this.id,
    required this.name,
    required this.status,
    this.description,
    this.latitude,
    this.longitude,
    this.radiusMeters = 50,
    this.supervisorIds = const [],
    this.studentIds = const [],
  });

  final String id;
  final String name;
  final String? description;
  final double? latitude;
  final double? longitude;
  final double radiusMeters;
  final List<String> supervisorIds;
  final List<String> studentIds;
  final LocationStatus status;

  static const String collection = 'locations';
}