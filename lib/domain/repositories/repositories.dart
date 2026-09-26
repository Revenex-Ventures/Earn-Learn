import '../../core/models/models.dart';
import '../identity/account_link.dart';

/// Source for the signed-in account and its directory link.
///
/// The account repository is read-only at the client: role and status changes
/// are server-side only.
abstract class AccountRepository {
  Future<UserProfile?> currentUser();
  Future<AccountLink?> currentAccountLink();
}

/// Directory and profile store of students.
abstract class StudentRepository {
  Future<Student?> byId(String id);
  Future<Student?> byUid(String uid);
  Future<List<Student>> all();
  Future<void> updateProfile(Student student);
}

/// Read-only directory of supervisors.
abstract class SupervisorRepository {
  Future<Supervisor?> byId(String id);
  Future<Supervisor?> byUid(String uid);
  Future<List<Supervisor>> all();
}

/// Read-only directory of work locations.
abstract class LocationRepository {
  Future<Location?> byId(String id);
  Future<List<Location>> all();
}

/// Assignments are institutional records: read-only for students, managed
/// exclusively by admins through the management flow.
abstract class AssignmentRepository {
  Future<Assignment?> byId(String id);
  Future<Assignment?> forStudent(String studentId);
  Future<List<Assignment>> all();
}

/// Attendance records and duty-session query repository.
///
/// Write operations (check-in, check-out, supervisor review) are handled
/// exclusively through the application service / [AttendanceGateway] path.
abstract class AttendanceRepository {
  Future<AttendanceRecord?> recordForDay({
    required String studentId,
    required DateTime day,
  });

  Future<List<AttendanceRecord>> recordsForMonth({
    required String studentId,
    required DateTime month,
  });
}

/// Institutional holiday calendar and approved leave.
abstract class CalendarRepository {
  Future<List<CalendarEvent>> eventsForMonth(DateTime month);
  Future<List<LeaveRequest>> leavesFor({
    required String studentId,
    required DateTime month,
  });
}

/// Supervisor verification queue.
abstract class VerificationRepository {
  Future<List<VerificationItem>> items({ApprovalStatus? status});
  Future<int> openCount();
}

/// Admin-side payroll rollup.
abstract class PayrollRepository {
  Future<PayrollRecord?> currentMonth();
  Future<List<PaymentRecord>> recordsForMonth(DateTime month);
}

/// Append-only audit trail.
abstract class AuditRepository {
  Future<List<AuditLogEntry>> recent({int limit = 50});
  Future<void> add(AuditLogEntry entry);
}

/// Leave requests for a student.
abstract class LeaveRepository {
  Future<List<LeaveRequest>> forStudent({
    required String studentId,
    required DateTime month,
  });

  Future<void> submit(LeaveRequest request);

  Future<void> review({
    required String requestId,
    required LeaveStatus decision,
    required String reviewedBy,
  });
}