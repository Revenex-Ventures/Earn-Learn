import '../../core/models/models.dart';
import '../calendar/day_resolution.dart';
import 'weekly_recurrence.dart';

/// A structural problem found while validating an assignment's windows.
class ShiftPolicyIssue {
  const ShiftPolicyIssue(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Validates a single window: monotonic, within the day, and not yet across
/// midnight (overnight permission is pending college confirmation).
ShiftPolicyIssue? validateWindow(ShiftWindow window) {
  if (window.start < Duration.zero || window.end <= window.start) {
    return ShiftPolicyIssue(
      'Invalid window ${window.label}: end must be after start.',
    );
  }
  if (window.end > const Duration(hours: 24)) {
    return ShiftPolicyIssue(
      'Overnight window ${window.label} crosses midnight and is not yet '
      'permitted — college confirmation pending.',
    );
  }
  return null;
}

/// Structural validation for an assignment's full window set, including
/// overlap detection.
List<ShiftPolicyIssue> validateAssignmentWindows(List<ShiftWindow> windows) {
  final issues = <ShiftPolicyIssue>[];
  final sorted = [...windows]..sort((a, b) => a.start.compareTo(b.start));
  for (var i = 0; i < sorted.length; i++) {
    final own = validateWindow(sorted[i]);
    if (own != null) issues.add(own);
    if (i > 0 && sorted[i].start < sorted[i - 1].end) {
      issues.add(ShiftPolicyIssue(
        'Overlapping windows: ${sorted[i - 1].label} overlaps ${sorted[i].label}.',
      ));
    }
  }
  return issues;
}

/// Total planned hours for an assignment across a month (windows ∩ recurrence).
double monthlyPlannedHours({
  required Assignment assignment,
  DateTime? month,
  WeeklyRecurrence? recurrence,
}) {
  final now = DateTime.now();
  final base = month ?? DateTime(now.year, now.month);
  final days = DateTime(base.year, base.month + 1, 0).day;
  var total = 0.0;
  for (var day = 1; day <= days; day++) {
    final date = DateTime(base.year, base.month, day);
    if (recurrence != null && !recurrence.isWorkday(date)) continue;
    if (assignment.windowsOn(date).isNotEmpty) {
      total += assignment.plannedHoursPerDay;
    }
  }
  return total;
}

/// Whether further monthly hours are still allowed under the ceiling.
class MonthlyCapacity {
  const MonthlyCapacity({required this.maxHours, required this.verifiedHours});

  final int maxHours;
  final double verifiedHours;

  double get remaining =>
      (maxHours - verifiedHours).clamp(0.0, maxHours.toDouble());

  bool get isExhausted => verifiedHours >= maxHours;
}

/// Evaluation of a late check-in against a window and optional grace.
class LateCheckInEvaluation {
  const LateCheckInEvaluation({required this.isLate, required this.delay});

  final bool isLate;
  final Duration delay;
}

LateCheckInEvaluation evaluateLateCheckIn({
  required ShiftWindow window,
  required DateTime checkInVerifiedAt,
  required DateTime day,
  Duration? grace,
}) {
  final start = window.startOn(day);
  final delay = checkInVerifiedAt.difference(start);
  if (delay <= (grace ?? Duration.zero)) {
    return LateCheckInEvaluation(isLate: false, delay: Duration.zero);
  }
  return LateCheckInEvaluation(isLate: true, delay: delay);
}

/// Evaluation of an early check-out.
class EarlyCheckOutEvaluation {
  const EarlyCheckOutEvaluation({
    required this.isEarly,
    required this.shortfall,
  });

  final bool isEarly;
  final Duration shortfall;
}

EarlyCheckOutEvaluation evaluateEarlyCheckOut({
  required ShiftWindow window,
  required DateTime checkOutVerifiedAt,
  required DateTime day,
  Duration? grace,
}) {
  final end = window.endOn(day);
  final shortfall = end.difference(checkOutVerifiedAt);
  if (shortfall <= (grace ?? Duration.zero)) {
    return EarlyCheckOutEvaluation(isEarly: false, shortfall: Duration.zero);
  }
  return EarlyCheckOutEvaluation(isEarly: true, shortfall: shortfall);
}

/// Answer to "is a check-in attempt permitted right now?".
class CheckInEligibility {
  const CheckInEligibility({required this.denied, this.reason});

  final bool denied;
  final String? reason;

  bool get isAllowed => !denied;
}

/// Guards an invalid shift attempt: check-in outside the scheduled day or
/// earlier than the pre-window grace allows.
CheckInEligibility checkInEligibility({
  required ScheduledDay day,
  required DateTime requestedAt,
  List<ShiftWindow> windows = const [],
  Duration? preWindowGrace,
}) {
  switch (day.kind) {
    case ScheduledDayKind.offDay:
    case ScheduledDayKind.holiday:
    case ScheduledDayKind.paidHoliday:
      return const CheckInEligibility(
        denied: true,
        reason: 'Not a scheduled work day.',
      );
    case ScheduledDayKind.leave:
      return const CheckInEligibility(
        denied: true,
        reason: 'Approved leave — no duty today.',
      );
    case ScheduledDayKind.unscheduled:
      return const CheckInEligibility(
        denied: true,
        reason: 'No scheduled window today.',
      );
    case ScheduledDayKind.workDay:
      final effective = windows.isNotEmpty ? windows : day.windows;
      if (effective.isEmpty) {
        return const CheckInEligibility(
          denied: true,
          reason: 'No scheduled window today.',
        );
      }
      final starts = effective.map((w) => w.startOn(requestedAt)).toList()
        ..sort();
      final ends = effective.map((w) => w.endOn(requestedAt)).toList()..sort();
      final opensAt = starts.first;
      final threshold = opensAt.subtract(preWindowGrace ?? Duration.zero);
      if (requestedAt.isBefore(threshold)) {
        return CheckInEligibility(
          denied: true,
          reason: 'Check-in not open yet (opens at ${_clock(opensAt)}).',
        );
      }
      if (requestedAt.isAfter(ends.last)) {
        return const CheckInEligibility(
          denied: true,
          reason: 'Shift window has ended.',
        );
      }
      return const CheckInEligibility(denied: false);
  }
}

String _clock(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
}