// Centralized mock data repository for Earn & Learn (AVCOE).
// Anchored on the authentic 15 locations and 68 student allocations from the college workbook.
// Dynamic attendance timeline is computed relative to DateTime.now().

import '../../core/models/models.dart';
import 'avcoe_seed_data.dart';

final DateTime mockNow = DateTime.now();
final DateTime mockToday = DateTime(mockNow.year, mockNow.month, mockNow.day);

// -----------------------------------------------------------------------------
// Institutional Entities
// -----------------------------------------------------------------------------
final List<Location> mockLocations = AvcoeSeedData.locations;
final List<Supervisor> mockSupervisors = AvcoeSeedData.supervisors;
final List<Student> mockStudents = AvcoeSeedData.students;
final List<Assignment> mockAssignments = AvcoeSeedData.createAssignments();

/// Locations enriched with the students stationed at each (from assignments).
final List<Location> mockLocationsWithCoverage = [
  for (final l in mockLocations)
    Location(
      id: l.id,
      name: l.name,
      description: l.description,
      latitude: l.latitude,
      longitude: l.longitude,
      radiusMeters: l.radiusMeters,
      supervisorIds: l.supervisorIds,
      studentIds: mockAssignments
          .where((a) => a.locationId == l.id)
          .map((a) => a.studentId)
          .toList(),
      status: l.status,
    ),
];

/// Server-side policy object (institution), 40h ceiling is a configurable value.
const AppPolicy mockAppPolicy = AppPolicy(monthlyMaxHours: 40);

/// Default student for demo / student portal (STU-001, Library).
final Student mockCurrentStudent = mockStudents.first;

/// Assigned supervisor used by supervisor portals (SV-01, Library).
final Supervisor mockCurrentSupervisor = mockSupervisors.first;

/// The real Student Development Officer who administers the scheme. Used as
/// the honest fallback whenever no signed-in account name is available —
/// never a placeholder stand-in.
const String mockAdminName = 'Dr. B.R. Borkar';
const String mockAdminRole = 'Student Development Officer';
const String mockAdminEmail = 'sdo@avcoe.edu.in';

/// Resolves a student's real name from the roster by their `STU-###` id.
/// Display surfaces call this instead of hard-coding an identity string, so a
/// re-imported allotment sheet flows through every screen automatically.
String mockStudentName(String studentId) {
  for (final s in mockStudents) {
    if (s.id == studentId) return s.name;
  }
  return 'Not available';
}

/// Resolves a student's workplace from their assignment, for the same reason:
/// location names must come from the sheet, never from a literal in this file.
String mockStudentLocation(String studentId) {
  final assignment = mockAssignmentFor(studentId);
  if (assignment == null) return 'Not assigned';
  if (assignment.locationName.isNotEmpty) return assignment.locationName;
  for (final l in mockLocations) {
    if (l.id == assignment.locationId) return l.name;
  }
  return 'Not assigned';
}

/// Profile records for signed-in demo identities (student, supervisor, admin).
final UserProfile mockStudentUser = UserProfile(
  uid: 'u-stu-001',
  email: 'el2627.student@avcoe.edu.in',
  displayName: mockCurrentStudent.name,
  role: UserRole.student,
  status: AccountStatus.active,
  createdAt: DateTime(mockNow.year - 1, 8, 1),
  updatedAt: mockNow,
  lastLoginAt: mockNow,
);

final UserProfile mockSupervisorUser = UserProfile(
  uid: 'u-sup-001',
  email: mockCurrentSupervisor.email,
  displayName: mockCurrentSupervisor.name,
  role: UserRole.supervisor,
  status: AccountStatus.active,
  createdAt: DateTime(mockNow.year - 2, 6, 15),
  updatedAt: mockNow,
  lastLoginAt: mockNow,
);

final UserProfile mockAdminUser = UserProfile(
  uid: 'u-admin-001',
  email: mockAdminEmail,
  displayName: mockAdminName,
  role: UserRole.admin,
  status: AccountStatus.active,
  createdAt: DateTime(mockNow.year - 3, 4, 1),
  updatedAt: mockNow,
  lastLoginAt: mockNow,
);

/// Demo user bound for the selected role in the development preview.
UserProfile mockUserForRole(UserRole? role) {
  switch (role) {
    case UserRole.supervisor:
      return mockSupervisorUser;
    case UserRole.admin:
      return mockAdminUser;
    case UserRole.student:
    case null:
      return mockStudentUser;
  }
}

/// Resolve a reference ID to its fixture, when present.
Location? mockLocationById(String id) {
  for (final l in mockLocationsWithCoverage) {
    if (l.id == id) return l;
  }
  return null;
}

Supervisor? mockSupervisorById(String id) {
  for (final s in mockSupervisors) {
    if (s.id == id) return s;
  }
  return null;
}

Assignment? mockAssignmentFor(String studentId) {
  for (final a in mockAssignments) {
    if (a.studentId == studentId) return a;
  }
  return null;
}

/// Active assignment for the default student.
final Assignment mockCurrentAssignment = mockAssignments.firstWhere(
  (a) => a.studentId == mockCurrentStudent.id,
  orElse: () => mockAssignments.first,
);

/// Primary shift window of the active demo assignment.
final ShiftWindow mockEveningShift = ShiftWindow(
  start: mockCurrentAssignment.shiftWindows.isNotEmpty
      ? mockCurrentAssignment.shiftWindows.first.start
      : const Duration(hours: 17),
  end: mockCurrentAssignment.shiftWindows.isNotEmpty
      ? mockCurrentAssignment.shiftWindows.first.end
      : const Duration(hours: 20),
);

// -----------------------------------------------------------------------------
// Calendar Events (Institutional Rules: Sundays Off, Paid Festivals, Holidays)
// -----------------------------------------------------------------------------
List<CalendarEvent> mockMonthCalendar(DateTime now) {
  final days = DateTime(now.year, now.month + 1, 0).day;
  final events = <CalendarEvent>[];

  var weekdaysSeen = 0;
  for (var day = 1; day <= days; day++) {
    final date = DateTime(now.year, now.month, day);
    if (date.weekday == DateTime.sunday) {
      events.add(CalendarEvent(
        date: date,
        label: 'Weekly off',
        type: CalendarEventType.offDay,
      ));
      continue;
    }
    weekdaysSeen++;
    if (weekdaysSeen == 2) {
      events.add(CalendarEvent(
        date: date,
        label: 'State Holiday',
        type: CalendarEventType.holiday,
      ));
    }
  }

  if (days >= 24) {
    final fest = DateTime(now.year, now.month, 24);
    events.add(CalendarEvent(
      date: fest,
      label: 'College Foundation Day',
      type: CalendarEventType.festival,
      isPaid: true,
    ));
  }

  return events;
}

final List<CalendarEvent> mockCalendar = mockMonthCalendar(mockNow);

// -----------------------------------------------------------------------------
// Attendance Records for the default student (3h daily duty)
// -----------------------------------------------------------------------------
List<AttendanceRecord> mockMonthAttendance(DateTime now, {String? studentId}) {
  final sid = studentId ?? mockCurrentStudent.id;
  final days = DateTime(now.year, now.month + 1, 0).day;
  final today = DateTime(now.year, now.month, now.day);

  final records = <AttendanceRecord>[];
  for (var day = 1; day <= days; day++) {
    final date = DateTime(now.year, now.month, day);
    if (date.weekday == DateTime.sunday && date != today) continue;

    if (date.isAfter(today)) {
      records.add(AttendanceRecord(
        id: 'ATT-${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}',
        studentId: sid,
        date: date,
        status: AttendanceStatus.scheduled,
        hours: 0,
        location: mockStudentLocation(sid),
      ));
      continue;
    }

    if (date == today) {
      if (now.hour < 17) {
        records.add(AttendanceRecord(
          id: 'ATT-TODAY',
          studentId: sid,
          date: date,
          status: AttendanceStatus.pending,
          hours: 0,
          location: mockStudentLocation(sid),
        ));
      } else if (now.hour < 20) {
        records.add(AttendanceRecord(
          id: 'ATT-TODAY',
          studentId: sid,
          date: date,
          status: AttendanceStatus.present,
          hours: 3.0,
          verifiedHours: 1.5,
          location: mockStudentLocation(sid),
          checkIn: DateTime(now.year, now.month, now.day, 17, 2),
        ));
      } else {
        records.add(AttendanceRecord(
          id: 'ATT-TODAY',
          studentId: sid,
          date: date,
          status: AttendanceStatus.present,
          hours: 3.0,
          verifiedHours: 3.0,
          location: mockStudentLocation(sid),
          checkIn: DateTime(now.year, now.month, now.day, 17, 2),
          checkOut: DateTime(now.year, now.month, now.day, 20, 0),
          review: ApprovalStatus.approved,
        ));
      }
      continue;
    }

    final dayOfMonth = day;
    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));
    final fourDaysAgo = today.subtract(const Duration(days: 4));
    final sixDaysAgo = today.subtract(const Duration(days: 6));

    if (date == yesterday) {
      records.add(AttendanceRecord(
        id: 'ATT-${date.day}',
        studentId: sid,
        date: date,
        status: AttendanceStatus.present,
        hours: 3.0,
        verifiedHours: 3.0,
        location: mockStudentLocation(sid),
        checkIn: DateTime(date.year, date.month, date.day, 17, 0),
        checkOut: DateTime(date.year, date.month, date.day, 20, 1),
        review: ApprovalStatus.approved,
      ));
    } else if (date == twoDaysAgo) {
      records.add(AttendanceRecord(
        id: 'ATT-${date.day}',
        studentId: sid,
        date: date,
        status: AttendanceStatus.pending,
        hours: 3.0,
        verifiedHours: 0,
        location: mockStudentLocation(sid),
        checkIn: DateTime(date.year, date.month, date.day, 17, 5),
        checkOut: DateTime(date.year, date.month, date.day, 20, 0),
        review: ApprovalStatus.pending,
      ));
    } else if (dayOfMonth == now.day - 4 || date == fourDaysAgo) {
      records.add(AttendanceRecord(
        id: 'ATT-${date.day}',
        studentId: sid,
        date: date,
        status: AttendanceStatus.late,
        hours: 2.5,
        verifiedHours: 2.5,
        location: mockStudentLocation(sid),
        checkIn: DateTime(date.year, date.month, date.day, 17, 35),
        checkOut: DateTime(date.year, date.month, date.day, 20, 0),
        exception: 'Late arrival due to class practicals',
        review: ApprovalStatus.approved,
      ));
    } else if (date == sixDaysAgo) {
      records.add(AttendanceRecord(
        id: 'ATT-${date.day}',
        studentId: sid,
        date: date,
        status: AttendanceStatus.absent,
        hours: 0,
        verifiedHours: 0,
        location: mockStudentLocation(sid),
        review: ApprovalStatus.approved,
      ));
    } else {
      records.add(AttendanceRecord(
        id: 'ATT-${date.day}',
        studentId: sid,
        date: date,
        status: AttendanceStatus.present,
        hours: 3.0,
        verifiedHours: 3.0,
        location: mockStudentLocation(sid),
        checkIn: DateTime(date.year, date.month, date.day, 17, 0),
        checkOut: DateTime(date.year, date.month, date.day, 20, 0),
        review: ApprovalStatus.approved,
      ));
    }
  }
  return records;
}

final List<AttendanceRecord> mockAttendance = mockMonthAttendance(mockNow);

/// Helper to get today's attendance record.
AttendanceRecord? mockTodayRecord([String? studentId]) {
  final now = DateTime.now();
  for (final r in mockAttendance) {
    if (r.date.year == now.year &&
        r.date.month == now.month &&
        r.date.day == now.day) {
      if (studentId == null || r.studentId == studentId) {
        return r;
      }
    }
  }
  return null;
}

/// Computes verified hours accumulated this month towards the 40-hour ceiling.
double get mockTotalVerifiedHoursMonth => mockAttendance.fold<double>(
      0,
      (sum, r) => sum + r.verifiedHours,
    );

/// Total present days this month.
int get mockTotalPresentDaysMonth =>
    mockAttendance.where((r) => r.status == AttendanceStatus.present).length;

/// Helper to get attendance for a specific student. Records are attributed to
/// the requested student (never silently the default demo student).
List<AttendanceRecord> mockStudentAttendance(String studentId, [DateTime? now]) {
  return mockMonthAttendance(now ?? mockNow, studentId: studentId);
}

/// Helper to compute verified hours for a list of records.
double mockVerifiedHoursFor(List<AttendanceRecord> records, [DateTime? month]) {
  return records.fold<double>(0, (sum, r) => sum + r.verifiedHours);
}

// -----------------------------------------------------------------------------
// Supervisor Verification Queue
//
// Student names and workplaces are resolved from the roster by `STU-###` id so
// this queue tracks the allotment sheet instead of duplicating it. Re-import
// the sheet and every row here follows automatically.
// -----------------------------------------------------------------------------
List<VerificationItem> get mockVerificationItems => [
      VerificationItem(
        id: 'V-101',
        studentName: mockStudentName('STU-052'),
        studentId: 'STU-052',
        location: mockStudentLocation('STU-052'),
        type: VerificationType.checkOut,
        submittedAt: mockNow.subtract(const Duration(minutes: 20)),
        evidenceTime: mockNow.subtract(const Duration(minutes: 22)),
        status: ApprovalStatus.pending,
        summary: 'Check-out at 8:02 PM • Desk logs verified',
      ),
      VerificationItem(
        id: 'V-102',
        studentName: mockStudentName('STU-003'),
        studentId: 'STU-003',
        location: mockStudentLocation('STU-003'),
        type: VerificationType.attendanceAudit,
        submittedAt: mockNow.subtract(const Duration(hours: 1, minutes: 15)),
        status: ApprovalStatus.pending,
        summary: 'Monthly register audit review',
      ),
      VerificationItem(
        id: 'V-103',
        studentName: mockStudentName('STU-001'),
        studentId: 'STU-001',
        location: mockStudentLocation('STU-001'),
        type: VerificationType.checkIn,
        submittedAt: mockNow.subtract(const Duration(hours: 2, minutes: 10)),
        evidenceTime: mockNow.subtract(const Duration(hours: 2, minutes: 12)),
        status: ApprovalStatus.pending,
        summary: 'Check-in at 6:00 PM • Zone selfie submitted',
      ),
      VerificationItem(
        id: 'V-104',
        studentName: mockStudentName('STU-004'),
        studentId: 'STU-004',
        location: mockStudentLocation('STU-004'),
        type: VerificationType.checkOut,
        submittedAt: mockNow.subtract(const Duration(hours: 3, minutes: 30)),
        status: ApprovalStatus.flagged,
        summary: 'Check-out timestamp discrepancy (+18m)',
      ),
      VerificationItem(
        id: 'V-105',
        studentName: mockStudentName('STU-001'),
        studentId: 'STU-001',
        location: mockStudentLocation('STU-001'),
        type: VerificationType.attendanceAudit,
        submittedAt: mockNow.subtract(const Duration(hours: 6)),
        status: ApprovalStatus.approved,
        summary: 'Weekly attendance review approved',
      ),
    ];

List<VerificationItem> get mockOpenVerifications =>
    mockVerificationItems.where((v) => v.status != ApprovalStatus.approved).toList();

// -----------------------------------------------------------------------------
// Supervisor Dynamic Audit Log
//
// The acting supervisor is resolved from the roster by `SV-##` id — the audit
// trail must name a real accountable person, never a literal in this file.
// -----------------------------------------------------------------------------
String mockSupervisorName(String supervisorId) {
  for (final s in mockSupervisors) {
    if (s.id == supervisorId) return s.name;
  }
  return 'Not assigned';
}

List<AuditLogEntry> get mockAuditLog => [
      AuditLogEntry(
        id: 'A-101',
        action: AuditAction.attendanceApproved,
        targetType: 'attendance',
        targetId: 'ATT-TODAY',
        actorName: mockSupervisorName('SV-01'),
        createdAt: mockNow.subtract(const Duration(hours: 2)),
        note: 'Duty at ${mockStudentLocation(mockCurrentStudent.id)} verified',
      ),
      AuditLogEntry(
        id: 'A-102',
        action: AuditAction.attendanceFlagged,
        targetType: 'attendance',
        targetId: 'ATT-16',
        actorName: mockSupervisorName('SV-01'),
        createdAt: mockNow.subtract(const Duration(days: 2)),
        note: 'Outside assigned work zone during check-out',
      ),
    ];

// -----------------------------------------------------------------------------
// Admin Domain: Institutional Payroll Records (Not visible to Students)
// -----------------------------------------------------------------------------
final PayrollRecord mockCurrentPayroll = PayrollRecord(
  month: DateTime(mockNow.year, mockNow.month),
  studentCount: mockStudents.length,
  presentDays: 21,
  paidHolidays: 1,
  ratePerDay: 150,
  estimatedPayable: 224400,
  status: PaymentStatus.inProgress,
);

/// Payment rows resolve student names from the roster by `STU-###` id, so the
/// payroll register follows the allotment sheet rather than duplicating it.
List<PaymentRecord> get mockPaymentRecords => [
      PaymentRecord(
        id: 'PAY-001',
        month: DateTime(mockNow.year, mockNow.month),
        studentId: 'STU-001',
        studentName: mockStudentName('STU-001'),
        verifiedHours: 32.0,
        eligibleDays: 21,
        paidHolidays: 1,
        ratePerDay: 150,
        calculatedAmount: 3300,
        status: PaymentStatus.inProgress,
      ),
      PaymentRecord(
        id: 'PAY-002',
        month: DateTime(mockNow.year, mockNow.month),
        studentId: 'STU-002',
        studentName: mockStudentName('STU-002'),
        verifiedHours: 30.0,
        eligibleDays: 20,
        paidHolidays: 1,
        ratePerDay: 150,
        calculatedAmount: 3150,
        status: PaymentStatus.inProgress,
      ),
      PaymentRecord(
        id: 'PAY-003',
        month: DateTime(mockNow.year, mockNow.month),
        studentId: 'STU-003',
        studentName: mockStudentName('STU-003'),
        verifiedHours: 36.0,
        eligibleDays: 22,
        paidHolidays: 1,
        ratePerDay: 150,
        calculatedAmount: 3450,
        status: PaymentStatus.approved,
      ),
    ];