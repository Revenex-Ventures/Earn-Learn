import 'calendar_event_type.dart';

class CalendarEvent {
  const CalendarEvent({
    required this.date,
    required this.label,
    required this.type,
    this.isPaid = false,
  });

  /// Day the event suspends the schedule (normalized to midnight).
  final DateTime date;
  final String label;
  final CalendarEventType type;

  /// Whether the day still counts towards earnings (paid holiday).
  final bool isPaid;

  static const String collection = 'calendar';
}