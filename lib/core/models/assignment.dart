import 'assignment_status.dart';
import 'shift_window.dart';

class Assignment {
  const Assignment({
    required this.id,
    required this.studentId,
    required this.locationId,
    required this.supervisorId,
    required this.workDescription,
    required this.shiftWindows,
    required this.effectiveFrom,
    required this.status,
    this.supervisorName = '',
    this.locationName = '',
    this.effectiveTo,
    this.maxMonthlyHours = 40,
  });

  final String id;
  final String studentId;
  final String locationId;
  final String supervisorId;
  final String workDescription;
  final List<ShiftWindow> shiftWindows;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final int maxMonthlyHours;
  final AssignmentStatus status;

  /// Display helpers (resolved from reference IDs by the UI / fixtures).
  final String supervisorName;
  final String locationName;

  /// True when the assignment has more than one shift window.
  bool get isSplitShift => shiftWindows.length > 1;

  /// Display label, e.g. "6:00 PM – 8:00 PM" or "4:00 PM – 5:00 PM, 6:00 PM – 8:00 PM".
  String get shiftLabel => shiftWindows.isEmpty
      ? 'Shift unassigned'
      : shiftWindows.map((w) => w.label).join(', ');

  /// Planned total hours per day from all windows.
  double get plannedHoursPerDay =>
      shiftWindows.fold<double>(0, (sum, w) => sum + w.duration.inMinutes) / 60;

  /// Windows that are active on [day] based on effectiveFrom/To.
  List<ShiftWindow> windowsOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (d.isBefore(DateTime(effectiveFrom.year, effectiveFrom.month, effectiveFrom.day))) {
      return const [];
    }
    if (effectiveTo != null && d.isAfter(effectiveTo!)) return const [];
    return shiftWindows;
  }

  static const String collection = 'assignments';
}