import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/domain/domain.dart';

const _window = ShiftWindow(start: Duration(hours: 17), end: Duration(hours: 20));
final _day = DateTime(2026, 9, 18);
final _midShift = DateTime(2026, 9, 18, 19, 0);
final _tenMinBefore = DateTime(2026, 9, 18, 16, 51);
final _fortyMinBefore = DateTime(2026, 9, 18, 16, 21);
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
    date: _day,
    status: status,
    hours: hours,
    review: review,
    location: 'Gymkhana',
    checkIn: checkIn,
    checkOut: checkOut,
  );
}

void main() {
  group('deriveShiftState (canonical attendance projection)', () {
    test('off day wins over everything', () {
      expect(
        deriveShiftState(
          now: _midShift,
          windows: const [_window],
          isOffDay: true,
        ),
        ShiftState.offDay,
      );
    });

    test('sanctioned leave is treated as leave', () {
      expect(
        deriveShiftState(
          now: _midShift,
          windows: const [_window],
          today: _record(status: AttendanceStatus.leave),
        ),
        ShiftState.leave,
      );
    });

    test('flagged surfaces even after a recorded checkout', () {
      expect(
        deriveShiftState(
          now: _afterShift,
          windows: const [_window],
          today: _record(
            checkIn: DateTime(2026, 9, 18, 17, 0),
            checkOut: DateTime(2026, 9, 18, 20, 0),
          ),
          approval: ApprovalStatus.flagged,
        ),
        ShiftState.flagged,
      );
    });

    test('no record before the shift is upcoming', () {
      expect(
        deriveShiftState(now: _fortyMinBefore, windows: const [_window]),
        ShiftState.upcoming,
      );
    });

    test('within 15 minutes of start is ready', () {
      expect(
        deriveShiftState(now: _tenMinBefore, windows: const [_window]),
        ShiftState.ready,
      );
    });

    test('no record after the shift ends is missed', () {
      expect(
        deriveShiftState(now: _afterShift, windows: const [_window]),
        ShiftState.missed,
      );
    });

    test('checked in during the shift is working', () {
      expect(
        deriveShiftState(
          now: _midShift,
          windows: const [_window],
          today: _record(checkIn: DateTime(2026, 9, 18, 18, 2)),
        ),
        ShiftState.working,
      );
    });

    test('checked out but unapproved is pending verification', () {
      expect(
        deriveShiftState(
          now: _afterShift,
          windows: const [_window],
          today: _record(
            status: AttendanceStatus.pending,
            checkIn: DateTime(2026, 9, 18, 17, 5),
            checkOut: DateTime(2026, 9, 18, 20, 0),
            review: ApprovalStatus.pending,
          ),
        ),
        ShiftState.pendingVerification,
      );
    });

    test('checked out and approved is completed', () {
      expect(
        deriveShiftState(
          now: _afterShift,
          windows: const [_window],
          today: _record(
            checkIn: DateTime(2026, 9, 18, 17, 5),
            checkOut: DateTime(2026, 9, 18, 20, 0),
            review: ApprovalStatus.approved,
          ),
        ),
        ShiftState.completed,
      );
    });

    test('no windows and no record is an off day', () {
      expect(deriveShiftState(now: _midShift), ShiftState.offDay);
    });

    test('checked in with no windows is still working', () {
      expect(
        deriveShiftState(
          now: _midShift,
          today: _record(checkIn: DateTime(2026, 9, 18, 8, 0)),
        ),
        ShiftState.working,
      );
    });

    test('split slots stay working between the two windows', () {
      final bothActive = deriveShiftState(
        now: DateTime(2026, 9, 18, 13, 0),
        windows: const [
          ShiftWindow(start: Duration(hours: 7), end: Duration(hours: 8)),
          ShiftWindow(start: Duration(hours: 17), end: Duration(hours: 18)),
        ],
        today: _record(checkIn: DateTime(2026, 9, 18, 7, 2)),
      );
      expect(bothActive, ShiftState.working);
    });
  });
}