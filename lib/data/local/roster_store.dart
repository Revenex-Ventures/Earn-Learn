import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/models/models.dart';
import '../../shared/mock_data/avcoe_seed_data.dart';
import '../dev_only.dart';
import 'notification_store.dart';

/// On-device persistent roster for the local (no-Firebase) build.
///
/// Owns the *live, mutable* lists of students, supervisors, assignments and
/// locations. It is seeded from [AvcoeSeedData] and then lets supervisors and
/// the SDO / admin add students, remove them, adjust shift timings, and add or
/// remove supervisors — all surviving an app restart via
/// `flutter_secure_storage`.
///
/// The lists are stable instances: `mockStudents` / `mockSupervisors` /
/// `mockAssignments` return these same objects, so every repository that
/// captured them at construction sees mutations immediately. A newly added
/// student can log in at once (credentials match the roster) and appears in
/// their supervisor's roster; a shift edit flows straight to the student's
/// schedule.
///
/// The Firestore build ignores this store entirely.
@DevOnly('Persistent, mutable roster for the local/demo build.')
class RosterStore {
  RosterStore._()
      : _students = [...AvcoeSeedData.students],
        _supervisors = [...AvcoeSeedData.supervisors],
        _assignments = AvcoeSeedData.createAssignments(),
        _locations = [...AvcoeSeedData.locations];

  static final RosterStore instance = RosterStore._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _key = 'el_roster_v1';

  final List<Student> _students;
  final List<Supervisor> _supervisors;
  final List<Assignment> _assignments;
  final List<Location> _locations;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  // Stable live views (same instances used app-wide).
  List<Student> get students => _students;
  List<Supervisor> get supervisors => _supervisors;
  List<Assignment> get assignments => _assignments;
  List<Location> get locations => _locations;

  /// Hydrates persisted roster edits from disk. Call once at boot, before
  /// `runApp`. If nothing was ever persisted, the seed roster is kept as-is.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final st = decoded['students'] as List?;
        final sv = decoded['supervisors'] as List?;
        final asn = decoded['assignments'] as List?;
        if (st != null) {
          _students
            ..clear()
            ..addAll(st.map((e) => _studentFromJson(e as Map<String, dynamic>)));
        }
        if (sv != null) {
          _supervisors
            ..clear()
            ..addAll(
                sv.map((e) => _supervisorFromJson(e as Map<String, dynamic>)));
        }
        if (asn != null) {
          _assignments
            ..clear()
            ..addAll(
                asn.map((e) => _assignmentFromJson(e as Map<String, dynamic>)));
        }
      }
    } catch (_) {
      // A corrupt store must never crash the app; fall back to the seed.
    }
    _loaded = true;
  }

  // --- reads ----------------------------------------------------------------

  Student? studentById(String id) {
    for (final s in _students) {
      if (s.id == id) return s;
    }
    return null;
  }

  Assignment? assignmentForStudent(String studentId) {
    for (final a in _assignments) {
      if (a.studentId == studentId) return a;
    }
    return null;
  }

  /// Students whose active assignment is supervised by [supervisorId].
  List<Student> studentsForSupervisor(String supervisorId) {
    final ids = _assignments
        .where((a) => a.supervisorId == supervisorId)
        .map((a) => a.studentId)
        .toSet();
    return _students.where((s) => ids.contains(s.id)).toList(growable: false);
  }

  // --- mutations (each persists) --------------------------------------------

  /// Adds a student and their duty assignment in one step, so the new login
  /// resolves everywhere immediately. Returns the created [Student].
  Student addStudent({
    required String name,
    required String locationId,
    required String supervisorId,
    List<ShiftWindow> shiftWindows = const [],
    String workDescription = 'General duty',
    String? department,
    String? className,
    String? contact,
    String? email,
  }) {
    final id = _nextId(_students.map((s) => s.id), 'STU-', 3);
    final roll = _nextId(
        _students.map((s) => s.rollNumber), 'EL2627-', 3);
    final student = Student(
      id: id,
      name: name.trim(),
      rollNumber: roll,
      department: department,
      className: className,
      contact: contact,
      email: email,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _students.add(student);

    final asnId = _nextId(_assignments.map((a) => a.id), 'ASN-', 3);
    _assignments.add(Assignment(
      id: asnId,
      studentId: id,
      locationId: locationId,
      supervisorId: supervisorId,
      workDescription: workDescription,
      shiftWindows: shiftWindows,
      effectiveFrom: DateTime.now(),
      status: AssignmentStatus.active,
      locationName: _locationName(locationId),
      supervisorName: _supervisorName(supervisorId),
    ));
    _persist();

    // Connected-loop notifications: welcome the new student and alert their
    // supervisor so the roster change is visible without a manual refresh.
    NotificationStore.instance.add(
      recipientRole: UserRole.student,
      recipientId: id,
      type: NotificationType.studentAdded,
      title: 'Welcome to Earn & Learn',
      body: 'You have been enrolled for campus duty'
          '${locationId.isNotEmpty ? ' at ${_locationName(locationId)}' : ''}.',
    );
    if (supervisorId.isNotEmpty) {
      NotificationStore.instance.add(
        recipientRole: UserRole.supervisor,
        recipientId: supervisorId,
        type: NotificationType.studentAdded,
        title: 'New student assigned',
        body: '${student.name} was added to your roster.',
      );
    }
    return student;
  }

  /// Removes a student and all of their assignments.
  void removeStudent(String studentId) {
    final assignment = assignmentForStudent(studentId);
    final student = studentById(studentId);
    _students.removeWhere((s) => s.id == studentId);
    _assignments.removeWhere((a) => a.studentId == studentId);
    _persist();

    final supervisorId = assignment?.supervisorId;
    if (supervisorId != null && supervisorId.isNotEmpty) {
      NotificationStore.instance.add(
        recipientRole: UserRole.supervisor,
        recipientId: supervisorId,
        type: NotificationType.studentRemoved,
        title: 'Student removed',
        body: '${student?.name ?? 'A student'} was removed from your roster.',
      );
    }
  }

  /// Replaces the shift windows on a student's active assignment.
  void updateStudentShift(String studentId, List<ShiftWindow> windows) {
    final idx = _assignments.indexWhere((a) => a.studentId == studentId);
    if (idx < 0) return;
    _assignments[idx] = _copyAssignment(_assignments[idx], shiftWindows: windows);
    _persist();

    NotificationStore.instance.add(
      recipientRole: UserRole.student,
      recipientId: studentId,
      type: NotificationType.shiftAdjusted,
      title: 'Shift updated',
      body: 'Your duty timings were adjusted. Open your schedule to review.',
    );
  }

  /// Reassigns a student to a different location / supervisor (keeps shifts).
  void reassignStudent(String studentId,
      {String? locationId, String? supervisorId}) {
    final idx = _assignments.indexWhere((a) => a.studentId == studentId);
    if (idx < 0) return;
    final current = _assignments[idx];
    _assignments[idx] = _copyAssignment(
      current,
      locationId: locationId,
      supervisorId: supervisorId,
      locationName: locationId != null ? _locationName(locationId) : null,
      supervisorName: supervisorId != null ? _supervisorName(supervisorId) : null,
    );
    _persist();
  }

  /// Adds a supervisor. Returns the created [Supervisor].
  Supervisor addSupervisor({
    required String name,
    String? department,
    List<String> locationIds = const [],
    String? email,
    String? contact,
  }) {
    final id = _nextId(_supervisors.map((s) => s.id), 'SV-', 2);
    final supervisor = Supervisor(
      id: id,
      name: name.trim(),
      department: department,
      email: email,
      contact: contact,
      assignedLocationIds: [...locationIds],
      status: SupervisorStatus.onDuty,
    );
    _supervisors.add(supervisor);
    _persist();
    return supervisor;
  }

  /// Removes a supervisor. Their students' assignments keep the id but surface
  /// as unassigned until an admin reassigns them.
  void removeSupervisor(String supervisorId) {
    _supervisors.removeWhere((s) => s.id == supervisorId);
    _persist();
  }

  /// Clears all persisted roster edits and restores the seed (tests / reset).
  Future<void> reset() async {
    _students
      ..clear()
      ..addAll(AvcoeSeedData.students);
    _supervisors
      ..clear()
      ..addAll(AvcoeSeedData.supervisors);
    _assignments
      ..clear()
      ..addAll(AvcoeSeedData.createAssignments());
    _locations
      ..clear()
      ..addAll(AvcoeSeedData.locations);
    await _storage.delete(key: _key);
  }

  // --- helpers --------------------------------------------------------------

  String _nextId(Iterable<String> existing, String prefix, int width) {
    var max = 0;
    for (final id in existing) {
      if (!id.startsWith(prefix)) continue;
      final n = int.tryParse(id.substring(prefix.length));
      if (n != null && n > max) max = n;
    }
    return '$prefix${(max + 1).toString().padLeft(width, '0')}';
  }

  String _locationName(String locationId) {
    for (final l in _locations) {
      if (l.id == locationId) return l.name;
    }
    return '';
  }

  String _supervisorName(String supervisorId) {
    for (final s in _supervisors) {
      if (s.id == supervisorId) return s.name;
    }
    return supervisorId.isEmpty ? 'Not assigned' : '';
  }

  Assignment _copyAssignment(
    Assignment a, {
    String? locationId,
    String? supervisorId,
    List<ShiftWindow>? shiftWindows,
    String? locationName,
    String? supervisorName,
  }) {
    return Assignment(
      id: a.id,
      studentId: a.studentId,
      locationId: locationId ?? a.locationId,
      supervisorId: supervisorId ?? a.supervisorId,
      workDescription: a.workDescription,
      shiftWindows: shiftWindows ?? a.shiftWindows,
      effectiveFrom: a.effectiveFrom,
      effectiveTo: a.effectiveTo,
      maxMonthlyHours: a.maxMonthlyHours,
      status: a.status,
      locationName: locationName ?? a.locationName,
      supervisorName: supervisorName ?? a.supervisorName,
    );
  }

  // --- persistence (fire-and-forget; failures are non-fatal) ----------------

  void _persist() {
    final map = <String, dynamic>{
      'students': _students.map(_studentToJson).toList(),
      'supervisors': _supervisors.map(_supervisorToJson).toList(),
      'assignments': _assignments.map(_assignmentToJson).toList(),
    };
    _storage.write(key: _key, value: jsonEncode(map));
  }

  Map<String, dynamic> _studentToJson(Student s) => {
        'id': s.id,
        'uid': s.uid,
        'name': s.name,
        'email': s.email,
        'contact': s.contact,
        'department': s.department,
        'className': s.className,
        'rollNumber': s.rollNumber,
        'status': s.status.name,
        'createdAt': s.createdAt?.toIso8601String(),
        'updatedAt': s.updatedAt?.toIso8601String(),
      };

  Student _studentFromJson(Map<String, dynamic> j) => Student(
        id: j['id'] as String,
        uid: j['uid'] as String?,
        name: j['name'] as String,
        email: j['email'] as String?,
        contact: j['contact'] as String?,
        department: j['department'] as String?,
        className: j['className'] as String?,
        rollNumber: j['rollNumber'] as String,
        status: _accountStatus(j['status'] as String?),
        createdAt: _dt(j['createdAt']),
        updatedAt: _dt(j['updatedAt']),
      );

  Map<String, dynamic> _supervisorToJson(Supervisor s) => {
        'id': s.id,
        'uid': s.uid,
        'name': s.name,
        'department': s.department,
        'email': s.email,
        'contact': s.contact,
        'assignedLocationIds': s.assignedLocationIds,
        'status': s.status.name,
      };

  Supervisor _supervisorFromJson(Map<String, dynamic> j) => Supervisor(
        id: j['id'] as String,
        uid: j['uid'] as String?,
        name: j['name'] as String,
        department: j['department'] as String?,
        email: j['email'] as String?,
        contact: j['contact'] as String?,
        assignedLocationIds: [
          for (final l in (j['assignedLocationIds'] as List? ?? const []))
            l as String,
        ],
        status: _supervisorStatus(j['status'] as String?),
      );

  Map<String, dynamic> _assignmentToJson(Assignment a) => {
        'id': a.id,
        'studentId': a.studentId,
        'locationId': a.locationId,
        'supervisorId': a.supervisorId,
        'workDescription': a.workDescription,
        'shiftWindows': [
          for (final w in a.shiftWindows)
            {'start': w.start.inMinutes, 'end': w.end.inMinutes},
        ],
        'effectiveFrom': a.effectiveFrom.toIso8601String(),
        'effectiveTo': a.effectiveTo?.toIso8601String(),
        'maxMonthlyHours': a.maxMonthlyHours,
        'status': a.status.name,
        'locationName': a.locationName,
        'supervisorName': a.supervisorName,
      };

  Assignment _assignmentFromJson(Map<String, dynamic> j) => Assignment(
        id: j['id'] as String,
        studentId: j['studentId'] as String,
        locationId: j['locationId'] as String,
        supervisorId: j['supervisorId'] as String,
        workDescription: j['workDescription'] as String? ?? '',
        shiftWindows: [
          for (final w in (j['shiftWindows'] as List? ?? const []))
            ShiftWindow(
              start: Duration(minutes: ((w as Map)['start'] as num).toInt()),
              end: Duration(minutes: (w['end'] as num).toInt()),
            ),
        ],
        effectiveFrom:
            _dt(j['effectiveFrom']) ?? DateTime(DateTime.now().year),
        effectiveTo: _dt(j['effectiveTo']),
        maxMonthlyHours: (j['maxMonthlyHours'] as num?)?.toInt() ?? 40,
        status: _assignmentStatus(j['status'] as String?),
        locationName: j['locationName'] as String? ?? '',
        supervisorName: j['supervisorName'] as String? ?? '',
      );

  DateTime? _dt(Object? v) =>
      v == null ? null : DateTime.tryParse(v as String);

  AccountStatus _accountStatus(String? n) {
    for (final v in AccountStatus.values) {
      if (v.name == n) return v;
    }
    return AccountStatus.active;
  }

  SupervisorStatus _supervisorStatus(String? n) {
    for (final v in SupervisorStatus.values) {
      if (v.name == n) return v;
    }
    return SupervisorStatus.onDuty;
  }

  AssignmentStatus _assignmentStatus(String? n) {
    for (final v in AssignmentStatus.values) {
      if (v.name == n) return v;
    }
    return AssignmentStatus.active;
  }
}
