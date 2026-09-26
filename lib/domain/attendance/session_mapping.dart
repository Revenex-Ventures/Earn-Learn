import '../../core/models/models.dart';
import 'session.dart';
import 'session_status.dart';

/// Canonical mapping from [SessionStatus] to [AttendanceStatus].
///
/// Used by both Local and Firestore attendance repositories so the
/// business rule lives in one place. Changes here automatically propagate
/// to every adapter.
AttendanceStatus sessionToAttendanceStatus(SessionStatus status) =>
    switch (status) {
      SessionStatus.approved => AttendanceStatus.present,
      SessionStatus.flagged => AttendanceStatus.flagged,
      SessionStatus.rejected ||
      SessionStatus.missed ||
      SessionStatus.cancelled ||
      SessionStatus.closed =>
        AttendanceStatus.absent,
      _ => AttendanceStatus.pending,
    };

/// Canonical projection of a [Session] into a client-facing
/// [AttendanceRecord] for month/day views.
///
/// Returns `null` for sessions that have no meaningful attendance footprint
/// yet (`scheduled`, `missed`).
AttendanceRecord? attendanceRecordFromSession(Session s) {
  if (s.status == SessionStatus.scheduled ||
      s.status == SessionStatus.missed) {
    return null;
  }
  return AttendanceRecord(
    id: s.id,
    studentId: s.studentId,
    date: s.date,
    status: sessionToAttendanceStatus(s.status),
    hours: s.plannedMinutes / 60,
    verifiedHours: s.verifiedHours,
    checkIn: s.checkInVerifiedAt,
    checkOut: s.checkOutVerifiedAt,
    review: s.review,
    exception: s.reason,
  );
}
