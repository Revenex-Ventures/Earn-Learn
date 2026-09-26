import 'approval_status.dart';
import 'attendance_status.dart';

/// Resolves the duty photograph for a single attendance day.
///
/// Declared beside the record it describes so both the data layer (which knows
/// how to fetch evidence) and the UI layer (which renders it) can depend on it
/// without either importing the other. Returning null — or throwing — means
/// "no servable photograph", and the UI must say so rather than draw a broken
/// image.
typedef DayEvidenceResolver = Future<String?> Function(AttendanceRecord record);

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
    this.evidenceRef,
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

  /// Opaque handle to the evidence captured for this day (the duty photograph).
  ///
  /// Null whenever the day has no retrievable photograph — an absent day, a
  /// lost upload, or a backend that cannot serve evidence. It is a reference
  /// only; the bytes are resolved on demand and never cached on the record.
  final String? evidenceRef;

  /// Whether a duty photograph is expected to exist for this day.
  ///
  /// True for a day the student actually attended, so the UI can tell
  /// "photograph not captured" apart from "no photograph expected".
  bool get expectsEvidence =>
      checkIn != null && status != AttendanceStatus.absent;

  /// True when the day recorded an arrival, a departure, or both.
  bool get hasAnyTime => checkIn != null || checkOut != null;

  /// True when the day requires a supervisor review.
  bool get needsReview =>
      status == AttendanceStatus.pending ||
      status == AttendanceStatus.late ||
      status == AttendanceStatus.absent ||
      status == AttendanceStatus.flagged;

  static const String collection = 'attendance';
}