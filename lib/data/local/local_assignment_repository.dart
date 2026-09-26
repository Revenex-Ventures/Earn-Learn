import '../../core/models/models.dart';
import '../../domain/domain.dart';
import '../dev_only.dart';

@DevOnly('Backed by the college workbook seed (68 assignments).')
class LocalAssignmentRepository implements AssignmentRepository {
  const LocalAssignmentRepository(this.assignments);

  final List<Assignment> assignments;

  @override
  Future<Assignment?> byId(String id) async {
    for (final a in assignments) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Future<Assignment?> forStudent(String studentId) async {
    Assignment? found;
    for (final a in assignments) {
      if (a.studentId != studentId) continue;
      if (a.status != AssignmentStatus.active &&
          a.status != AssignmentStatus.temporary) {
        continue;
      }
      if (found == null || a.effectiveFrom.isAfter(found.effectiveFrom)) {
        found = a;
      }
    }
    return found;
  }

  @override
  Future<List<Assignment>> all() async => assignments;
}