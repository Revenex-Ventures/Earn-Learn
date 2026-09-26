enum LeaveStatus {
  pending,
  approved,
  rejected;

  String get label => switch (this) {
        LeaveStatus.pending => 'Pending',
        LeaveStatus.approved => 'Approved',
        LeaveStatus.rejected => 'Rejected',
      };
}

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.date,
    required this.reason,
    required this.status,
    required this.submittedAt,
    this.reviewedBy,
    this.reviewedAt,
  });

  final String id;
  final String studentId;
  final String studentName;
  final DateTime date;
  final String reason;
  final LeaveStatus status;
  final DateTime submittedAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  static const String collection = 'leave_requests';
}