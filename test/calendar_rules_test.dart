import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/shared/mock_data/mock_data.dart';

void main() {
  group('Official programme calendar', () {
    test('every Sunday is seeded as a weekly off day', () {
      // A 31-day month guarantees 4 or 5 Sundays.
      for (final month in [DateTime(2026, 1), DateTime(2026, 8)]) {
        final events = mockMonthCalendar(month);
        final sundays = DateTime(month.year, month.month + 1, 0).day ~/ 7;
        final offs = events.where((e) => e.type == CalendarEventType.offDay);
        expect(offs.length, greaterThanOrEqualTo(4));
        expect(offs.length, lessThanOrEqualTo(sundays + 1));
        expect(offs.every((e) => e.date.weekday == DateTime.sunday), isTrue);
      }
    });

    test('each national holiday is seeded exactly once, in its own month', () {
      const expectations = {
        DateTime.january: ('Republic Day', 26),
        DateTime.august: ('Independence Day', 15),
        DateTime.october: ('Gandhi Jayanti', 2),
      };

      for (final entry in expectations.entries) {
        final month = DateTime(2026, entry.key);
        final holidays = mockMonthCalendar(month)
            .where((e) => e.type == CalendarEventType.holiday)
            .toList();

        expect(holidays, hasLength(1), reason: 'month ${entry.key}');
        expect(holidays.single.label, entry.value.$1);
        expect(holidays.single.date.day, entry.value.$2);
        expect(holidays.single.date.weekday, isNot(DateTime.sunday));
      }
    });

    test('no national holiday leaks into a month it does not fall in', () {
      const ownMonth = {
        'Republic Day': DateTime.january,
        'Independence Day': DateTime.august,
        'Gandhi Jayanti': DateTime.october,
      };

      for (var month = 1; month <= 12; month++) {
        final labels = mockMonthCalendar(DateTime(2026, month))
            .map((e) => e.label)
            .toSet();
        for (final entry in ownMonth.entries) {
          if (entry.value == month) continue;
          expect(labels, isNot(contains(entry.key)),
              reason: '${entry.key} leaked into month $month');
        }
      }
    });

    test('no fabricated institutional events are seeded', () {
      // 'State Holiday' (2nd weekday) and 'College Foundation Day' (the 24th,
      // marked paid) were invented demo dates. They must not return.
      const forbidden = {
        'State Holiday',
        'College Foundation Day',
        'Foundation Day',
        'Gandhi Jayanti Holiday',
      };

      for (var month = 1; month <= 12; month++) {
        final events = mockMonthCalendar(DateTime(2026, month));
        final labels = events.map((e) => e.label).toSet();
        expect(labels.intersection(forbidden), isEmpty, reason: 'month $month');
      }
    });

    test('no seeded event is marked as a paid festival', () {
      for (var month = 1; month <= 12; month++) {
        final paid = mockMonthCalendar(DateTime(2026, month))
            .where((e) => e.isPaid)
            .toList();
        expect(paid, isEmpty, reason: 'month $month');
      }
    });

    test('the 40 h ceiling is a policy value, never a calendar event', () {
      expect(mockAppPolicy.monthlyMaxHours, 40);
      for (final a in mockAssignments) {
        expect(a.maxMonthlyHours, 40);
      }
    });
  });
}
