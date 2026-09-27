import 'approval_status.dart';

/// Kind of record awaiting supervisor verification.
enum VerificationType {
  checkIn,
  checkOut,
  attendanceAudit,
  correction;

  String get label => switch (this) {
        VerificationType.checkIn => 'Check-in',
        VerificationType.checkOut => 'Check-out',
        VerificationType.attendanceAudit => 'Attendance audit',
        VerificationType.correction => 'Correction request',
      };
}

/// A single item in the supervisor approval queue.
class VerificationItem {
  const VerificationItem({
    required this.id,
    required this.studentName,
    required this.studentId,
    required this.location,
    required this.type,
    required this.submittedAt,
    required this.status,
    required this.summary,
    this.evidenceTime,
  });

  final String id;
  final String studentName;
  final String studentId;
  final String location;
  final VerificationType type;
  final DateTime submittedAt;
  final ApprovalStatus status;
  final String summary;

  /// Timestamp of the underlying check-in/check-out event.
  final DateTime? evidenceTime;

  VerificationItem copyWith({
    String? id,
    String? studentName,
    String? studentId,
    String? location,
    VerificationType? type,
    DateTime? submittedAt,
    ApprovalStatus? status,
    String? summary,
    DateTime? evidenceTime,
  }) {
    return VerificationItem(
      id: id ?? this.id,
      studentName: studentName ?? this.studentName,
      studentId: studentId ?? this.studentId,
      location: location ?? this.location,
      type: type ?? this.type,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
      summary: summary ?? this.summary,
      evidenceTime: evidenceTime ?? this.evidenceTime,
    );
  }

  static const String collection = 'verifications';
}