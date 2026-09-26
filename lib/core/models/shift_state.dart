/// Today's shift machine state for the TodayPanel.
enum ShiftState {
  upcoming,
  ready,
  working,
  completed,
  pendingVerification,
  missed,
  flagged,
  leave,
  offDay;

  String get label => switch (this) {
        ShiftState.upcoming => 'Upcoming',
        ShiftState.ready => 'Ready',
        ShiftState.working => 'Working',
        ShiftState.completed => 'Completed',
        ShiftState.pendingVerification => 'Pending verification',
        ShiftState.missed => 'Missed',
        ShiftState.flagged => 'Flagged',
        ShiftState.leave => 'On leave',
        ShiftState.offDay => 'Off day',
      };
}