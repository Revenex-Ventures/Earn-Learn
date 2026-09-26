import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/core/seed/seed_validation_report.dart';
import 'package:earn_and_learn/core/seed/student_seed_entry.dart';
import 'package:earn_and_learn/domain/domain.dart';
import 'package:earn_and_learn/shared/mock_data/avcoe_seed_data.dart';
import 'package:earn_and_learn/shared/mock_data/mock_data.dart';

const _shift3h = ShiftWindow(start: Duration(hours: 17), end: Duration(hours: 20));
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
  group('deriveShiftState edges', () {
    test('within 15 minutes of start is ready', () {
      expect(
        deriveShiftState(now: _tenMinBefore, windows: const [_shift3h]),
        ShiftState.ready,
      );
    });

    test('more than 30 minutes before start is upcoming', () {
      expect(
        deriveShiftState(now: _fortyMinBefore, windows: const [_shift3h]),
        ShiftState.upcoming,
      );
    });

    test('explicit leave wins over a live shift', () {
      expect(
        deriveShiftState(
          now: _midShift,
          windows: const [_shift3h],
          today: _record(status: AttendanceStatus.leave),
        ),
        ShiftState.leave,
      );
    });

    test('checked out but unapproved is pending verification', () {
      expect(
        deriveShiftState(
          now: _afterShift,
          windows: const [_shift3h],
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
          windows: const [_shift3h],
          today: _record(
            checkIn: DateTime(2026, 9, 18, 17, 5),
            checkOut: DateTime(2026, 9, 18, 20, 0),
            review: ApprovalStatus.approved,
          ),
        ),
        ShiftState.completed,
      );
    });

    test('split windows stay working between the two slots', () {
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

    test('attendance flagged surfaces as flagged even after checkout', () {
      expect(
        deriveShiftState(
          now: _afterShift,
          windows: const [_shift3h],
          today: _record(
            checkIn: DateTime(2026, 9, 18, 17, 0),
            checkOut: DateTime(2026, 9, 18, 20, 0),
          ),
          approval: ApprovalStatus.flagged,
        ),
        ShiftState.flagged,
      );
    });
  });

  group('assignment shift math', () {
test('planned hours across split windows sum', () {
      final split = Assignment(
        id: 'A1',
        studentId: 'S1',
        locationId: 'L1',
        supervisorId: 'SV1',
        workDescription: 'w',
        shiftWindows: const [
          ShiftWindow(start: Duration(hours: 7), end: Duration(hours: 8)),
          ShiftWindow(start: Duration(hours: 17), end: Duration(hours: 18)),
        ],
        effectiveFrom: DateTime(2026, 9, 1),
        status: AssignmentStatus.active,
      );
      expect(split.isSplitShift, isTrue);
      expect(split.plannedHoursPerDay, 2.0);
      expect(split.maxMonthlyHours, 40);
    });

    test('windowsOn respects effectiveFrom and effectiveTo', () {
      final active = Assignment(
        id: 'A2',
        studentId: 'S2',
        locationId: 'L1',
        supervisorId: 'SV1',
        workDescription: 'w',
        shiftWindows: const [_shift3h],
        effectiveFrom: DateTime(2026, 9, 1),
        effectiveTo: DateTime(2026, 9, 30),
        status: AssignmentStatus.active,
      );
      expect(active.windowsOn(DateTime(2026, 9, 18)), isNotEmpty);
      expect(active.windowsOn(DateTime(2026, 8, 18)), isEmpty);
      expect(active.windowsOn(DateTime(2026, 10, 1)), isEmpty);
    });
  });

  group('policy ceiling', () {
    test('mock policy is a configurable 40h ceiling, not a constant', () {
      expect(mockAppPolicy.monthlyMaxHours, 40);
      const independent = AppPolicy(monthlyMaxHours: 40);
      expect(independent.monthlyMaxHours, 40);
    });
  });

  group('worksheet seed validation', () {
    test('flags missing columns and duplicate names without fabricating', () {
      const rows = [
        StudentSeedEntry(name: 'Alpha', department: 'Civil Engineering'),
        StudentSeedEntry(name: 'Alpha'),
        StudentSeedEntry(name: 'Gamma', className: 'TE-A', time: '5-8 PM'),
        StudentSeedEntry(name: ''),
      ];
      final report = validateSeedEntries(rows);
      expect(report.hasIssues, isTrue);
      expect(report.duplicates, contains('Alpha'));
      expect(report.missingTime, isNotEmpty);
      expect(report.missingWork, isNotEmpty);
      expect(report.missingDepartment, isNotEmpty);
      expect(knownDepartments, contains('Civil Engineering'));
    });
  });

  group('roster helpers', () {
    test('every student resolves to exactly one assignment', () {
      for (final s in AvcoeSeedData.students) {
        expect(mockAssignmentFor(s.id), isNotNull, reason: '${s.id} ${s.name}');
      }
    });

    test('supervisor lookup and coverage locations resolve', () {
      final supervisor = mockCurrentSupervisor;
      expect(mockSupervisorById(supervisor.id), isNotNull);
      for (final id in supervisor.assignedLocationIds) {
        expect(mockLocationById(id), isNotNull);
      }
    });

    test('per-student attendance is deterministic and month-scoped', () {
      final a = mockStudentAttendance(mockCurrentStudent.id, mockNow);
      final b = mockStudentAttendance(mockCurrentStudent.id, mockNow);
      expect(a.map((r) => r.id), b.map((r) => r.id));
      expect(a, isNotEmpty);
      for (final r in a) {
        expect(r.studentId, mockCurrentStudent.id);
        expect(r.date.month, mockNow.month);
      }
    });

    test('verified hours tally only covers approved amounts', () {
      final records = [
        AttendanceRecord(
          id: 'x',
          date: DateTime(2026, 9, 1),
          status: AttendanceStatus.present,
          hours: 3,
          verifiedHours: 3,
        ),
        AttendanceRecord(
          id: 'y',
          date: DateTime(2026, 9, 2),
          status: AttendanceStatus.present,
          hours: 3,
          verifiedHours: 0,
        ),
      ];
      expect(mockVerifiedHoursFor(records, DateTime(2026, 9, 1)), 3.0);
    });
  });
}