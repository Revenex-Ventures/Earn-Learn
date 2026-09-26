/// Daily attendance state for a student on a given day.
enum AttendanceStatus {
  present,
  late,
  absent,
  leave,
  pending,
  scheduled,
  flagged;

  String get label => switch (this) {
        AttendanceStatus.present => 'Present',
        AttendanceStatus.late => 'Late',
        AttendanceStatus.absent => 'Absent',
        AttendanceStatus.leave => 'Leave',
        AttendanceStatus.pending => 'Pending',
        AttendanceStatus.scheduled => 'Scheduled',
        AttendanceStatus.flagged => 'Flagged',
      };
}