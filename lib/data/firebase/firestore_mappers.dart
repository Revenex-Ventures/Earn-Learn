import 'package:cloud_firestore/cloud_firestore.dart'
    show Timestamp;

import '../../core/models/models.dart';
import '../../domain/attendance/session.dart';
import '../../domain/attendance/session_mapping.dart';
import '../../domain/attendance/session_status.dart';
import '../../domain/identity/account_link.dart';

/// Deterministic document keys. Sessions live at
/// `attendance/{studentId}/{yyyy-MM}/{yyyy-MM-dd}`; operations (idempotency
/// ledger) live in a sibling `operations/` namespace.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

DateTime? parseTimestamp(Object? value) {
  if (value is DateTime) return value.toUtc();
  if (value is Timestamp) return value.toDate().toUtc();
  if (value is String) return DateTime.tryParse(value);
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.round() * 1000);
  }
  if (value is Map) {
    final seconds = (value['seconds'] as num?)?.toInt();
    final nanos = (value['nanoseconds'] as num?)?.toInt();
    if (seconds != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000 + (nanos ?? 0) ~/ 1000000,
        isUtc: true,
      );
    }
  }
  return null;
}

String parseString(Object? value, String fallback) =>
    value is String && value.isNotEmpty ? value : fallback;

double parseDouble(Object? value, double fallback) =>
    value is num ? value.toDouble() : fallback;

int parseInt(Object? value, int fallback) =>
    value is num ? value.toInt() : fallback;

bool parseBool(Object? value, bool fallback) =>
    value is bool ? value : fallback;

T parseEnum<T extends Enum>(List<T> values, Object? value, T fallback) =>
    values.firstWhere((e) => e.name == value, orElse: () => fallback);

/// Server session document → domain [Session].
Session mapSessionFromDoc({
  required String id,
  required Map<String, Object?> data,
}) {
  final windows = <ShiftWindow>[];
  final rawWindows = data['windows'];
  if (rawWindows is List) {
    for (final w in rawWindows) {
      if (w is Map) {
        windows.add(ShiftWindow(
          start: Duration(minutes: parseInt(w['startMin'], 0)),
          end: Duration(minutes: parseInt(w['endMin'], 60 * 24)),
        ));
      }
    }
  }

  return Session(
    id: id,
    studentId: parseString(data['studentId'], ''),
    date: _dateFromKey(id),
    windows: windows,
    status: parseEnum(
      SessionStatus.values,
      data['status'],
      SessionStatus.scheduled,
    ),
    review: parseEnum(
      ApprovalStatus.values,
      data['review'],
      ApprovalStatus.pending,
    ),
    checkInRequestedAt: parseTimestamp(data['checkInRequestedAt']),
    checkInVerifiedAt: parseTimestamp(data['checkInVerifiedAt']),
    checkOutRequestedAt: parseTimestamp(data['checkOutRequestedAt']),
    checkOutVerifiedAt: parseTimestamp(data['checkOutVerifiedAt']),
    verifiedHours: parseDouble(data['verifiedHours'], 0),
    reason: data['reason'] as String?,
    createdAt: parseTimestamp(data['createdAt']),
    updatedAt: parseTimestamp(data['updatedAt']),
  );
}

/// Projection of a server session onto the client's month/day views.
///
/// Delegates to the canonical [attendanceRecordFromSession] in the domain
/// layer so the status mapping stays in sync with the local repository.
AttendanceRecord? mapAttendanceRecordFromSession(Session s) =>
    attendanceRecordFromSession(s);

Map<String, Object?> sessionToUploadDoc(Session s) => {
      'studentId': s.studentId,
      'date': dateKey(s.date),
      'windows': [
        for (final w in s.windows)
          {'startMin': w.start.inMinutes, 'endMin': w.end.inMinutes},
      ],
      'status': s.status.name,
      'review': s.review.name,
      'verifiedHours': s.verifiedHours,
      if (s.checkInRequestedAt != null)
        'checkInRequestedAt': s.checkInRequestedAt!.toUtc().toIso8601String(),
      if (s.checkOutRequestedAt != null)
        'checkOutRequestedAt': s.checkOutRequestedAt!.toUtc().toIso8601String(),
    };

Student mapStudentFromDoc({
  required String id,
  required Map<String, Object?> data,
}) {
  return Student(
    id: id,
    name: parseString(data['name'], id),
    rollNumber: parseString(data['rollNumber'], id),
    uid: data['uid'] as String?,
    email: data['email'] as String?,
    contact: data['contact'] as String?,
    department: data['department'] as String?,
    className: data['className'] as String?,
    status: parseEnum(AccountStatus.values, data['status'], AccountStatus.active),
    createdAt: parseTimestamp(data['createdAt']),
    updatedAt: parseTimestamp(data['updatedAt']),
  );
}

Supervisor mapSupervisorFromDoc({
  required String id,
  required Map<String, Object?> data,
}) {
  final rawIds = data['assignedLocationIds'];
  return Supervisor(
    id: id,
    name: parseString(data['name'], id),
    uid: data['uid'] as String?,
    department: data['department'] as String?,
    email: data['email'] as String?,
    contact: data['contact'] as String?,
    assignedLocationIds: rawIds is List
        ? rawIds.map((e) => e.toString()).toList()
        : const [],
    status: parseEnum(
      SupervisorStatus.values,
      data['status'],
      SupervisorStatus.offDuty,
    ),
  );
}

Location mapLocationFromDoc({
  required String id,
  required Map<String, Object?> data,
}) {
  final supervisorIds = data['supervisorIds'];
  final studentIds = data['studentIds'];
  return Location(
    id: id,
    name: parseString(data['name'], id),
    description: data['description'] as String?,
    latitude: (data['latitude'] as num?)?.toDouble(),
    longitude: (data['longitude'] as num?)?.toDouble(),
    radiusMeters: parseDouble(data['radiusMeters'], 50),
    supervisorIds: supervisorIds is List
        ? supervisorIds.map((e) => e.toString()).toList()
        : const [],
    studentIds: studentIds is List
        ? studentIds.map((e) => e.toString()).toList()
        : const [],
    status: parseEnum(
      LocationStatus.values,
      data['status'],
      LocationStatus.active,
    ),
  );
}

Assignment mapAssignmentFromDoc({
  required String id,
  required Map<String, Object?> data,
}) {
  final windows = <ShiftWindow>[];
  final rawWindows = data['shiftWindows'];
  if (rawWindows is List) {
    for (final w in rawWindows) {
      if (w is Map) {
        windows.add(ShiftWindow(
          start: Duration(minutes: parseInt(w['startMin'], 0)),
          end: Duration(minutes: parseInt(w['endMin'], 60 * 24)),
        ));
      }
    }
  }
  return Assignment(
    id: id,
    studentId: parseString(data['studentId'], id),
    locationId: parseString(data['locationId'], ''),
    supervisorId: parseString(data['supervisorId'], ''),
    workDescription: parseString(data['workDescription'], ''),
    shiftWindows: windows,
    effectiveFrom: parseTimestamp(data['effectiveFrom']) ?? DateTime(1970),
    effectiveTo: parseTimestamp(data['effectiveTo']),
    maxMonthlyHours: parseInt(data['maxMonthlyHours'], 40),
    status: parseEnum(
      AssignmentStatus.values,
      data['status'],
      AssignmentStatus.active,
    ),
  );
}

UserProfile mapUserProfileFromDoc({
  required String uid,
  required Map<String, Object?> data,
}) {
  return UserProfile(
    uid: uid,
    email: data['email'] as String?,
    displayName: data['displayName'] as String?,
    photoUrl: data['photoUrl'] as String?,
    role: parseEnum(UserRole.values, data['role'], UserRole.student),
    status: parseEnum(AccountStatus.values, data['status'], AccountStatus.pending),
    createdAt: parseTimestamp(data['createdAt']) ?? DateTime(1970),
    updatedAt: parseTimestamp(data['updatedAt']) ?? DateTime(1970),
    lastLoginAt: parseTimestamp(data['lastLoginAt']),
  );
}

AccountLink? mapAccountLinkFromDoc({
  required String uid,
  required Map<String, Object?> data,
}) {
  final role = parseEnum(UserRole.values, data['role'], UserRole.student);
  if (role == UserRole.student || role == UserRole.supervisor) {
    final entityId = data['linkedEntityId'] as String?;
    if (entityId == null || entityId.isEmpty) {
      return AccountLink(userId: uid, role: role);
    }
    return AccountLink(userId: uid, role: role, entityId: entityId);
  }
  return AccountLink(userId: uid, role: role);
}

VerificationItem mapVerificationItem(Map<String, Object?> data) {
  return VerificationItem(
    id: parseString(data['id'], ''),
    studentName: parseString(data['studentName'], 'Unknown'),
    studentId: parseString(data['studentId'], ''),
    location: parseString(data['location'], ''),
    type: parseEnum(
      VerificationType.values,
      data['type'],
      VerificationType.checkIn,
    ),
    submittedAt: parseTimestamp(data['submittedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    status: parseEnum(
      ApprovalStatus.values,
      data['status'],
      ApprovalStatus.pending,
    ),
    summary: parseString(data['summary'], ''),
    evidenceTime: parseTimestamp(data['evidenceTime']),
  );
}

DateTime _dateFromKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return DateTime(1970);
  final year = int.tryParse(parts[0]) ?? 1970;
  final month = int.tryParse(parts[1]) ?? 1;
  final day = int.tryParse(parts[2]) ?? 1;
  return DateTime(year, month, day);
}