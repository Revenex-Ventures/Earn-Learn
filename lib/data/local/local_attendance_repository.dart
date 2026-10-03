import '../../core/models/models.dart';
import '../../domain/domain.dart';
import '../dev_only.dart';
import 'runtime_store.dart';

@DevOnly('Golden demo attendance timeline plus persisted submitted sessions.')
class LocalAttendanceRepository implements AttendanceRepository {
  LocalAttendanceRepository({required this.goldenRecords});

  final List<AttendanceRecord> goldenRecords;

  @override
  Future<AttendanceRecord?> recordForDay({
    required String studentId,
    required DateTime day,
  }) async {
    final normalized = DateTime(day.year, day.month, day.day);
    for (final s in RuntimeStore.instance.sessionsFor(studentId)) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      if (d.isAtSameMomentAs(normalized)) {
        final mapped = attendanceRecordFromSession(s);
        if (mapped != null) return mapped;
      }
    }
    for (final r in goldenRecords) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      if (r.studentId == studentId && d.isAtSameMomentAs(normalized)) {
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
    for (final s in RuntimeStore.instance.sessionsFor(studentId)) {
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

  /// Persists a submitted session so it survives app restarts and is visible
  /// across portals (student calendar + supervisor queue).
  void submitSession(Session session) =>
      RuntimeStore.instance.putSession(session);
}