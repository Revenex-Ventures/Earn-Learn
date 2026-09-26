import '../../core/models/models.dart';
import 'session_status.dart';

/// A duty session for one student on one day.
///
/// Client-supplied (`*RequestedAt`) and server-authoritative (`*VerifiedAt`)
/// timestamps are intentionally kept separate.
class Session {
  const Session({
    required this.id,
    required this.studentId,
    required this.date,
    required this.windows,
    required this.status,
    this.review = ApprovalStatus.pending,
    this.checkInRequestedAt,
    this.checkInVerifiedAt,
    this.checkOutRequestedAt,
    this.checkOutVerifiedAt,
    this.verifiedHours = 0,
    this.reason,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String studentId;

  /// Normalized to midnight.
  final DateTime date;

  /// Shift windows scheduled for the day (resolved by the day engine).
  final List<ShiftWindow> windows;
  final SessionStatus status;

  /// Supervisor review state for submitted work.
  final ApprovalStatus review;

  final DateTime? checkInRequestedAt;
  final DateTime? checkInVerifiedAt;
  final DateTime? checkOutRequestedAt;
  final DateTime? checkOutVerifiedAt;

  /// Hours confirmed by the supervisor / server.
  final double verifiedHours;

  /// Rejection / flag / correction note.
  final String? reason;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get checkedIn => checkInVerifiedAt != null;
  bool get checkedOut => checkOutVerifiedAt != null;

  /// Total planned minutes across the day's windows.
  int get plannedMinutes =>
      windows.fold<int>(0, (sum, w) => sum + w.duration.inMinutes);

  Session copyWith({
    String? id,
    String? studentId,
    DateTime? date,
    List<ShiftWindow>? windows,
    SessionStatus? status,
    ApprovalStatus? review,
    DateTime? checkInRequestedAt,
    DateTime? checkInVerifiedAt,
    DateTime? checkOutRequestedAt,
    DateTime? checkOutVerifiedAt,
    double? verifiedHours,
    String? reason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Session(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      date: date ?? this.date,
      windows: windows ?? this.windows,
      status: status ?? this.status,
      review: review ?? this.review,
      checkInRequestedAt: checkInRequestedAt ?? this.checkInRequestedAt,
      checkInVerifiedAt: checkInVerifiedAt ?? this.checkInVerifiedAt,
      checkOutRequestedAt: checkOutRequestedAt ?? this.checkOutRequestedAt,
      checkOutVerifiedAt: checkOutVerifiedAt ?? this.checkOutVerifiedAt,
      verifiedHours: verifiedHours ?? this.verifiedHours,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}