import '../../core/models/models.dart';
import '../../domain/domain.dart';
import '../dev_only.dart';

@DevOnly('Backed by the college workbook seed (12 supervisors).')
class LocalSupervisorRepository implements SupervisorRepository {
  const LocalSupervisorRepository(this.supervisors);

  final List<Supervisor> supervisors;

  @override
  Future<Supervisor?> byId(String id) async {
    for (final s in supervisors) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Future<Supervisor?> byUid(String uid) async {
    for (final s in supervisors) {
      if (s.uid == uid) return s;
    }
    return null;
  }

  @override
  Future<List<Supervisor>> all() async => supervisors;
}