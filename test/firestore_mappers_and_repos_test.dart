import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/evidence/evidence_geo.dart';
import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/data/firebase/attendance_gateway.dart';
import 'package:earn_and_learn/data/firebase/firebase_repositories.dart';
import 'package:earn_and_learn/data/firebase/firestore_mappers.dart';
import 'package:earn_and_learn/domain/domain.dart';

Map<String, Object?> _sessionDoc({
  String status = 'working',
  String review = 'pending',
  Object? checkInVerifiedAt,
  double verifiedHours = 0,
  List<Map<String, Object?>> windows = const [
    {'startMin': 960, 'endMin': 1080},
  ],
}) {
  return {
    'studentId': 'STU-9001',
    'windows': windows,
    'status': status,
    'review': review,
    'verifiedHours': verifiedHours,
    'checkInRequestedAt': null,
    'checkInVerifiedAt': checkInVerifiedAt,
    'checkOutRequestedAt': null,
    'checkOutVerifiedAt': null,
    'reason': null,
  };
}

void main() {
  group('parseTimestamp', () {
    test('accepts DateTime, string, nanoseconds map, and Firestore Timestamp',
        () {
      final t = DateTime.utc(2026, 9, 19, 10, 30);
      expect(parseTimestamp(t), t);
      expect(parseTimestamp(t.toIso8601String()), t);
      expect(
        parseTimestamp({
          'seconds': t.millisecondsSinceEpoch ~/ 1000,
          'nanoseconds': 0,
        }),
        t,
      );
      expect(parseTimestamp(Timestamp.fromDate(t)), t);
      expect(parseTimestamp(null), isNull);
      expect(parseTimestamp('not-a-date'), isNull);
    });
  });

  group('mapSessionFromDoc', () {
    test('maps a working session including verified timestamp', () {
      final checkedIn = DateTime.utc(2026, 9, 19, 10, 2);
      final session = mapSessionFromDoc(
        id: '2026-09-19',
        data: _sessionDoc(
          status: 'working',
          checkInVerifiedAt: {
            'seconds': checkedIn.millisecondsSinceEpoch ~/ 1000,
            'nanoseconds': 0,
          },
        ),
      );
      expect(session.studentId, 'STU-9001');
      expect(session.status, SessionStatus.working);
      expect(session.windows.single.start, const Duration(minutes: 960));
      expect(session.windows.single.end, const Duration(minutes: 1080));
      expect(session.checkInVerifiedAt, checkedIn);
    });

    test('unknown enums fall back safely', () {
      final session = mapSessionFromDoc(
        id: '2026-09-19',
        data: _sessionDoc(status: '??buggy??'),
      );
      expect(session.status, SessionStatus.scheduled);
    });

    test('submitted with hours maps to a pending verified-hours record', () {
      final record = mapAttendanceRecordFromSession(
        mapSessionFromDoc(id: '2026-09-19', data: _sessionDoc(status: 'submitted')),
      );
      expect(record, isNotNull);
      expect(record!.status, AttendanceStatus.pending);
      expect(record.hours, closeTo(2.0, 0.001));
    });

    test('approved maps to present; scheduled to null; missed to absent', () {
      final approved = mapAttendanceRecordFromSession(
        mapSessionFromDoc(id: '2026-09-19', data: _sessionDoc(status: 'approved', review: 'approved')),
      );
      expect(approved!.status, AttendanceStatus.present);

      expect(
        mapAttendanceRecordFromSession(
          mapSessionFromDoc(id: '2026-09-19', data: _sessionDoc(status: 'scheduled')),
        ),
        isNull,
      );

      final missed = mapAttendanceRecordFromSession(
        mapSessionFromDoc(id: '2026-09-19', data: _sessionDoc(status: 'missed')),
      );
      expect(missed, isNull);
    });
  });

  group('directory + account mappers', () {
    test('mapStudentFromDoc reads fields', () {
      final student = mapStudentFromDoc(id: 'STU-9001', data: {
        'name': 'Synthetic Student One',
        'rollNumber': 'SYN-9001',
        'uid': 'auth-stu-001',
        'email': 'synthetic.one@avcoe.example.edu',
        'className': 'SYN-A',
        'status': 'active',
      });
      expect(student.name, 'Synthetic Student One');
      expect(student.uid, 'auth-stu-001');
      expect(student.status, AccountStatus.active);
    });

    test('mapLocation + mapAssignment decode windows and geofence', () {
      final location = mapLocationFromDoc(id: 'LOC-9001', data: {
        'name': 'Synthetic Test Location',
        'latitude': 19.5,
        'longitude': 74.25,
        'radiusMeters': 100,
        'supervisorIds': ['SV-9001'],
      });
      expect(location.latitude, 19.5);
      expect(location.radiusMeters, 100);

      final assignment = mapAssignmentFromDoc(id: 'STU-9001', data: {
        'studentId': 'STU-9001',
        'locationId': 'LOC-9001',
        'supervisorId': 'SV-9001',
        'shiftWindows': [
          {'startMin': 960, 'endMin': 1080},
        ],
        'effectiveFrom': '2000-01-01',
        'maxMonthlyHours': 40,
        'status': 'active',
      });
      expect(assignment.supervisorId, 'SV-9001');
      expect(assignment.shiftWindows.single.start, const Duration(hours: 16));
    });

    test('mapUserProfile + mapAccountLink reflect link state', () {
      final profile = mapUserProfileFromDoc(uid: 'auth-stu-001', data: {
        'role': 'student',
        'status': 'active',
        'linkedEntityId': 'STU-9001',
        'displayName': 'Syn One',
      });
      expect(profile.role, UserRole.student);
      expect(profile.status, AccountStatus.active);

      final linked = mapAccountLinkFromDoc(uid: 'auth-stu-001', data: {
        'role': 'student',
        'status': 'active',
        'linkedEntityId': 'STU-9001',
      });
      expect(linked!.entityId, 'STU-9001');

      final pending = mapAccountLinkFromDoc(uid: 'auth-stu-pending', data: {
        'role': 'student',
        'status': 'pending',
        'linkedEntityId': null,
      });
      expect(pending!.entityId, isNull);
    });

    test('mapVerificationItem from queue payload', () {
      final item = mapVerificationItem({
        'id': '2026-09-19',
        'studentId': 'STU-9001',
        'studentName': 'Synthetic Student One',
        'location': 'Synthetic Test Location',
        'type': 'checkOut',
        'submittedAt': '2026-09-19T18:00:05.000Z',
        'status': 'pending',
        'summary': 'Duty recorded',
      });
      expect(item.type, VerificationType.checkOut);
      expect(item.status, ApprovalStatus.pending);
      expect(item.submittedAt, DateTime.utc(2026, 9, 19, 18, 0, 5));
    });
  });

  group('Firestore repositories (read surface)', () {
    test('recordForDay returns null when the doc does not exist', () async {
      final repo = FirestoreAttendanceRepository(
        store: _FakeStore({}),
      );
      final record = await repo.recordForDay(
        studentId: 'STU-9001',
        day: DateTime(2026, 9, 19),
      );
      expect(record, isNull);
    });

    test('recordsForMonth maps and sorts by date', () async {
      final store = _FakeStore(
        {},
        {
          'attendance/STU-9001/2026-09': [
            {'date': '2026-09-19', ..._sessionDoc(status: 'approved', review: 'approved')},
            {'date': '2026-09-17', ..._sessionDoc(status: 'submitted')},
            {'date': '2026-09-18', ..._sessionDoc(status: 'missed')},
          ],
        },
      );
      final repo = FirestoreAttendanceRepository(
        store: store,
      );
      final records = await repo.recordsForMonth(
        studentId: 'STU-9001',
        month: DateTime(2026, 9),
      );
      expect(
        records.map((r) => r.date.day).toList(),
        [17, 19], // missed is filtered out by the month projection
      );
    });

    test('verification repository filters queue by status', () async {
      final gateway = _FakeGateway(
        queue: [
          _item(studentId: 'STU-9001', status: ApprovalStatus.pending),
          _item(studentId: 'STU-9001', status: ApprovalStatus.flagged),
        ],
      );
      final repo = FirestoreVerificationRepository(gateway);
      final open = await repo.items();
      expect(open.length, 2);
      final flagged = await repo.items(status: ApprovalStatus.flagged);
      expect(flagged.single.id, '2026-09-19');
      expect(await repo.openCount(), 2);
    });

    test('account repo returns null when signed out', () async {
      final repo = FirestoreAccountRepository(
        store: _FakeStore({}),
        uid: () => null,
      );
      expect(await repo.currentUser(), isNull);
      expect(await repo.currentAccountLink(), isNull);
    });

    test('student repo finds a student by uid across the directory', () async {
      final store = _FakeStore(
        {},
        {
          'students': [
            {'id': 'STU-9001', 'name': 'Syn One', 'uid': 'auth-stu-001', 'status': 'active'},
          ],
        },
      );
      final repo = FirestoreStudentRepository(store);
      final found = await repo.byUid('auth-stu-001');
      expect(found!.id, 'STU-9001');
    });
  });
}

VerificationItem _item({
  required String studentId,
  required ApprovalStatus status,
}) {
  return VerificationItem(
    id: '2026-09-19',
    studentId: studentId,
    studentName: 'Syn One',
    location: 'Synthetic Test Location',
    type: VerificationType.checkOut,
    submittedAt: DateTime.utc(2026, 9, 19, 18, 0),
    status: status,
    summary: 'Duty recorded',
  );
}

class _FakeStore implements FirebaseDataStore {
  _FakeStore(this._docs, [this._collections = const {}]);

  final Map<String, Map<String, Object?>> _docs;
  final Map<String, List<Map<String, Object?>>> _collections;

  @override
  Future<Map<String, Object?>?> read(String docPath) async => _docs[docPath];

  @override
  Future<List<Map<String, Object?>>> readAll(String collectionPath) async =>
      _collections[collectionPath] ?? const [];
}

class _FakeGateway implements AttendanceGateway {
  _FakeGateway({this.queue = const []});

  final List<VerificationItem> queue;

  @override
  Future<CheckInConfirmResult> confirmCheckIn({
    required String requestId,
    required String sessionId,
    required String uploadPath,
    required EvidenceGeo geo,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CheckOutConfirmResult> confirmCheckOut({
    required String requestId,
    required String sessionId,
    required String uploadPath,
    required EvidenceGeo geo,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CheckInInit> checkIn({
    required String requestId,
    required DateTime date,
    required EvidenceGeo geo,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<CheckOutInit> checkOut({
    required String requestId,
    required String sessionId,
    required EvidenceGeo geo,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> evidenceUrl({
    required String sessionId,
    required String studentId,
    required String kind,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<VerificationItem>> myQueue() async => queue;

  @override
  Future<ReviewResult> review({
    required String sessionId,
    required String studentId,
    required ApprovalStatus decision,
    String? note,
  }) {
    throw UnimplementedError();
  }
}