import '../../core/models/models.dart';
import '../policy/policy_config.dart';

/// Raised when a stipend amount cannot be computed because the per-day rate
/// has not been confirmed by the college.
class RateNotConfigured implements Exception {
  const RateNotConfigured();

  @override
  String toString() =>
      'Rate not configured: the college has not confirmed the per-day rate yet.';
}

/// Result of computing one month's stipend for a student.
class MonthlyPayment {
  const MonthlyPayment({
    required this.studentId,
    required this.eligibleDays,
    required this.paidHolidays,
    required this.ratePerDay,
    required this.amount,
  });

  final String studentId;
  final int eligibleDays;
  final int paidHolidays;
  final double ratePerDay;
  final double amount;
}

/// Counts days eligible for the stipend from a month's attendance.
///
/// Present and late days count when their review is approved; absent, leave
/// and unreviewed days do not. Paid holidays are counted separately so the
/// college's chosen [PaidHolidayRule] can be applied on top.
int eligibleDaysFrom(List<AttendanceRecord> records) {
  return records.where((r) {
    if (r.review != ApprovalStatus.approved) return false;
    return r.status == AttendanceStatus.present ||
        r.status == AttendanceStatus.late;
  }).length;
}

/// Computes the monthly stipend for a student.
///
/// The per-day rate MUST come from confirmed [PolicyConfig]. The legacy ₹150
/// fixture value is never used here.
MonthlyPayment calculateStipend({
  required String studentId,
  required List<AttendanceRecord> records,
  required int paidHolidays,
  required PolicyConfig policy,
  String? locationId,
}) {
  double? rate = policy.defaultRatePerDay;
  final tiers = policy.locationRateTiers;
  if (locationId != null && tiers != null && tiers.containsKey(locationId)) {
    rate = tiers[locationId];
  }
  if (rate == null) throw const RateNotConfigured();

  final eligible = eligibleDaysFrom(records);
  final days = policy.paidHolidayRule == PaidHolidayRule.countedSeparately
      ? eligible
      : eligible + paidHolidays;

  return MonthlyPayment(
    studentId: studentId,
    eligibleDays: eligible,
    paidHolidays: paidHolidays,
    ratePerDay: rate,
    amount: days * rate,
  );
}

/// Asserts a student stays stipend-eligible under the optional minimum
/// attendance rule. Returns true when the rule is not configured yet.
bool remainsStipendEligible({
  required int workedDays,
  required int scheduledDays,
  required PolicyConfig policy,
}) {
  final minimum = policy.minimumAttendancePercent;
  if (minimum == null) return true;
  if (scheduledDays <= 0) return true;
  return (workedDays / scheduledDays) * 100 >= minimum;
}

/// Outcome of evaluating a payroll approval transaction.
class PayrollApprovalDecision {
  const PayrollApprovalDecision({
    required this.allowed,
    this.denialReason,
  });

  final bool allowed;
  final String? denialReason;
}

/// Two-person rule for approving a payroll run.
///
/// The college has not confirmed whether a second, distinct approver is
/// mandatory, so the stricter default (distinct approver required) applies.
PayrollApprovalDecision evaluatePayrollApproval({
  required String? preparedBy,
  required String? approvedBy,
  required PolicyConfig policy,
}) {
  if (approvedBy == null || approvedBy.isEmpty) {
    return const PayrollApprovalDecision(
      allowed: false,
      denialReason: 'No approver recorded.',
    );
  }
  if ((policy.payrollApproverRequired ?? true) && preparedBy == approvedBy) {
    return const PayrollApprovalDecision(
      allowed: false,
      denialReason: 'Approver must differ from the preparer.',
    );
  }
  return const PayrollApprovalDecision(allowed: true);
}