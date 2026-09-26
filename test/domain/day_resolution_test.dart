import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/domain/domain.dart';

void main() {
  final assignment = Assignment(
    id: 'ASN-D1',
    studentId: 'STU-D1',
    locationId: 'LOC-D',
    supervisorId: 'SV-D',
    workDescription: 'Daily duty',
    shiftWindows: const [
      ShiftWindow(start: Duration(hours: 17), end: Duration(hours: 20)),
    ],
    effectiveFrom: DateTime(2026, 1, 1),
    status: AssignmentStatus.active,
  );

  final monday = DateTime(2026, 6, 1); // a Monday

  group('resolveDay', () {
    test('resolves a work day from assignment windows', () {
      final day = resolveDay(day: monday, assignment: assignment);
      expect(day.kind, ScheduledDayKind.workDay);
      expect(day.windows, hasLength(1));
      expect(day.source, 'assignment');
    });

    test('calendar holiday takes precedence and is unpaid', () {
      final day = resolveDay(
        day: monday,
        assignment: assignment,
        events: [
          CalendarEvent(
            date: monday,
            label: 'State Holiday',
            type: CalendarEventType.holiday,
          ),
        ],
      );
      expect(day.kind, ScheduledDayKind.holiday);
      expect(day.isPaid, isFalse);
      expect(day.source, 'calendar');
    });

    test('paid festival resolves as a paid holiday', () {
      final day = resolveDay(
        day: monday,
        assignment: assignment,
        events: [
          CalendarEvent(
            date: monday,
            label: 'College Foundation Day',
            type: CalendarEventType.festival,
            isPaid: true,
          ),
        ],
      );
      expect(day.kind, ScheduledDayKind.paidHoliday);
      expect(day.isPaid, isTrue);
    });

    test('approved leave beats the assignment windows', () {
      final day = resolveDay(
        day: monday,
        assignment: assignment,
        approvedLeaves: [
          LeaveRequest(
            id: 'LV-1',
            studentId: 'STU-D1',
            studentName: 'Test Student',
            date: monday,
            reason: 'Medical',
            status: LeaveStatus.approved,
            submittedAt: DateTime(2026, 5, 30),
          ),
        ],
      );
      expect(day.kind, ScheduledDayKind.leave);
      expect(day.source, 'leave');
    });

    test('rejected leave does not suspend the schedule', () {
      final day = resolveDay(
        day: monday,
        assignment: assignment,
        approvedLeaves: [
          LeaveRequest(
            id: 'LV-2',
            studentId: 'STU-D1',
            studentName: 'Test Student',
            date: monday,
            reason: 'Medical',
            status: LeaveStatus.rejected,
            submittedAt: DateTime(2026, 5, 30),
          ),
        ],
      );
      expect(day.kind, ScheduledDayKind.workDay);
    });

    test('weekly recurrence removes non-working weekdays', () {
      const recurrence = WeeklyRecurrence({1, 2, 3, 4, 5});
      // 2026-06-06 is a Saturday.
      final day = resolveDay(
        day: DateTime(2026, 6, 6),
        assignment: assignment,
        recurrence: recurrence,
      );
      expect(day.kind, ScheduledDayKind.unscheduled);
      expect(day.source, 'recurrence');
    });

    test('an unconfigured recurrence keeps every day', () {
      const recurrence = WeeklyRecurrence({});
      final day = resolveDay(
        day: monday,
        assignment: assignment,
        recurrence: recurrence,
      );
      expect(day.kind, ScheduledDayKind.workDay);
    });

    test('no windows and no rules resolves unscheduled', () {
      final empty = Assignment(
        id: 'ASN-D2',
        studentId: 'STU-D1',
        locationId: 'LOC-D',
        supervisorId: 'SV-D',
        workDescription: 'No windows',
shiftWindows: const [],
    effectiveFrom: DateTime(2026, 1, 1),
    status: AssignmentStatus.active,
  );
      final day = resolveDay(day: monday, assignment: empty);
      expect(day.kind, ScheduledDayKind.unscheduled);
      expect(day.source, 'assignment');
    });
  });
}