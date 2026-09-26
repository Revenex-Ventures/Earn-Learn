import '../../core/models/models.dart';
import '../../domain/domain.dart';
import '../dev_only.dart';

@DevOnly('Backed by the college workbook seed (68 students).')
class LocalStudentRepository implements StudentRepository {
  const LocalStudentRepository(this.students);

  final List<Student> students;

  @override
  Future<Student?> byId(String id) async {
    for (final s in students) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Future<Student?> byUid(String uid) async {
    for (final s in students) {
      if (s.uid == uid) return s;
    }
    return null;
  }

  @override
  Future<List<Student>> all() async => students;

  @override
  Future<void> updateProfile(Student student) async {
    final idx = students.indexWhere((s) => s.id == student.id);
    if (idx >= 0) {
      students[idx] = student;
    } else {
      students.add(student);
    }
  }
}