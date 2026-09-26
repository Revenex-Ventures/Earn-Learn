import 'package:intl/intl.dart';

/// A single shift window expressed as minutes from midnight, keeping the
/// model pure Dart (no Flutter dependency).
///
/// An assignment owns one or more windows so variable durations, split
/// shifts and overnight schedules are all representable.
class ShiftWindow {
  const ShiftWindow({required this.start, required this.end});

  /// Start of the window as minutes from midnight.
  final Duration start;

  /// End of the window as minutes from midnight.
  final Duration end;

  /// Display label, e.g. "6:00 PM – 8:00 PM".
  String get label => '${_format(start)} – ${_format(end)}';

  /// Planned length of the window.
  Duration get duration => end - start;

  /// Duration expressed as fractional hours.
  double get hours => duration.inMinutes / 60.0;

  /// True when [time] falls inside the window.
  bool contains(DateTime time) {
    final minutes = time.hour * 60 + time.minute;
    return minutes >= start.inMinutes && minutes <= end.inMinutes;
  }

  /// This day's window start for [day].
  DateTime startOn(DateTime day) => _timeOn(day, start);

  /// This day's window end for [day].
  DateTime endOn(DateTime day) => _timeOn(day, end);

  /// Duration from [now] to the window start (negative once started).
  Duration durationUntilStart(DateTime now) => startOn(now).difference(now);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShiftWindow &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  String _format(Duration d) {
    final time = DateTime(2000, 1, 1, d.inHours, d.inMinutes % 60);
    return DateFormat('h:mm a').format(time);
  }

  DateTime _timeOn(DateTime day, Duration d) =>
      DateTime(day.year, day.month, day.day, d.inHours, d.inMinutes % 60);
}