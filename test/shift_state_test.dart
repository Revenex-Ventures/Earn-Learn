import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/domain/domain.dart';
import 'package:earn_and_learn/shared/components/today_panel.dart';

const _window = ShiftWindow(start: Duration(hours: 18), end: Duration(hours: 20));
final _midShift = DateTime(2026, 9, 18, 19, 0);
final _beforeShift = DateTime(2026, 9, 18, 17, 30);
final _afterShift = DateTime(2026, 9, 18, 20, 45);

AttendanceRecord _record({
  AttendanceStatus status = AttendanceStatus.present,
  DateTime? checkIn,
  DateTime? checkOut,
  double hours = 2.0,
  ApprovalStatus review = ApprovalStatus.pending,
}) {
  return AttendanceRecord(
    id: 'ATT-TEST',
    date: DateTime(2026, 9, 18),
    status: status,
    hours: hours,
    review: review,
    location: 'Gymkhana',
    checkIn: checkIn,
    checkOut: checkOut,
  );
}

void main() {
  group('deriveShiftState', () {
    test('off day wins over everything', () {
      expect(
        deriveShiftState(
          now: _beforeShift,
          windows: const [_window],
          isOffDay: true,
        ),
        ShiftState.offDay,
      );
    });

    test('sanctioned leave is treated as off day', () {
      expect(
        deriveShiftState(
          now: _midShift,
          windows: const [_window],
          today: _record(status: AttendanceStatus.leave),
        ),
        ShiftState.leave,
      );
    });

    test('no record before shift start is upcoming', () {
      expect(
        deriveShiftState(now: _beforeShift, windows: const [_window]),
        ShiftState.upcoming,
      );
    });

    test('no record after shift end is missed', () {
      expect(
        deriveShiftState(now: _afterShift, windows: const [_window]),
        ShiftState.missed,
      );
    });

    test('checked in during shift is working', () {
      expect(
        deriveShiftState(
          now: _midShift,
          windows: const [_window],
          today: _record(checkIn: DateTime(2026, 9, 18, 18, 2)),
        ),
        ShiftState.working,
      );
    });

    test('checked in and out is completed', () {
      expect(
        deriveShiftState(
          now: _afterShift,
          windows: const [_window],
          today: _record(
            checkIn: DateTime(2026, 9, 18, 18, 0),
            checkOut: DateTime(2026, 9, 18, 20, 0),
          ),
        ),
        ShiftState.completed,
      );
    });

    test('flagged approval surfaces as flagged', () {
      expect(
        deriveShiftState(
          now: _midShift,
          windows: const [_window],
          today: _record(checkIn: DateTime(2026, 9, 18, 18, 2)),
          approval: ApprovalStatus.flagged,
        ),
        ShiftState.flagged,
      );
    });
  });

  group('todayPanelCopy narration', () {
    test('upcoming announces start', () {
      final copy = todayPanelCopy(
        state: ShiftState.upcoming,
        now: _beforeShift,
        windows: const [_window],
      );
      expect(copy.headline, contains('Starts in'));
      expect(copy.actionLabel, "I'm ready for shift");
    });

    test('working announces elapsed time', () {
      final copy = todayPanelCopy(
        state: ShiftState.working,
        now: _midShift,
        windows: const [_window],
        today: _record(checkIn: DateTime(2026, 9, 18, 18, 2)),
      );
      expect(copy.headline, contains('Working'));
      expect(copy.actionLabel, 'Check out');
    });

    test('completed approved reads verified', () {
      final copy = todayPanelCopy(
        state: ShiftState.completed,
        now: _afterShift,
        windows: const [_window],
        today: _record(
          checkIn: DateTime(2026, 9, 18, 18, 0),
          checkOut: DateTime(2026, 9, 18, 20, 0),
        ),
        approval: ApprovalStatus.approved,
      );
      expect(copy.headline, contains('Verified'));
    });

    test('missed provides a recovery action', () {
      final copy = todayPanelCopy(
        state: ShiftState.missed,
        now: _afterShift,
        windows: const [_window],
      );
      expect(copy.headline, contains('Missed'));
      expect(copy.actionLabel, 'Request make-up');
    });
  });
}