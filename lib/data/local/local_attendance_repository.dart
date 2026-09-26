import '../../core/models/models.dart';
import '../../domain/domain.dart';
import '../dev_only.dart';

@DevOnly('Golden demo attendance timeline plus in-memory submitted sessions.')
class LocalAttendanceRepository implements AttendanceRepository {
  LocalAttendanceRepository({required this.goldenRecords})
      : _submitted = <String, Session>{};

  final List<AttendanceRecord> goldenRecords;
  final Map<String, Session> _submitted;

  @override
  Future<AttendanceRecord?> recordForDay({
    required String studentId,
    required DateTime day,
  }) async {
    final normalized = DateTime(day.year, day.month, day.day);
    for (final s in _submitted.values) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      if (s.studentId == studentId && d.isAtSameMomentAs(normalized)) {
        return attendanceRecordFromSession(s);
      }
    }
    for (final r in goldenRecords) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      if (r.studentId == studentId &&
          d.isAtSameMomentAs(normalized)) {
        return r;
      }
    }
    return null;
  }

  @override
  Future<List<AttendanceRecord>> recordsForMonth({
    required String studentId,
    required DateTime month,
  }) async {
    final records = <AttendanceRecord>[
      for (final r in goldenRecords)
        if (r.studentId == studentId &&
            r.date.year == month.year &&
            r.date.month == month.month)
          r,
    ];
    for (final s in _submitted.values) {
      if (s.studentId != studentId) continue;
      if (s.date.year != month.year || s.date.month != month.month) continue;
      final mapped = attendanceRecordFromSession(s);
      if (mapped == null) continue;
      records.removeWhere((r) {
        final d = DateTime(r.date.year, r.date.month, r.date.day);
        return d.isAtSameMomentAs(
          DateTime(s.date.year, s.date.month, s.date.day),
        );
      });
      records.add(mapped);
    }
    records.sort((a, b) => a.date.compareTo(b.date));
    return records;
  }

  /// In-memory session helper for local development and testing.
  void submitSession(Session session) {
    _submitted[session.id] = session;
  }
}