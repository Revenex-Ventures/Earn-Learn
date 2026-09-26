/// Optional fixed weekly rhythm for assignments.
///
/// An empty or unconfigured recurrence means the rule is not applied and
/// shifts run on the assignment windows plus the calendar only.
class WeeklyRecurrence {
  const WeeklyRecurrence(this.workingDays);

  /// Working weekdays, 1=Monday .. 7=Sunday.
  final Set<int> workingDays;

  bool get isConfigured => workingDays.isNotEmpty;

  bool isWorkday(DateTime day) =>
      !isConfigured || workingDays.contains(day.weekday);

  @override
  bool operator ==(Object other) =>
      other is WeeklyRecurrence &&
      other.workingDays.length == workingDays.length &&
      workingDays.containsAll(other.workingDays);

  @override
  int get hashCode => Object.hashAllUnordered(workingDays);
}