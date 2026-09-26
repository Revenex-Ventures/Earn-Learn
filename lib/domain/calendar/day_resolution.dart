import '../../core/models/models.dart';
import '../assignment/weekly_recurrence.dart';

/// What kind of day a student's schedule resolves to.
enum ScheduledDayKind {
  /// A day with live shift windows.
  workDay,

  /// Weekly off or calendar-suspended day (no compensation).
  offDay,

  /// Unpaid national/college holiday.
  holiday,

  /// Festival that still counts towards earnings.
  paidHoliday,

  /// Approved leave in effect.
  leave,

  /// Nothing scheduled (no windows, no rules).
  unscheduled;

  String get label => switch (this) {
        ScheduledDayKind.workDay => 'Work day',
        ScheduledDayKind.offDay => 'Off day',
        ScheduledDayKind.holiday => 'Holiday',
        ScheduledDayKind.paidHoliday => 'Paid holiday',
        ScheduledDayKind.leave => 'Leave',
        ScheduledDayKind.unscheduled => 'Unscheduled',
      };
}

/// The resolved schedule for a single day, and the rule that produced it.
class ScheduledDay {
  const ScheduledDay({
    required this.kind,
    required this.isPaid,
    required this.windows,
    this.source,
  });

  final ScheduledDayKind kind;

  /// Whether the day still compensates (paid festivals/holidays).
  final bool isPaid;

  final List<ShiftWindow> windows;

  /// Which rule produced this day:
  /// 'calendar' | 'leave' | 'recurrence' | 'assignment'.
  final String? source;
}

/// Resolves a day from the calendar, approved leave, optional weekly
/// recurrence, and the assignment windows themselves.
///
/// Precedence: calendar suspension > approved leave > recurrence > windows.
ScheduledDay resolveDay({
  required DateTime day,
  required Assignment assignment,
  List<CalendarEvent> events = const [],
  List<LeaveRequest> approvedLeaves = const [],
  WeeklyRecurrence? recurrence,
}) {
  final normalized = DateTime(day.year, day.month, day.day);

  for (final e in events) {
    final d = DateTime(e.date.year, e.date.month, e.date.day);
    if (!d.isAtSameMomentAs(normalized)) continue;
    return ScheduledDay(
      kind: e.isPaid ? ScheduledDayKind.paidHoliday : ScheduledDayKind.holiday,
      isPaid: e.isPaid,
      windows: const [],
      source: 'calendar',
    );
  }

  for (final l in approvedLeaves) {
    if (l.status != LeaveStatus.approved) continue;
    final d = DateTime(l.date.year, l.date.month, l.date.day);
    if (!d.isAtSameMomentAs(normalized)) continue;
    return const ScheduledDay(
      kind: ScheduledDayKind.leave,
      isPaid: false,
      windows: [],
      source: 'leave',
    );
  }

  if (recurrence != null && !recurrence.isWorkday(normalized)) {
    return const ScheduledDay(
      kind: ScheduledDayKind.unscheduled,
      isPaid: false,
      windows: [],
      source: 'recurrence',
    );
  }

  final windows = assignment.windowsOn(normalized);
  if (windows.isEmpty) {
    return const ScheduledDay(
      kind: ScheduledDayKind.unscheduled,
      isPaid: false,
      windows: [],
      source: 'assignment',
    );
  }
  return ScheduledDay(
    kind: ScheduledDayKind.workDay,
    isPaid: false,
    windows: windows,
    source: 'assignment',
  );
}