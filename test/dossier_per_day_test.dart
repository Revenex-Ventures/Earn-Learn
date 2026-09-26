import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/design_system/app_radius.dart';
import 'package:earn_and_learn/core/design_system/app_spacing.dart';
import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/data/firebase/attendance_gateway.dart';
import 'package:earn_and_learn/data/local/local_repositories.dart';
import 'package:earn_and_learn/shared/components/components.dart';

class _StubGateway implements AttendanceGateway {
  _StubGateway(this.responses);

  /// ref -> value (a null value is a "no servable photo" answer).
  final Map<String, String?> responses;
  final List<String> requested = [];

  @override
  Future<String> evidenceUrl({
    required String sessionId,
    required String studentId,
    required String kind,
  }) async {
    requested.add(sessionId);
    final value = responses[sessionId];
    if (value == null) throw StateError('No evidence object for $sessionId');
    return value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not used by this test');
}

class _StubRepo implements AttendanceGateway {
  @override
  Future<String> evidenceUrl({
    required String sessionId,
    required String studentId,
    required String kind,
  }) async =>
      'local://evidence/$studentId/$sessionId/$kind.jpg';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not used by this test');
}

const Student _student = Student(
  id: 'STU-001',
  name: 'Prasanna Auti',
  rollNumber: 'EL2627-052',
  status: AccountStatus.active,
);

Widget _host(List<AttendanceRecord> records, {DayEvidenceResolver? resolve}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: StudentDossierView(
          data: StudentDossierData(
            student: _student,
            records: records,
            resolveEvidence: resolve,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('Dossier per-day detail', () {
    testWidgets('shows the arrival and departure time of the day',
        (tester) async {
      await tester.pumpWidget(_host([
        AttendanceRecord(
          id: 'A-1',
          studentId: 'STU-001',
          date: DateTime(2026, 8, 12),
          status: AttendanceStatus.present,
          hours: 2.5,
          checkIn: DateTime(2026, 8, 12, 18, 2),
          checkOut: DateTime(2026, 8, 12, 20, 31),
        ),
      ]));

      expect(find.textContaining('Attended'), findsOneWidget);
      expect(find.textContaining('6:02 PM'), findsOneWidget);
      expect(find.textContaining('8:31 PM'), findsOneWidget);
    });

    testWidgets('a half-recorded day reads as a dash, not as silence',
        (tester) async {
      await tester.pumpWidget(_host([
        AttendanceRecord(
          id: 'A-2',
          studentId: 'STU-001',
          date: DateTime(2026, 8, 13),
          status: AttendanceStatus.late,
          hours: 1,
          checkIn: DateTime(2026, 8, 13, 19, 5),
        ),
      ]));

      expect(find.textContaining('Attended 7:05 PM'), findsOneWidget);
      expect(find.textContaining('Left —'), findsOneWidget);
    });

    testWidgets('a day with no recorded time shows no time line',
        (tester) async {
      await tester.pumpWidget(_host([
        AttendanceRecord(
          id: 'A-3',
          studentId: 'STU-001',
          date: DateTime(2026, 8, 14),
          status: AttendanceStatus.absent,
          hours: 0,
        ),
      ]));

      expect(find.textContaining('Attended'), findsNothing);
      expect(find.textContaining('Left'), findsNothing);
    });
  });

  group('Dossier per-day evidence', () {
    testWidgets('a missing photograph is stated, never drawn broken',
        (tester) async {
      await tester.pumpWidget(_host(
        [
          AttendanceRecord(
            id: 'A-4',
            studentId: 'STU-001',
            date: DateTime(2026, 8, 15),
            status: AttendanceStatus.present,
            hours: 3,
            checkIn: DateTime(2026, 8, 15, 18),
            checkOut: DateTime(2026, 8, 15, 21),
            evidenceRef: 'duty/A-4.jpg',
          ),
        ],
        resolve: (record) async => null,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Photo not available'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('an absent day never asks for a photograph', (tester) async {
      var asked = 0;
      await tester.pumpWidget(_host(
        [
          AttendanceRecord(
            id: 'A-5',
            studentId: 'STU-001',
            date: DateTime(2026, 8, 16),
            status: AttendanceStatus.absent,
            hours: 0,
          ),
        ],
        resolve: (record) async {
          asked++;
          return null;
        },
      ));
      await tester.pumpAndSettle();

      expect(asked, 0);
      expect(find.text('Photo not available'), findsNothing);
    });

    testWidgets('an attended day with no evidence handle states the absence',
        (tester) async {
      await tester.pumpWidget(_host(
        [
          AttendanceRecord(
            id: 'A-6',
            studentId: 'STU-001',
            date: DateTime(2026, 8, 17),
            status: AttendanceStatus.present,
            hours: 3,
            checkIn: DateTime(2026, 8, 17, 18),
          ),
        ],
        resolve: (record) async => null,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Photo not available'), findsOneWidget);
    });

    testWidgets('with no resolver wired, no thumbnail is attempted',
        (tester) async {
      await tester.pumpWidget(_host([
        AttendanceRecord(
          id: 'A-7',
          studentId: 'STU-001',
          date: DateTime(2026, 8, 18),
          status: AttendanceStatus.present,
          hours: 3,
          checkIn: DateTime(2026, 8, 18, 18),
          evidenceRef: 'duty/A-7.jpg',
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Photo not available'), findsNothing);
      expect(find.byType(Image), findsNothing);
    });
  });

  group('buildDayEvidenceResolver', () {
    test('resolves an http(s) evidence URL', () async {
      final resolver = buildDayEvidenceResolver(
        _StubGateway({'duty/A-8.jpg': 'https://cdn.example/a8.jpg'}),
      );
      final record = AttendanceRecord(
        id: 'A-8',
        studentId: 'STU-001',
        date: DateTime(2026, 8, 19),
        status: AttendanceStatus.present,
        hours: 2,
        evidenceRef: 'duty/A-8.jpg',
      );

      expect(await resolver(record), 'https://cdn.example/a8.jpg');
    });

    test('refuses a non-servable local:// URL so no image is attempted',
        () async {
      final record = AttendanceRecord(
        id: 'A-9',
        studentId: 'STU-001',
        date: DateTime(2026, 8, 20),
        status: AttendanceStatus.present,
        hours: 2,
        evidenceRef: 'duty/A-9.jpg',
      );
      final local = buildDayEvidenceResolver(_StubRepo());

      expect(await local(record), isNull);
    });

    test('a gateway failure resolves to null instead of rethrowing', () async {
      final record = AttendanceRecord(
        id: 'A-10',
        studentId: 'STU-001',
        date: DateTime(2026, 8, 21),
        status: AttendanceStatus.present,
        hours: 2,
        evidenceRef: 'duty/A-10.jpg',
      );
      final resolver = buildDayEvidenceResolver(_StubGateway(const {}));

      expect(await resolver(record), isNull);
    });

    test('a record with no evidence handle performs no request', () async {
      final gateway = _StubGateway({});
      final resolver = buildDayEvidenceResolver(gateway);
      final record = AttendanceRecord(
        id: 'A-11',
        studentId: 'STU-001',
        date: DateTime(2026, 8, 22),
        status: AttendanceStatus.present,
        hours: 2,
      );

      expect(await resolver(record), isNull);
      expect(gateway.requested, isEmpty);
    });
  });

  group('AttendanceRecord evidence semantics', () {
    test('an attended day expects a photograph; an absent day does not', () {
      final attended = AttendanceRecord(
        date: DateTime(2026, 8, 12),
        status: AttendanceStatus.present,
        hours: 2,
        checkIn: DateTime(2026, 8, 12, 18),
      );
      final absent = AttendanceRecord(
        date: DateTime(2026, 8, 12),
        status: AttendanceStatus.absent,
        hours: 0,
      );

      expect(attended.expectsEvidence, isTrue);
      expect(absent.expectsEvidence, isFalse);
    });

    test('hasAnyTime is true for a one-sided day', () {
      final onlyIn = AttendanceRecord(
        date: DateTime(2026, 8, 12),
        status: AttendanceStatus.late,
        hours: 1,
        checkIn: DateTime(2026, 8, 12, 18),
      );
      final neither = AttendanceRecord(
        date: DateTime(2026, 8, 12),
        status: AttendanceStatus.absent,
        hours: 0,
      );

      expect(onlyIn.hasAnyTime, isTrue);
      expect(neither.hasAnyTime, isFalse);
    });
  });

  group('Dossier evidence tile geometry', () {
    testWidgets('the unavailable tile matches the design tokens', (tester) async {
      await tester.pumpWidget(_host(
        [
          AttendanceRecord(
            id: 'A-12',
            studentId: 'STU-001',
            date: DateTime(2026, 8, 23),
            status: AttendanceStatus.present,
            hours: 2,
            checkIn: DateTime(2026, 8, 23, 18),
            evidenceRef: 'duty/A-12.jpg',
          ),
        ],
        resolve: (record) async => null,
      ));
      await tester.pumpAndSettle();

      final shell = tester.widget<Container>(find.descendant(
        of: find.byKey(const ValueKey('evidence-unavailable')),
        matching: find.byType(Container),
      ));
      final decoration = shell.decoration! as BoxDecoration;

      expect(decoration.color, isNotNull);
      expect((decoration.border as Border).top.width, 1);
      expect(
        tester.getSize(find.byKey(const ValueKey('day-evidence-A-12'))).height,
        56,
      );
      expect(AppSpacing.sm, greaterThan(0));
      expect(AppRadius.sm, greaterThan(0));
    });
  });
}
