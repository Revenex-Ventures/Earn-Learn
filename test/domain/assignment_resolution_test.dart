import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/domain/domain.dart';

void main() {
  const student = Student(
    id: 'STU-T1',
    name: 'Test Student',
    rollNumber: '22XX001',
  );
  const location = Location(
    id: 'LOC-T',
    name: 'Test Location',
    status: LocationStatus.active,
  );
  const supervisor = Supervisor(
    id: 'SV-T',
    name: 'Mr. Test',
    assignedLocationIds: ['LOC-T'],
    status: SupervisorStatus.onDuty,
  );
  final assignment = Assignment(
    id: 'ASN-T1',
    studentId: 'STU-T1',
    locationId: 'LOC-T',
    supervisorId: 'SV-T',
    workDescription: 'Test duty',
    shiftWindows: const [
      ShiftWindow(start: Duration(hours: 17), end: Duration(hours: 20)),
    ],
    effectiveFrom: DateTime(2026, 1, 1),
    status: AssignmentStatus.active,
  );

  group('resolveAssignmentFor', () {
    test('resolves the live assignment with its location and supervisor', () {
      final resolution = resolveAssignmentFor(
        student: student,
        assignments: [assignment],
        locations: const [location],
        supervisors: const [supervisor],
        now: DateTime(2026, 6, 1),
      );

      expect(resolution, isNotNull);
      expect(resolution!.assignment.id, 'ASN-T1');
      expect(resolution.location.id, 'LOC-T');
      expect(resolution.supervisor.id, 'SV-T');
      expect(resolution.windowsOn(DateTime(2026, 6, 1)), hasLength(1));
    });

    test('returns null before the assignment becomes effective', () {
      final resolution = resolveAssignmentFor(
        student: student,
        assignments: [assignment],
        locations: const [location],
        supervisors: const [supervisor],
        now: DateTime(2025, 6, 1),
      );

      expect(resolution, isNull);
    });

    test('returns null after the assignment ends', () {
      final ended = Assignment(
        id: 'ASN-T2',
        studentId: 'STU-T1',
        locationId: 'LOC-T',
        supervisorId: 'SV-T',
        workDescription: 'Ended duty',
        shiftWindows: [
          ShiftWindow(start: Duration(hours: 17), end: Duration(hours: 20)),
        ],
        effectiveFrom: DateTime(2026, 1, 1),
        effectiveTo: DateTime(2026, 1, 31),
        status: AssignmentStatus.active,
      );

expect(
          resolveAssignmentFor(
            student: student,
            assignments: [ended],
            locations: const [location],
            supervisors: const [supervisor],
            now: DateTime(2026, 3, 1),
          ),
          isNull,
        );
    });

    test('returns null when the student has no assignment', () {
      const other = Student(
        id: 'STU-T9',
        name: 'Unassigned Student',
        rollNumber: '22XX009',
      );

expect(
        resolveAssignmentFor(
          student: other,
          assignments: [assignment],
          locations: const [location],
          supervisors: const [supervisor],
        ),
        isNull,
      );
    });

    test('throws when references are broken', () {
      expect(
        () => resolveAssignmentFor(
          student: student,
          assignments: [assignment],
          locations: const [],
          supervisors: const [supervisor],
        ),
        throwsA(isA<AssignmentResolutionException>()),
      );
    });
  });
}