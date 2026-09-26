import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/data/data.dart';
import 'package:earn_and_learn/domain/domain.dart';
import 'package:earn_and_learn/shared/mock_data/mock_data.dart';

void main() {
  group('seed roster counts', () {
    test('the workbook snapshot has the authenticated totals', () {
      expect(mockStudents, hasLength(68));
      expect(mockSupervisors, hasLength(12));
      expect(mockLocations, hasLength(15));
      expect(mockAssignments, hasLength(68));
    });
  });

  group('validateRoster on the real seed', () {
    final report = validateRoster(
      students: mockStudents,
      supervisors: mockSupervisors,
      locations: mockLocations,
      assignments: mockAssignments,
      links: demoAccountLinks,
    );

    List<RosterIssue> byCode(String code) =>
        report.issues.where((i) => i.code == code).toList();

    test('surfaces the 15 missing student contacts as errors', () {
      final missing = byCode('student-missing-contact');
      expect(missing, hasLength(15));
      expect(
        missing.map((i) => i.entityId).toSet(),
        {
          'STU-006',
          'STU-011',
          'STU-018',
          'STU-023',
          'STU-027',
          'STU-032',
          'STU-036',
          'STU-040',
          'STU-044',
          'STU-048',
          'STU-052',
          'STU-056',
          'STU-059',
          'STU-063',
          'STU-067',
        },
      );
    });

    test('fails the core checks until contacts are completed', () {
      expect(report.passesCoreChecks, isFalse);
      expect(report.count(RosterIssueSeverity.error),
          byCode('student-missing-contact').length);
    });

    test('every student and supervisor still needs an account link', () {
      expect(byCode('student-unlinked-account'), hasLength(67));
      expect(byCode('supervisor-unlinked-account'), hasLength(11));
    });

    test('flags the off-duty supervisor still carrying students', () {
      final offDuty = byCode('offduty-supervisor-with-students');
      expect(offDuty, hasLength(1));
      expect(offDuty.single.entityId, 'SV-10');
    });

    test('all locations still need official coordinates', () {
      expect(byCode('location-missing-coordinates'), hasLength(15));
    });

    test('every assignment resolves against the directory', () {
      expect(byCode('assignment-unknown-student'), isEmpty);
      expect(byCode('assignment-unknown-location'), isEmpty);
      expect(byCode('assignment-unknown-supervisor'), isEmpty);
      expect(byCode('assignment-missing-work-description'), isEmpty);
      expect(byCode('assignment-missing-windows'), isEmpty);
    });

    test('all 68 students are assigned', () {
      expect(byCode('student-without-assignment'), isEmpty);
    });

    test('roll numbers are unique', () {
      expect(byCode('duplicate-roll-number'), isEmpty);
    });

    test('supervisor emails are recorded but await college confirmation', () {
      expect(byCode('supervisor-email-unconfirmed'), hasLength(12));
      expect(byCode('supervisor-missing-email'), isEmpty);
    });
  });

  group('validateRoster on a healthy synthetic roster', () {
    test('passes core checks when data is complete', () {
      const student = Student(
        id: 'STU-OK1',
        name: 'Complete Student',
        rollNumber: '24XX001',
        contact: '+91 90000 00001',
        department: 'CS',
        className: 'SE-A',
      );
      const location = Location(
        id: 'LOC-OK',
        name: 'Library',
        latitude: 19.5,
        longitude: 74.3,
        status: LocationStatus.active,
      );
      const supervisor = Supervisor(
        id: 'SV-OK',
        name: 'Mr. Supervisor',
        email: 'sv.ok@college.edu.in',
        contact: '+91 90000 00002',
        assignedLocationIds: ['LOC-OK'],
        status: SupervisorStatus.onDuty,
      );
      final assignment = Assignment(
        id: 'ASN-OK1',
        studentId: 'STU-OK1',
        locationId: 'LOC-OK',
        supervisorId: 'SV-OK',
        workDescription: 'Library desk duty',
        shiftWindows: const [
          ShiftWindow(start: Duration(hours: 17), end: Duration(hours: 20)),
        ],
        effectiveFrom: DateTime(2026, 1, 1),
        status: AssignmentStatus.active,
      );
      const links = [
        AccountLink(
          userId: 'u-ok-1',
          role: UserRole.student,
          entityId: 'STU-OK1',
        ),
        AccountLink(userId: 'u-ok-2', role: UserRole.supervisor, entityId: 'SV-OK'),
      ];

      final report = validateRoster(
        students: const [student],
        supervisors: const [supervisor],
        locations: const [location],
        assignments: [assignment],
        links: links,
      );

      expect(report.count(RosterIssueSeverity.error), 0);
      expect(report.passesCoreChecks, isTrue);
    });
  });
}