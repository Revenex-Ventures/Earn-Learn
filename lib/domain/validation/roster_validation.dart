import '../../core/models/models.dart';
import '../identity/account_link.dart';

/// Severity of a roster finding.
enum RosterIssueSeverity {
  error,
  warning,
  info;

  String get label => switch (this) {
        RosterIssueSeverity.error => 'Error',
        RosterIssueSeverity.warning => 'Warning',
        RosterIssueSeverity.info => 'Info',
      };
}

/// A single finding from roster validation.
class RosterIssue {
  const RosterIssue({
    required this.code,
    required this.severity,
    required this.message,
    this.entityType,
    this.entityId,
    this.entityName,
  });

  final String code;
  final RosterIssueSeverity severity;
  final String message;
  final String? entityType;
  final String? entityId;
  final String? entityName;

  String get displayName => entityName ?? entityId ?? '-';
}

/// Result of validating the institutional roster snapshot.
class RosterValidationReport {
  const RosterValidationReport({required this.issues});

  final List<RosterIssue> issues;

  Iterable<RosterIssue> where(RosterIssueSeverity severity) =>
      issues.where((i) => i.severity == severity);

  int count(RosterIssueSeverity severity) => where(severity).length;

  /// Passes only when every real data requirement is met. Missing student
  /// contacts are a hard error per the data checklist.
  bool get passesCoreChecks => count(RosterIssueSeverity.error) == 0;
}

/// Validates the college workbook snapshot for data readiness.
///
/// All findings derive from the actual seed; nothing is assumed or invented.
RosterValidationReport validateRoster({
  required List<Student> students,
  required List<Supervisor> supervisors,
  required List<Location> locations,
  required List<Assignment> assignments,
  List<AccountLink> links = const [],
}) {
  final issues = <RosterIssue>[];

  final locationById = {for (final l in locations) l.id: l};
  final supervisorById = {for (final s in supervisors) s.id: s};
  final linkedStudentIds = {
    for (final l in links)
      if (l.role == UserRole.student) l.entityId,
  };
  final linkedSupervisorIds = {
    for (final l in links)
      if (l.role == UserRole.supervisor) l.entityId,
  };

  void add({
    required String code,
    required RosterIssueSeverity severity,
    required String message,
    String? entityType,
    String? entityId,
    String? entityName,
  }) {
    issues.add(RosterIssue(
      code: code,
      severity: severity,
      message: message,
      entityType: entityType,
      entityId: entityId,
      entityName: entityName,
    ));
  }

  final seenRollNumbers = <String>{};
  for (final s in students) {
    final missingContact =
        s.contact == null || s.contact!.trim().isEmpty;
    if (missingContact) {
      add(
        code: 'student-missing-contact',
        severity: RosterIssueSeverity.error,
        message: 'No contact number on record.',
        entityType: 'student',
        entityId: s.id,
        entityName: s.name,
      );
    }
    if (s.department == null || s.department!.trim().isEmpty) {
      add(
        code: 'student-missing-department',
        severity: RosterIssueSeverity.warning,
        message: 'No department on record.',
        entityType: 'student',
        entityId: s.id,
        entityName: s.name,
      );
    }
    if (s.uid == null && !linkedStudentIds.contains(s.id)) {
      add(
        code: 'student-unlinked-account',
        severity: RosterIssueSeverity.warning,
        message: 'No account is linked to this student.',
        entityType: 'student',
        entityId: s.id,
        entityName: s.name,
      );
    }
    if (!seenRollNumbers.add(s.rollNumber)) {
      add(
        code: 'duplicate-roll-number',
        severity: RosterIssueSeverity.error,
        message: 'Roll number ${s.rollNumber} is duplicated.',
        entityType: 'student',
        entityId: s.id,
        entityName: s.name,
      );
    }
  }

  for (final s in supervisors) {
    final missingEmail = s.email == null || s.email!.trim().isEmpty;
    if (missingEmail) {
      add(
        code: 'supervisor-missing-email',
        severity: RosterIssueSeverity.error,
        message: 'No email on record.',
        entityType: 'supervisor',
        entityId: s.id,
        entityName: s.name,
      );
    } else {
      add(
        code: 'supervisor-email-unconfirmed',
        severity: RosterIssueSeverity.info,
        message: 'Email is on record; the college must confirm it before release.',
        entityType: 'supervisor',
        entityId: s.id,
        entityName: s.name,
      );
    }
    if (s.contact == null || s.contact!.trim().isEmpty) {
      add(
        code: 'supervisor-missing-contact',
        severity: RosterIssueSeverity.warning,
        message: 'No contact number on record.',
        entityType: 'supervisor',
        entityId: s.id,
        entityName: s.name,
      );
    }
    if (s.uid == null && !linkedSupervisorIds.contains(s.id)) {
      add(
        code: 'supervisor-unlinked-account',
        severity: RosterIssueSeverity.warning,
        message: 'No account is linked to this supervisor.',
        entityType: 'supervisor',
        entityId: s.id,
        entityName: s.name,
      );
    }
    for (final loc in s.assignedLocationIds) {
      if (!locationById.containsKey(loc)) {
        add(
          code: 'supervisor-unknown-location',
          severity: RosterIssueSeverity.error,
          message: 'Assigned location $loc is not in the location list.',
          entityType: 'supervisor',
          entityId: s.id,
          entityName: s.name,
        );
      }
    }
    if (s.status == SupervisorStatus.offDuty &&
        assignments.any((a) => a.supervisorId == s.id)) {
      add(
        code: 'offduty-supervisor-with-students',
        severity: RosterIssueSeverity.warning,
        message: 'Off-duty supervisor still has assigned students.',
        entityType: 'supervisor',
        entityId: s.id,
        entityName: s.name,
      );
    }
  }

  for (final l in locations) {
    if (l.latitude == null || l.longitude == null) {
      add(
        code: 'location-missing-coordinates',
        severity: RosterIssueSeverity.warning,
        message: 'No coordinates on record; geofencing will not work until set.',
        entityType: 'location',
        entityId: l.id,
        entityName: l.name,
      );
    }
  }

  final assignedStudentIds = <String>{};
  for (final a in assignments) {
    if (!locationById.containsKey(a.locationId)) {
      add(
        code: 'assignment-unknown-location',
        severity: RosterIssueSeverity.error,
        message: 'References location ${a.locationId}, which is not in the list.',
        entityType: 'assignment',
        entityId: a.id,
      );
    }
    if (!supervisorById.containsKey(a.supervisorId)) {
      add(
        code: 'assignment-unknown-supervisor',
        severity: RosterIssueSeverity.error,
        message: 'References supervisor ${a.supervisorId}, which is not in the list.',
        entityType: 'assignment',
        entityId: a.id,
      );
    }
    if (a.workDescription.trim().isEmpty) {
      add(
        code: 'assignment-missing-work-description',
        severity: RosterIssueSeverity.error,
        message: 'No work description on record.',
        entityType: 'assignment',
        entityId: a.id,
      );
    }
    if (a.shiftWindows.isEmpty) {
      add(
        code: 'assignment-missing-windows',
        severity: RosterIssueSeverity.error,
        message: 'No shift windows defined.',
        entityType: 'assignment',
        entityId: a.id,
      );
    }
    if (a.status == AssignmentStatus.active && a.maxMonthlyHours <= 0) {
      add(
        code: 'assignment-invalid-cap',
        severity: RosterIssueSeverity.error,
        message: 'Monthly hour cap must be positive.',
        entityType: 'assignment',
        entityId: a.id,
      );
    }
    final student = _findStudent(
      studentId: a.studentId,
      students: students,
    );
    if (student == null) {
      add(
        code: 'assignment-unknown-student',
        severity: RosterIssueSeverity.error,
        message: 'References student ${a.studentId}, which is not in the list.',
        entityType: 'assignment',
        entityId: a.id,
      );
    } else {
      assignedStudentIds.add(student.id);
    }
  }

  for (final s in students) {
    if (!assignedStudentIds.contains(s.id)) {
      add(
        code: 'student-without-assignment',
        severity: RosterIssueSeverity.warning,
        message: 'No assignment on record.',
        entityType: 'student',
        entityId: s.id,
        entityName: s.name,
      );
    }
  }

  return RosterValidationReport(issues: issues);
}

Student? _findStudent({
  required String studentId,
  required List<Student> students,
}) {
  for (final s in students) {
    if (s.id == studentId) return s;
  }
  return null;
}