/// Lifecycle of one student's duty day.
///
/// Mirrors the shift machine used by the TodayPanel while adding the
/// verification and review states that Stage 2 (Firestore) will persist.
enum SessionStatus {
  scheduled,
  checkInPending,
  working,
  checkOutPending,
  submitted,
  underReview,
  correctionRequested,
  approved,
  flagged,
  rejected,
  missed,
  cancelled,
  closed;

  String get label => switch (this) {
        SessionStatus.scheduled => 'Scheduled',
        SessionStatus.checkInPending => 'Check-in pending',
        SessionStatus.working => 'Working',
        SessionStatus.checkOutPending => 'Check-out pending',
        SessionStatus.submitted => 'Submitted',
        SessionStatus.underReview => 'Under review',
        SessionStatus.correctionRequested => 'Correction requested',
        SessionStatus.approved => 'Approved',
        SessionStatus.flagged => 'Flagged',
        SessionStatus.rejected => 'Rejected',
        SessionStatus.missed => 'Missed',
        SessionStatus.cancelled => 'Cancelled',
        SessionStatus.closed => 'Closed',
      };

  bool get isTerminal =>
      this == SessionStatus.approved ||
      this == SessionStatus.rejected ||
      this == SessionStatus.missed ||
      this == SessionStatus.cancelled ||
      this == SessionStatus.closed;
}