/// Review state of an attendance/verification item.
enum ApprovalStatus {
  pending,
  approved,
  rejected,
  flagged;

  String get label => switch (this) {
        ApprovalStatus.pending => 'Pending',
        ApprovalStatus.approved => 'Approved',
        ApprovalStatus.rejected => 'Rejected',
        ApprovalStatus.flagged => 'Flagged',
      };
}