import '../../core/models/models.dart';
import '../../domain/payroll/payroll_service.dart';
import '../../domain/policy/policy_config.dart';
import '../../domain/repositories/repositories.dart';
import '../dev_only.dart';
import 'payroll_store.dart';

/// Payroll rollup COMPUTED from real attendance (no fixtures).
///
/// Delegates to [PayrollService], which counts each student's approved duty
/// days for the month and applies the admin-configured per-day rate from
/// [PayrollStore]. The rollup reflects live check-outs and supervisor
/// approvals; the batch's approved/in-progress state comes from the persisted
/// approval record.
@DevOnly('Computed payroll rollup derived from attendance + configured rate.')
class LocalPayrollRepository implements PayrollRepository {
  const LocalPayrollRepository({
    required this.students,
    required this.assignments,
    required this.attendance,
    required this.calendar,
  });

  final StudentRepository students;
  final AssignmentRepository assignments;
  final AttendanceRepository attendance;
  final CalendarRepository calendar;

  @override
  Future<PayrollRecord?> currentMonth() async {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final result = await _computeMonth(month);
    return result?.rollup;
  }

  @override
  Future<List<PaymentRecord>> recordsForMonth(DateTime month) async {
    final result = await _computeMonth(month);
    return result?.records ?? const [];
  }

  Future<ComputedPayroll?> _computeMonth(DateTime month) async {
    final store = PayrollStore.instance;
    final service = PayrollService();
    return service.computeMonth(
      month: month,
      students: students,
      assignments: assignments,
      attendance: attendance,
      calendar: calendar,
      policy: PolicyConfig(
        defaultRatePerDay: store.effectiveRatePerDay,
        locationRateTiers: store.locationRates.isEmpty ? null : store.locationRates,
      ),
    );
  }
}
