import '../../core/models/models.dart';

/// How a paid holiday contributes to the monthly stipend.
enum PaidHolidayRule {
  countedAsEligibleDay,
  countedSeparately;

  String get label => switch (this) {
        PaidHolidayRule.countedAsEligibleDay =>
          'Paid holiday counts as an eligible day',
        PaidHolidayRule.countedSeparately =>
          'Paid holiday is compensated separately',
      };
}

/// The institutionally-confirmed and still-unresolved policy surface.
///
/// Stage 1B ships the *contract* for policy that the college must confirm
/// (see docs/POLICY_CONFIG.md). Values confirmed from the source workbook are
/// filled in; unanswered fields stay `null` and MUST NOT be fabricated.
class PolicyConfig {
  const PolicyConfig({
    this.monthlyMaxHours = 40,
    this.enforceHardCap,
    this.rollingWindow,
    this.defaultRatePerDay,
    this.locationRateTiers,
    this.lateGrace,
    this.earlyCheckoutGrace,
    this.minimumAttendancePercent,
    this.leaveNoticeDays,
    this.maxLeaveDaysPerMonth,
    this.weeklyWorkingDays,
    this.overnightShiftsAllowed,
    this.paidHolidayRule,
    this.payrollApproverRequired,
    this.evidenceRetentionDays,
  });

  /// Monthly hour ceiling. Confirmed as 40 from the college workbook and
  /// mirrored by `AppPolicy.monthlyMaxHours` and `Assignment.maxMonthlyHours`.
  final int monthlyMaxHours;

  /// Whether the ceiling is a hard stop or a soft flag. Unresolved.
  final bool? enforceHardCap;

  /// Whether the ceiling is per calendar month or a rolling 30-day window.
  /// Unresolved.
  final bool? rollingWindow;

  /// Default per-day rate. Unresolved — must not be fabricated.
  final double? defaultRatePerDay;

  /// Per-location day rates, keyed by location id. Unresolved — must not be
  /// fabricated.
  final Map<String, double>? locationRateTiers;

  /// Grace for late check-in. Unresolved.
  final Duration? lateGrace;

  /// Grace for early check-out. Unresolved.
  final Duration? earlyCheckoutGrace;

  /// Minimum attendance to stay stipend-eligible. Unresolved.
  final double? minimumAttendancePercent;

  /// Advance notice required for leave requests. Unresolved.
  final int? leaveNoticeDays;

  /// Maximum leave days per month. Unresolved.
  final int? maxLeaveDaysPerMonth;

  /// Fixed weekly working days (1=Mon .. 7=Sun). Null means the recurrence
  /// rule is not yet applied.
  final Set<int>? weeklyWorkingDays;

  /// Whether overnight (window past midnight) shifts are permitted. Unresolved.
  final bool? overnightShiftsAllowed;

  /// How paid holidays are compensated. Unresolved.
  final PaidHolidayRule? paidHolidayRule;

  /// Whether payroll approval requires a second, distinct approver. Unresolved.
  final bool? payrollApproverRequired;

  /// Retention period for offline-evidence artifacts. Unresolved.
  final int? evidenceRetentionDays;

  /// Field names the college has confirmed from the workbook.
  List<String> get confirmedFields => const ['monthlyMaxHours'];

  /// Field names still pending the college's confirmation.
  List<String> get unresolvedFields => [
        if (enforceHardCap == null) 'enforceHardCap',
        if (rollingWindow == null) 'rollingWindow',
        if (defaultRatePerDay == null) 'defaultRatePerDay',
        if (locationRateTiers == null) 'locationRateTiers',
        if (lateGrace == null) 'lateGrace',
        if (earlyCheckoutGrace == null) 'earlyCheckoutGrace',
        if (minimumAttendancePercent == null) 'minimumAttendancePercent',
        if (leaveNoticeDays == null) 'leaveNoticeDays',
        if (maxLeaveDaysPerMonth == null) 'maxLeaveDaysPerMonth',
        if (weeklyWorkingDays == null) 'weeklyWorkingDays',
        if (overnightShiftsAllowed == null) 'overnightShiftsAllowed',
        if (paidHolidayRule == null) 'paidHolidayRule',
        if (payrollApproverRequired == null) 'payrollApproverRequired',
        if (evidenceRetentionDays == null) 'evidenceRetentionDays',
      ];

  bool get isFullyResolved => unresolvedFields.isEmpty;

  /// Builds the validated surface from the server-side policy object.
  factory PolicyConfig.fromAppPolicy(AppPolicy policy) => PolicyConfig(
        monthlyMaxHours: policy.monthlyMaxHours,
        defaultRatePerDay: policy.defaultRatePerDay,
      );

  @override
  bool operator ==(Object other) =>
      other is PolicyConfig &&
      other.monthlyMaxHours == monthlyMaxHours &&
      other.enforceHardCap == enforceHardCap &&
      other.rollingWindow == rollingWindow &&
      other.defaultRatePerDay == defaultRatePerDay &&
      other.locationRateTiers == locationRateTiers &&
      other.lateGrace == lateGrace &&
      other.earlyCheckoutGrace == earlyCheckoutGrace &&
      other.minimumAttendancePercent == minimumAttendancePercent &&
      other.leaveNoticeDays == leaveNoticeDays &&
      other.maxLeaveDaysPerMonth == maxLeaveDaysPerMonth &&
      other.weeklyWorkingDays == weeklyWorkingDays &&
      other.overnightShiftsAllowed == overnightShiftsAllowed &&
      other.paidHolidayRule == paidHolidayRule &&
      other.payrollApproverRequired == payrollApproverRequired &&
      other.evidenceRetentionDays == evidenceRetentionDays;

  @override
  int get hashCode => Object.hash(
        monthlyMaxHours,
        enforceHardCap,
        rollingWindow,
        defaultRatePerDay,
        locationRateTiers,
        lateGrace,
        earlyCheckoutGrace,
        minimumAttendancePercent,
        leaveNoticeDays,
        maxLeaveDaysPerMonth,
        weeklyWorkingDays,
        overnightShiftsAllowed,
        paidHolidayRule,
        payrollApproverRequired,
        evidenceRetentionDays,
      );
}