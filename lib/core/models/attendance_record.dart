import 'approval_status.dart';
import 'attendance_status.dart';

class AttendanceRecord {
  const AttendanceRecord({
    this.id = '',
    required this.date,
    required this.status,
    required this.hours,
    this.studentId = '',
    this.verifiedHours = 0,
    this.review = ApprovalStatus.pending,
    this.location,
    this.checkIn,
    this.checkOut,
    this.exception,
  });

  final String id;
  final String studentId;

  /// Day the record belongs to (normalized to midnight).
  final DateTime date;
  final AttendanceStatus status;

  /// Raw recorded hours.
  final double hours;

  /// Hours confirmed by supervisor verification (server authoritative).
  final double verifiedHours;

  /// Review state: pending → approved / rejected / flagged.
  final ApprovalStatus review;

  final String? location;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String? exception;

  /// True when the day requires a supervisor review.
  bool get needsReview =>
      status == AttendanceStatus.pending ||
      status == AttendanceStatus.late ||
      status == AttendanceStatus.absent ||
      status == AttendanceStatus.flagged;

  static const String collection = 'attendance';
}