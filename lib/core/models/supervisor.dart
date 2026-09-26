import 'supervisor_status.dart';

class Supervisor {
  const Supervisor({
    required this.id,
    required this.name,
    required this.assignedLocationIds,
    required this.status,
    this.uid,
    this.department,
    this.email,
    this.contact,
  });

  final String id;
  final String? uid;
  final String name;
  final String? department;
  final String? email;
  final String? contact;
  final List<String> assignedLocationIds;
  final SupervisorStatus status;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String get departmentOrNA =>
      (department != null && department!.trim().isNotEmpty) ? department! : 'Not specified';

  String get contactOrNA =>
      (contact != null && contact!.trim().isNotEmpty) ? contact! : 'Not available';

  static const String collection = 'supervisors';
}