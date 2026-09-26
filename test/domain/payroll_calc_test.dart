import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/domain/domain.dart';

void main() {
  group('payroll math', () {
    const policy = PolicyConfig(
      monthlyMaxHours: 40,
      defaultRatePerDay: 200,
      paidHolidayRule: PaidHolidayRule.countedAsEligibleDay,
    );

    List<AttendanceRecord> records() => [
          AttendanceRecord(
            id: 'A1',
            studentId: 'STU-P1',
            date: DateTime(2026, 6, 1),
            status: AttendanceStatus.present,
            hours: 3,
            review: ApprovalStatus.approved,
          ),
          AttendanceRecord(
            id: 'A2',
            studentId: 'STU-P1',
            date: DateTime(2026, 6, 2),
            status: AttendanceStatus.late,
            hours: 2.5,
            review: ApprovalStatus.approved,
          ),
          AttendanceRecord(
            id: 'A3',
            studentId: 'STU-P1',
            date: DateTime(2026, 6, 3),
            status: AttendanceStatus.present,
            hours: 3,
            review: ApprovalStatus.pending,
          ),
          AttendanceRecord(
            id: 'A4',
            studentId: 'STU-P1',
            date: DateTime(2026, 6, 4),
            status: AttendanceStatus.absent,
            hours: 0,
            review: ApprovalStatus.approved,
          ),
          AttendanceRecord(
            id: 'A5',
            studentId: 'STU-P1',
            date: DateTime(2026, 6, 5),
            status: AttendanceStatus.leave,
            hours: 0,
            review: ApprovalStatus.approved,
          ),
        ];

    test('eligible days count approved present/late only', () {
      expect(eligibleDaysFrom(records()), 2);
    });

    test('stipend follows the confirmed rate and paid-holiday rule', () {
      final payment = calculateStipend(
        studentId: 'STU-P1',
        records: records(),
        paidHolidays: 1,
        policy: policy,
      );
      expect(payment.eligibleDays, 2);
      expect(payment.amount, (2 + 1) * 200);
    });

    test('separate compensation leaves paid holidays out of the amount', () {
      final separate = PolicyConfig(
        monthlyMaxHours: 40,
        defaultRatePerDay: 200,
        paidHolidayRule: PaidHolidayRule.countedSeparately,
      );
      final payment = calculateStipend(
        studentId: 'STU-P1',
        records: records(),
        paidHolidays: 1,
        policy: separate,
      );
      expect(payment.amount, 2 * 200);
    });

    test('a location tier overrides the default rate', () {
      final tiered = PolicyConfig(
        monthlyMaxHours: 40,
        defaultRatePerDay: 200,
        locationRateTiers: {'LOC-08': 250},
      );
      final payment = calculateStipend(
        studentId: 'STU-P1',
        records: records(),
        paidHolidays: 0,
        policy: tiered,
        locationId: 'LOC-08',
      );
      expect(payment.amount, 2 * 250);
    });

    test('throws RateNotConfigured without a confirmed rate', () {
      expect(
        () => calculateStipend(
          studentId: 'STU-P1',
          records: records(),
          paidHolidays: 0,
          policy: const PolicyConfig(monthlyMaxHours: 40),
        ),
        throwsA(isA<RateNotConfigured>()),
      );
    });

    test('minimum attendance rule applies when configured', () {
      const lax = PolicyConfig(monthlyMaxHours: 40);
      const strict = PolicyConfig(
        monthlyMaxHours: 40,
        minimumAttendancePercent: 80,
      );
      expect(remainsStipendEligible(workedDays: 5, scheduledDays: 6, policy: lax), isTrue);
      expect(remainsStipendEligible(workedDays: 4, scheduledDays: 6, policy: strict), isFalse);
      expect(remainsStipendEligible(workedDays: 5, scheduledDays: 5, policy: strict), isTrue);
    });
  });

  group('payroll approval', () {
    const defaultPolicy = PolicyConfig(monthlyMaxHours: 40);
    const relaxed = PolicyConfig(monthlyMaxHours: 40, payrollApproverRequired: false);

    test('requires an approver', () {
      final decision = evaluatePayrollApproval(
        preparedBy: 'SV-01',
        approvedBy: null,
        policy: defaultPolicy,
      );
      expect(decision.allowed, isFalse);
      expect(decision.denialReason, contains('No approver'));
    });

    test('distinct approver rule applies by default', () {
      final decision = evaluatePayrollApproval(
        preparedBy: 'SV-01',
        approvedBy: 'SV-01',
        policy: defaultPolicy,
      );
      expect(decision.allowed, isFalse);
      expect(decision.denialReason, contains('differ'));
    });

    test('distinct approvers are allowed', () {
      final decision = evaluatePayrollApproval(
        preparedBy: 'SV-01',
        approvedBy: 'u-admin-001',
        policy: defaultPolicy,
      );
      expect(decision.allowed, isTrue);
    });

    test('relaxed policy permits the same preparer', () {
      final decision = evaluatePayrollApproval(
        preparedBy: 'SV-01',
        approvedBy: 'SV-01',
        policy: relaxed,
      );
      expect(decision.allowed, isTrue);
    });
  });
}