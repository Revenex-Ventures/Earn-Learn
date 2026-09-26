import '../../core/models/models.dart';

/// Raised when an assignment cannot be resolved safely for a student.
class AssignmentResolutionException implements Exception {
  const AssignmentResolutionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Fully-resolved view of a student's assignment against the directory.
class AssignmentResolution {
  const AssignmentResolution({
    required this.assignment,
    required this.location,
    required this.supervisor,
  });

  final Assignment assignment;
  final Location location;
  final Supervisor supervisor;

  List<ShiftWindow> get windows => assignment.shiftWindows;

  /// Windows active on [day], restricted to live assignments. Students cannot
  /// mutate assignments; live status + effective dates gate what is scheduled.
  List<ShiftWindow> windowsOn(DateTime day) {
    if (assignment.status != AssignmentStatus.active &&
        assignment.status != AssignmentStatus.temporary) {
      return const [];
    }
    return assignment.windowsOn(day);
  }
}

/// Resolves a student's assignment against the directory and the clock.
///
/// A confirmed result is only produced when the assignment, its location and
/// its supervisor all resolve; anything less is a [null] (no assignment) or an
/// [AssignmentResolutionException] (broken reference).
AssignmentResolution? resolveAssignmentFor({
  required Student student,
  required List<Assignment> assignments,
  required List<Location> locations,
  required List<Supervisor> supervisors,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  Assignment? found;
  for (final a in assignments) {
    if (a.studentId != student.id) continue;
    if (a.status != AssignmentStatus.active &&
        a.status != AssignmentStatus.temporary) {
      continue;
    }
    if (today.isBefore(a.effectiveFrom)) continue;
    if (a.effectiveTo != null && today.isAfter(a.effectiveTo!)) continue;
    if (found == null || a.effectiveFrom.isAfter(found.effectiveFrom)) {
      found = a;
    }
  }
  if (found == null) return null;

  Location? location;
  for (final l in locations) {
    if (l.id == found.locationId) location = l;
  }
  Supervisor? supervisor;
  for (final s in supervisors) {
    if (s.id == found.supervisorId) supervisor = s;
  }
  if (location == null || supervisor == null) {
    throw AssignmentResolutionException(
      'Assignment ${found.id} references a missing location or supervisor.',
    );
  }
  return AssignmentResolution(
    assignment: found,
    location: location,
    supervisor: supervisor,
  );
}