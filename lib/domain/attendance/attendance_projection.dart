import '../../core/models/models.dart';

/// Resolve today's state for a student from assignment windows and the day's
/// attendance record into the [ShiftState] the TodayPanel renders.
///
/// This is the single canonical projection from schedule + attendance facts to
/// the presentation state. It is cosmetic: it converts persisted data into the
/// headline narrative the UI presents and never mutates anything. Pure
/// function, unit-tested with an injected clock.
ShiftState deriveShiftState({
  required DateTime now,
  List<ShiftWindow> windows = const [],
  AttendanceRecord? today,
  ApprovalStatus approval = ApprovalStatus.pending,
  bool isLeave = false,
  bool isOffDay = false,
}) {
  if (isLeave || today?.status == AttendanceStatus.leave) return ShiftState.leave;
  if (isOffDay) return ShiftState.offDay;
  if (approval == ApprovalStatus.flagged ||
      today?.review == ApprovalStatus.flagged ||
      today?.status == AttendanceStatus.flagged) {
    return ShiftState.flagged;
  }
  final effectiveApproval = (approval != ApprovalStatus.pending) ? approval : (today?.review ?? approval);

  if (windows.isEmpty) {
    return today?.checkIn != null ? ShiftState.working : ShiftState.offDay;
  }

  final starts = windows.map((w) => w.startOn(now)).toList()..sort();
  final ends = windows.map((w) => w.endOn(now)).toList()..sort();
  final nextStart = starts.firstWhere((t) => t.isAfter(now), orElse: () => starts.first);

  if (today == null) {
    if (now.isAfter(ends.last)) return ShiftState.missed;
    final wait = nextStart.difference(now);
    return (wait > Duration.zero && wait <= const Duration(minutes: 15))
        ? ShiftState.ready
        : (now.isBefore(starts.first) ? ShiftState.upcoming : ShiftState.ready);
  }

  if (today.checkOut != null) {
    return (effectiveApproval == ApprovalStatus.approved || today.status == AttendanceStatus.present)
        ? ShiftState.completed
        : ShiftState.pendingVerification;
  }
  if (today.checkIn != null) return ShiftState.working;

  if (now.isAfter(ends.last)) return ShiftState.missed;
  final wait = nextStart.difference(now);
  return (wait > Duration.zero && wait <= const Duration(minutes: 15))
      ? ShiftState.ready
      : (now.isBefore(starts.first) ? ShiftState.upcoming : ShiftState.ready);
}