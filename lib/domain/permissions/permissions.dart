import '../../core/models/models.dart';

/// Fine-grained actions the app exposes.
enum DomainPermission {
  viewOwnProfile,
  viewOwnAssignment,
  viewOwnAttendance,
  submitLeave,
  requestCorrection,
  initiateCheckIn,
  initiateCheckOut,
  reviewAttendance,
  flagAttendance,
  rejectAttendance,
  requestCorrectionFor,
  manageStudents,
  manageSupervisors,
  manageLocations,
  manageAssignments,
  manageCalendar,
  managePolicy,
  managePayroll,
  approvePayroll,
  viewAllAttendance,
  viewAllPayroll,
  viewReports,
  viewAuditLog,
  writeCriticalFields,
}

/// Identity of an actor making a permission decision.
class Actor {
  const Actor({
    required this.userId,
    required this.role,
    this.supervisorId,
    this.studentId,
    this.zoneIds = const {},
  });

  final String userId;
  final UserRole role;

  /// Directory ids the actor owns (SV-* / STU-*).
  final String? supervisorId;
  final String? studentId;

  /// Locations whose sessions/students this supervisor may act on.
  final Set<String> zoneIds;
}

/// Outcome of a permission check.
class PermissionDecision {
  const PermissionDecision({
    required this.allowed,
    this.denialReason,
  });

  final bool allowed;
  final String? denialReason;

  static const PermissionDecision allow = PermissionDecision(allowed: true);

  static PermissionDecision deny(String reason) =>
      PermissionDecision(allowed: false, denialReason: reason);
}

/// Role → permission matrix (coarse role gates).
const Map<UserRole, Set<DomainPermission>> _rolePermissions = {
  UserRole.student: {
    DomainPermission.viewOwnProfile,
    DomainPermission.viewOwnAssignment,
    DomainPermission.viewOwnAttendance,
    DomainPermission.submitLeave,
    DomainPermission.requestCorrection,
    DomainPermission.initiateCheckIn,
    DomainPermission.initiateCheckOut,
  },
  UserRole.supervisor: {
    DomainPermission.initiateCheckIn,
    DomainPermission.initiateCheckOut,
    DomainPermission.reviewAttendance,
    DomainPermission.flagAttendance,
    DomainPermission.rejectAttendance,
    DomainPermission.requestCorrectionFor,
    DomainPermission.viewAllAttendance,
    DomainPermission.viewAuditLog,
  },
  UserRole.admin: {
    DomainPermission.manageStudents,
    DomainPermission.manageSupervisors,
    DomainPermission.manageLocations,
    DomainPermission.manageAssignments,
    DomainPermission.manageCalendar,
    DomainPermission.managePolicy,
    DomainPermission.managePayroll,
    DomainPermission.approvePayroll,
    DomainPermission.viewAllAttendance,
    DomainPermission.viewAllPayroll,
    DomainPermission.viewReports,
    DomainPermission.viewAuditLog,
  },
};

/// Columns that are never client-writable and only mutated server-side.
const Set<String> criticalFields = {
  'role',
  'status',
  'verifiedHours',
  'paymentStatus',
  'coordinates',
  'checkInVerifiedAt',
  'checkOutVerifiedAt',
  'review',
};

/// Evaluates [permission] for [actor], with optional target scoping.
///
/// Scoping rules: students can only act on their own record; supervisors can
/// only review sessions in locations they are assigned to.
PermissionDecision checkPermission({
  required Actor actor,
  required DomainPermission permission,
  Student? targetStudent,
  Supervisor? targetSupervisor,
  String? targetLocationId,
}) {
  if (permission == DomainPermission.writeCriticalFields) {
    return const PermissionDecision(
      allowed: false,
      denialReason: 'Critical fields are server-writable only.',
    );
  }

  final granted = _rolePermissions[actor.role] ?? const <DomainPermission>{};
  if (!granted.contains(permission)) {
    return PermissionDecision.deny(
      'Role ${actor.role.name} cannot ${permission.name}.',
    );
  }

  if (actor.role == UserRole.student &&
      targetStudent != null &&
      actor.studentId != targetStudent.id &&
      permission.name.startsWith('viewOwn')) {
    return PermissionDecision.deny(
      'Student ${actor.studentId} cannot access ${targetStudent.id}.',
    );
  }

  if (actor.role == UserRole.supervisor &&
      targetSupervisor != null &&
      actor.supervisorId != targetSupervisor.id) {
    return PermissionDecision.deny(
      'Supervisor ${actor.supervisorId} cannot target ${targetSupervisor.id}.',
    );
  }

  final zoneGated = permission == DomainPermission.reviewAttendance ||
      permission == DomainPermission.flagAttendance ||
      permission == DomainPermission.rejectAttendance ||
      permission == DomainPermission.requestCorrectionFor;
  if (actor.role == UserRole.supervisor &&
      zoneGated &&
      targetLocationId != null &&
      !actor.zoneIds.contains(targetLocationId)) {
    return PermissionDecision.deny(
      'Supervisor is not assigned to location $targetLocationId.',
    );
  }

  return PermissionDecision.allow;
}