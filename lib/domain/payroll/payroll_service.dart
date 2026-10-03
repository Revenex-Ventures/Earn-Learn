import '../../core/models/models.dart';
import '../policy/policy_config.dart';
import 'payroll_calc.dart';
import '../repositories/repositories.dart';

/// Result of computing one month's payroll.
class ComputedPayroll {
  const ComputedPayroll({
    required this.rollup,
    required this.records,
  });

  final PayrollRecord rollup;
  final List<PaymentRecord> records;
}

/// Pure payroll computation service for the local build.
///
/// Takes repository data as input and returns computed payroll records.
/// No side effects, no persistence — easily unit-testable.
class PayrollService {
  const PayrollService();

  /// Computes the full payroll for a given month.
  Future<ComputedPayroll> computeMonth({
    required DateTime month,
    required StudentRepository students,
    required AssignmentRepository assignments,
    required AttendanceRepository attendance,
    required CalendarRepository calendar,
    required PolicyConfig policy,
  }) async {
    final allStudents = await students.all();
    final allAssignments = await assignments.all();
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    // Get calendar events for paid holidays
    final calendarEvents = await calendar.eventsForMonth(month);

    // Count paid holidays in this month
    final paidHolidays = calendarEvents
        .where((e) =>
            e.date.isAfter(monthStart.subtract(const Duration(days: 1))) &&
            e.date.isBefore(monthEnd.add(const Duration(days: 1))) &&
            e.type == CalendarEventType.holiday)
        .length;

    final records = <PaymentRecord>[];
    var totalEstimated = 0.0;

    for (final student in allStudents) {
      // Only include students with active assignments
      final assignment = allAssignments
          .where((a) => a.studentId == student.id && a.status == AssignmentStatus.active)
          .firstOrNull;
      if (assignment == null) continue;

      final monthlyAttendance = await attendance.recordsForMonth(
        studentId: student.id,
        month: month,
      );

      // Compute stipend using payroll_calc
      try {
        final payment = calculateStipend(
          studentId: student.id,
          records: monthlyAttendance,
          paidHolidays: paidHolidays,
          policy: policy,
          locationId: assignment.locationId,
        );

        final record = PaymentRecord(
          id: 'PAY-${student.id}-${month.year}${month.month.toString().padLeft(2, '0')}',
          month: monthStart,
          studentId: student.id,
          studentName: student.name,
          verifiedHours: monthlyAttendance.fold<double>(0, (sum, r) => sum + r.verifiedHours),
          eligibleDays: payment.eligibleDays,
          paidHolidays: payment.paidHolidays,
          ratePerDay: payment.ratePerDay,
          calculatedAmount: payment.amount,
          status: PaymentStatus.inProgress,
        );

        records.add(record);
        totalEstimated += payment.amount;
      } on RateNotConfigured {
        // Skip students if rate not configured
        continue;
      }
    }

    // Build rollup
    final rollup = PayrollRecord(
      month: monthStart,
      studentCount: records.length,
      presentDays: records.fold<int>(0, (sum, r) => sum + r.eligibleDays),
      paidHolidays: paidHolidays,
      ratePerDay: policy.defaultRatePerDay ?? 100.0,
      estimatedPayable: totalEstimated,
      status: PaymentStatus.inProgress,
    );

    return ComputedPayroll(rollup: rollup, records: records);
  }
}