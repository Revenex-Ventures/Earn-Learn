// ignore_for_file: prefer_initializing_formals

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../domain/domain.dart';
import '../app_flavor.dart';
import 'attendance_gateway.dart';
import 'firestore_mappers.dart';

/// Narrow read-only Firestore surface so the client repositories never touch
/// server-authoritative writes (roles, statuses, verified timestamps, hours).
abstract class FirebaseDataStore {
  Future<Map<String, Object?>?> read(String docPath);

  Future<List<Map<String, Object?>>> readAll(String collectionPath);
}

class CloudFirestoreDataStore implements FirebaseDataStore {
  CloudFirestoreDataStore(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<Map<String, Object?>?> read(String docPath) async {
    final snap = await _firestore.doc(docPath).get();
    if (!snap.exists) return null;
    return snap.data()?.cast<String, Object?>();
  }

  @override
  Future<List<Map<String, Object?>>> readAll(String collectionPath) async {
    final snap = await _firestore.collection(collectionPath).get();
    return [
      for (final d in snap.docs) d.data().cast<String, Object?>(),
    ];
  }
}

/// Emulator-only wiring. Live infrastructure stays billing-blocked.
class FirebaseRepositories {
  FirebaseRepositories._();

  static Future<void> attachEmulators({required String host}) async {
    FirebaseFirestore.instance
        .useFirestoreEmulator(host, AppFlavor.firestorePort);
  }
}

/// Account source that supplies the signed-in UID out-of-band (auth plugin).
typedef UidProvider = String? Function();

class FirestoreAccountRepository implements AccountRepository {
  FirestoreAccountRepository({
    required FirebaseDataStore store,
    required UidProvider uid,
  })  : _store = store,
        _uid = uid;

  final FirebaseDataStore _store;
  final UidProvider _uid;

  @override
  Future<UserProfile?> currentUser() async {
    final uid = _uid();
    if (uid == null) return null;
    final data = await _store.read('users/$uid');
    if (data == null) return null;
    return mapUserProfileFromDoc(uid: uid, data: data);
  }

  @override
  Future<AccountLink?> currentAccountLink() async {
    final uid = _uid();
    if (uid == null) return null;
    final data = await _store.read('users/$uid');
    if (data == null) return null;
    return mapAccountLinkFromDoc(uid: uid, data: data);
  }
}

class FirestoreStudentRepository implements StudentRepository {
  FirestoreStudentRepository(this._store);

  final FirebaseDataStore _store;

  @override
  Future<Student?> byId(String id) async {
    final data = await _store.read('students/$id');
    if (data == null) return null;
    return mapStudentFromDoc(id: id, data: data);
  }

  @override
  Future<Student?> byUid(String uid) async {
    for (final data in await _store.readAll('students')) {
      if (data['uid'] == uid) {
        return mapStudentFromDoc(id: data['id'] as String? ?? uid, data: data);
      }
    }
    return null;
  }

  @override
  Future<List<Student>> all() async {
    final docs = await _store.readAll('students');
    return [
      for (final data in docs)
        mapStudentFromDoc(id: parseString(data['id'], ''), data: data),
    ];
  }

  @override
  Future<void> updateProfile(Student student) async {
    // Student updates in firestore
  }
}

class FirestoreSupervisorRepository implements SupervisorRepository {
  FirestoreSupervisorRepository(this._store);

  final FirebaseDataStore _store;

  @override
  Future<Supervisor?> byId(String id) async {
    final data = await _store.read('supervisors/$id');
    if (data == null) return null;
    return mapSupervisorFromDoc(id: id, data: data);
  }

  @override
  Future<Supervisor?> byUid(String uid) async {
    for (final data in await _store.readAll('supervisors')) {
      if (data['uid'] == uid) {
        return mapSupervisorFromDoc(id: data['id'] as String? ?? uid, data: data);
      }
    }
    return null;
  }

  @override
  Future<List<Supervisor>> all() async {
    final docs = await _store.readAll('supervisors');
    return [
      for (final data in docs)
        mapSupervisorFromDoc(id: parseString(data['id'], ''), data: data),
    ];
  }
}

class FirestoreLocationRepository implements LocationRepository {
  FirestoreLocationRepository(this._store);

  final FirebaseDataStore _store;

  @override
  Future<Location?> byId(String id) async {
    final data = await _store.read('locations/$id');
    if (data == null) return null;
    return mapLocationFromDoc(id: id, data: data);
  }

  @override
  Future<List<Location>> all() async {
    final docs = await _store.readAll('locations');
    return [
      for (final data in docs)
        mapLocationFromDoc(id: parseString(data['id'], ''), data: data),
    ];
  }
}

class FirestoreAssignmentRepository implements AssignmentRepository {
  FirestoreAssignmentRepository(this._store);

  final FirebaseDataStore _store;

  @override
  Future<Assignment?> byId(String id) async {
    final data = await _store.read('assignments/$id');
    if (data == null) return null;
    return mapAssignmentFromDoc(id: id, data: data);
  }

  @override
  Future<Assignment?> forStudent(String studentId) async {
    final data = await _store.read('assignments/$studentId');
    if (data == null) return null;
    return mapAssignmentFromDoc(id: studentId, data: data);
  }

  @override
  Future<List<Assignment>> all() async {
    final docs = await _store.readAll('assignments');
    return [
      for (final data in docs)
        mapAssignmentFromDoc(
          id: parseString(data['id'],
              parseString(data['studentId'], '')),
          data: data,
        ),
    ];
  }
}

class FirestoreAttendanceRepository implements AttendanceRepository {
  FirestoreAttendanceRepository({required FirebaseDataStore store}) : _store = store;

  final FirebaseDataStore _store;

  @override
  Future<AttendanceRecord?> recordForDay({
    required String studentId,
    required DateTime day,
  }) async {
    final path =
        'attendance/$studentId/${monthKey(day)}/${dateKey(day)}';
    final data = await _store.read(path);
    if (data == null) return null;
    final session = mapSessionFromDoc(id: dateKey(day), data: data);
    return mapAttendanceRecordFromSession(session);
  }

  @override
  Future<List<AttendanceRecord>> recordsForMonth({
    required String studentId,
    required DateTime month,
  }) async {
    final path = 'attendance/$studentId/${monthKey(month)}';
    final docs = await _store.readAll(path);
    final records = <DateTime, AttendanceRecord>{};
    for (final data in docs) {
      final id = parseString(data['date'], dateKey(month));
      final session = mapSessionFromDoc(id: id, data: data);
      final mapped = mapAttendanceRecordFromSession(session);
      if (mapped != null) records[session.date] = mapped;
    }
    final list = records.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }
}

class FirestoreVerificationRepository implements VerificationRepository {
  FirestoreVerificationRepository(this._gateway);

  final AttendanceGateway _gateway;

  @override
  Future<List<VerificationItem>> items({ApprovalStatus? status}) async {
    final items = await _gateway.myQueue();
    if (status == null) return items;
    return items.where((v) => v.status == status).toList();
  }

  @override
  Future<int> openCount() async => (await _gateway.myQueue()).length;
}

/// Firebase-backed repository providers (emulator-first) — bindings are
/// selected by the single set of provider names in `local_repositories.dart`
/// when `AppFlavor.useFirebase` is true.
final firestoreDataStoreProvider = Provider<FirebaseDataStore>(
  (ref) => CloudFirestoreDataStore(FirebaseFirestore.instance),
);

/// The current signed-in UID (null when signed out). Mutated by the auth
/// controller; providers read it through the account repository.
final firebaseAuthUidProvider = StateProvider<String?>((ref) => null);