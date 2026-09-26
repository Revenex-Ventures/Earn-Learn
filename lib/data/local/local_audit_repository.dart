import '../../core/models/models.dart';
import '../../domain/domain.dart';
import '../../shared/mock_data/mock_data.dart';
import '../dev_only.dart';

@DevOnly('Starts from the demo audit fixtures; appends are in memory only.')
class LocalAuditRepository implements AuditRepository {
  LocalAuditRepository([List<AuditLogEntry> entries = const []])
      : _entries = [...mockAuditLog, ...entries];

  final List<AuditLogEntry> _entries;

  @override
  Future<List<AuditLogEntry>> recent({int limit = 50}) async {
    if (limit <= 0) return const [];
    return _entries.length <= limit ? _entries : _entries.sublist(0, limit);
  }

  @override
  Future<void> add(AuditLogEntry entry) async {
    _entries.insert(0, entry);
  }
}