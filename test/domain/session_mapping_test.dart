import 'package:flutter_test/flutter_test.dart';
import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/domain/attendance/session.dart';
import 'package:earn_and_learn/domain/attendance/session_mapping.dart';
import 'package:earn_and_learn/domain/attendance/session_status.dart';

void main() {
  group('sessionToAttendanceStatus', () {
    test('maps approved to present', () {
      expect(sessionToAttendanceStatus(SessionStatus.approved), AttendanceStatus.present);
    });

    test('maps flagged to flagged', () {
      expect(sessionToAttendanceStatus(SessionStatus.flagged), AttendanceStatus.flagged);
    });

    test('maps terminal non-working states to absent', () {
      expect(sessionToAttendanceStatus(SessionStatus.rejected), AttendanceStatus.absent);
      expect(sessionToAttendanceStatus(SessionStatus.missed), AttendanceStatus.absent);
      expect(sessionToAttendanceStatus(SessionStatus.cancelled), AttendanceStatus.absent);
      expect(sessionToAttendanceStatus(SessionStatus.closed), AttendanceStatus.absent);
    });

    test('maps in-flight states to pending', () {
      expect(sessionToAttendanceStatus(SessionStatus.scheduled), AttendanceStatus.pending);
      expect(sessionToAttendanceStatus(SessionStatus.checkInPending), AttendanceStatus.pending);
      expect(sessionToAttendanceStatus(SessionStatus.working), AttendanceStatus.pending);
      expect(sessionToAttendanceStatus(SessionStatus.checkOutPending), AttendanceStatus.pending);
      expect(sessionToAttendanceStatus(SessionStatus.submitted), AttendanceStatus.pending);
      expect(sessionToAttendanceStatus(SessionStatus.underReview), AttendanceStatus.pending);
      expect(sessionToAttendanceStatus(SessionStatus.correctionRequested), AttendanceStatus.pending);
    });
  });

  group('attendanceRecordFromSession', () {
    final day = DateTime(2026, 9, 19);
    const windows = [ShiftWindow(start: Duration(hours: 17), end: Duration(hours: 20))];

    Session makeSession({
      required SessionStatus status,
      ApprovalStatus review = ApprovalStatus.pending,
      double verifiedHours = 0,
      DateTime? checkIn,
      DateTime? checkOut,
    }) {
      return Session(
        id: 'SES-001',
        studentId: 'STU-001',
        date: day,
        windows: windows,
        status: status,
        review: review,
        verifiedHours: verifiedHours,
        checkInVerifiedAt: checkIn,
        checkOutVerifiedAt: checkOut,
      );
    }

    test('scheduled and missed sessions map to null footprint', () {
      expect(attendanceRecordFromSession(makeSession(status: SessionStatus.scheduled)), isNull);
      expect(attendanceRecordFromSession(makeSession(status: SessionStatus.missed)), isNull);
    });

    test('approved session maps to full AttendanceRecord with verified fields', () {
      final session = makeSession(
        status: SessionStatus.approved,
        review: ApprovalStatus.approved,
        verifiedHours: 3.0,
        checkIn: DateTime(2026, 9, 19, 17, 0),
        checkOut: DateTime(2026, 9, 19, 20, 0),
      );
      final record = attendanceRecordFromSession(session);

      expect(record, isNotNull);
      expect(record!.id, 'SES-001');
      expect(record.studentId, 'STU-001');
      expect(record.date, day);
      expect(record.status, AttendanceStatus.present);
      expect(record.hours, 3.0);
      expect(record.verifiedHours, 3.0);
      expect(record.review, ApprovalStatus.approved);
      expect(record.checkIn, DateTime(2026, 9, 19, 17, 0));
      expect(record.checkOut, DateTime(2026, 9, 19, 20, 0));
    });

    test('submitted session maps to pending AttendanceRecord', () {
      final session = makeSession(
        status: SessionStatus.submitted,
        review: ApprovalStatus.pending,
        checkIn: DateTime(2026, 9, 19, 17, 0),
        checkOut: DateTime(2026, 9, 19, 20, 0),
      );
      final record = attendanceRecordFromSession(session);

      expect(record, isNotNull);
      expect(record!.status, AttendanceStatus.pending);
      expect(record.review, ApprovalStatus.pending);
    });

    test('flagged session maps to flagged AttendanceRecord', () {
      final session = makeSession(
        status: SessionStatus.flagged,
        review: ApprovalStatus.flagged,
      );
      final record = attendanceRecordFromSession(session);

      expect(record, isNotNull);
      expect(record!.status, AttendanceStatus.flagged);
      expect(record.review, ApprovalStatus.flagged);
    });
  });
}
