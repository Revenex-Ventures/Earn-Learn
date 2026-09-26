import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/domain/domain.dart';

void main() {
  group('validateWindow / validateAssignmentWindows', () {
    test('accepts a normal within-day window', () {
      const window = ShiftWindow(
        start: Duration(hours: 17),
        end: Duration(hours: 20),
      );
      expect(validateWindow(window), isNull);
      expect(validateAssignmentWindows(const [window]), isEmpty);
    });

    test('rejects an inverted window', () {
      const window = ShiftWindow(
        start: Duration(hours: 20),
        end: Duration(hours: 17),
      );
      expect(validateWindow(window), isNotNull);
    });

    test('rejects an overnight window crossing midnight', () {
      const window = ShiftWindow(
        start: Duration(hours: 20),
        end: Duration(hours: 26),
      );
      expect(validateWindow(window), isNotNull);
    });

    test('flags overlapping windows', () {
      const windows = [
        ShiftWindow(start: Duration(hours: 9), end: Duration(hours: 12)),
        ShiftWindow(start: Duration(hours: 11), end: Duration(hours: 14)),
      ];
      final issues = validateAssignmentWindows(windows);
      expect(issues.any((i) => i.message.contains('Overlapping')), isTrue);
    });

    test('accepts a split shift without overlap', () {
      const windows = [
        ShiftWindow(start: Duration(hours: 9), end: Duration(hours: 11)),
        ShiftWindow(start: Duration(hours: 14), end: Duration(hours: 17)),
      ];
      expect(validateAssignmentWindows(windows), isEmpty);
    });
  });

  group('monthlyPlannedHours', () {
    final daily3h = Assignment(
      id: 'ASN-P1',
      studentId: 'STU-P1',
      locationId: 'LOC-P',
      supervisorId: 'SV-P',
      workDescription: 'Planned duty',
shiftWindows: const [
      ShiftWindow(start: Duration(hours: 17), end: Duration(hours: 20)),
    ],
    effectiveFrom: DateTime(2024, 1, 1),
    status: AssignmentStatus.active,
  );

    test('sums windows across the month without recurrence', () {
      // January 2024 has 31 days; every day is a candidate.
      expect(monthlyPlannedHours(assignment: daily3h, month: DateTime(2024, 1)),
          31 * 3.0);
    });

    test('honours a Mon-Fri weekly recurrence', () {
      // January 2024 = 23 weekdays (Mon-Fri).
      const recurrence = WeeklyRecurrence({1, 2, 3, 4, 5});
      expect(
        monthlyPlannedHours(
          assignment: daily3h,
          month: DateTime(2024, 1),
          recurrence: recurrence,
        ),
        23 * 3.0,
      );
    });

    test('an unconfigured recurrence disables itself', () {
      const recurrence = WeeklyRecurrence({});
      expect(
        monthlyPlannedHours(
          assignment: daily3h,
          month: DateTime(2024, 1),
          recurrence: recurrence,
        ),
        31 * 3.0,
      );
    });
  });

  group('late / early evaluation', () {
    const window = ShiftWindow(
      start: Duration(hours: 17),
      end: Duration(hours: 20),
    );
    final day = DateTime(2026, 6, 1);

    test('flags a late check-in beyond the grace', () {
      final result = evaluateLateCheckIn(
        window: window,
        checkInVerifiedAt: DateTime(2026, 6, 1, 17, 10),
        day: day,
      );
      expect(result.isLate, isTrue);
      expect(result.delay, const Duration(minutes: 10));
    });

    test('grace absorbs small delays', () {
      final result = evaluateLateCheckIn(
        window: window,
        checkInVerifiedAt: DateTime(2026, 6, 1, 17, 10),
        day: day,
        grace: const Duration(minutes: 15),
      );
      expect(result.isLate, isFalse);
    });

    test('flags an early check-out', () {
      final result = evaluateEarlyCheckOut(
        window: window,
        checkOutVerifiedAt: DateTime(2026, 6, 1, 19, 45),
        day: day,
      );
      expect(result.isEarly, isTrue);
      expect(result.shortfall, const Duration(minutes: 15));
    });
  });

  group('checkInEligibility', () {
    const windows = [
      ShiftWindow(start: Duration(hours: 17), end: Duration(hours: 20)),
    ];
    final day = DateTime(2026, 6, 1, 17, 30);

    ScheduledDay workDay() => const ScheduledDay(
          kind: ScheduledDayKind.workDay,
          isPaid: false,
          windows: windows,
        );

    test('allows check-in inside a work window', () {
      final result = checkInEligibility(
        day: workDay(),
        requestedAt: day,
        windows: windows,
      );
      expect(result.isAllowed, isTrue);
    });

    test('denies check-in ahead of the pre-window grace', () {
      final result = checkInEligibility(
        day: workDay(),
        requestedAt: DateTime(2026, 6, 1, 7, 0),
        windows: windows,
      );
      expect(result.isAllowed, isFalse);
      expect(result.reason, contains('not open yet'));
    });

    test('denies check-in after the window has ended', () {
      final result = checkInEligibility(
        day: workDay(),
        requestedAt: DateTime(2026, 6, 1, 22, 0),
        windows: windows,
      );
      expect(result.isAllowed, isFalse);
      expect(result.reason, contains('ended'));
    });

    test('denies on an off day', () {
      const offDay = ScheduledDay(
        kind: ScheduledDayKind.offDay,
        isPaid: false,
        windows: [],
        source: 'calendar',
      );
      final result = checkInEligibility(day: offDay, requestedAt: day);
      expect(result.isAllowed, isFalse);
    });

    test('denies on approved leave', () {
      const leave = ScheduledDay(
        kind: ScheduledDayKind.leave,
        isPaid: false,
        windows: [],
        source: 'leave',
      );
      final result = checkInEligibility(day: leave, requestedAt: day);
      expect(result.isAllowed, isFalse);
    });
  });

  group('MonthlyCapacity', () {
    test('tracks remaining hours under the ceiling', () {
      const capacity = MonthlyCapacity(maxHours: 40, verifiedHours: 32);
      expect(capacity.remaining, 8);
      expect(capacity.isExhausted, isFalse);
    });

    test('clamps remaining to zero once exhausted', () {
      const capacity = MonthlyCapacity(maxHours: 40, verifiedHours: 45);
      expect(capacity.remaining, 0);
      expect(capacity.isExhausted, isTrue);
    });
  });
}