/// Category of a calendar event that suspends the regular schedule.
enum CalendarEventType {
  offDay,
  holiday,
  festival,
  event;

  String get label => switch (this) {
        CalendarEventType.offDay => 'Weekly off',
        CalendarEventType.holiday => 'Holiday',
        CalendarEventType.festival => 'Festival',
        CalendarEventType.event => 'Program',
      };
}