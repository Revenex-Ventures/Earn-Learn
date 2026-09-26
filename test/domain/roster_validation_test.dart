import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/data/data.dart';
import 'package:earn_and_learn/domain/domain.dart';
import 'package:earn_and_learn/shared/mock_data/mock_data.dart';

void main() {
  group('seed roster counts', () {
    test('the workbook snapshot has the authenticated totals', () {
      expect(mockStudents, hasLength(68));
      expect(mockSupervisors, hasLength(10));
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

    test('surfaces the 60 students the sheet leaves without a contact', () {
      final missing = byCode('student-missing-contact');
      expect(missing, hasLength(60));
      // The sheet only records contacts for the 8 office-location students.
      expect(
        missing.map((i) => i.entityId).toSet(),
        {
          for (final s in mockStudents)
            if (s.contact == null) s.id,
        },
      );
    });

    test('fails core checks while the recorded gaps are unresolved', () {
      expect(report.passesCoreChecks, isFalse);
      // 60 contacts + 10 supervisor emails + 3 blank shifts + 4 unnamed
      // supervisors. Every one is a real gap in the official sheet.
      expect(report.count(RosterIssueSeverity.error), 77);
      expect(byCode('student-missing-contact'), hasLength(60));
      expect(byCode('supervisor-missing-email'), hasLength(10));
      expect(byCode('assignment-missing-windows'), hasLength(3));
      expect(byCode('assignment-unassigned-supervisor'), hasLength(4));
    });

    test('every student and supervisor still needs an account link', () {
      // Only STU-001 and SV-01 are bound to the demo identities.
      expect(byCode('student-unlinked-account'), hasLength(67));
      expect(byCode('supervisor-unlinked-account'), hasLength(9));
    });

    test('no supervisor is off duty while carrying students', () {
      expect(
        mockSupervisors.every((s) => s.status == SupervisorStatus.onDuty),
        true,
      );
      expect(byCode('offduty-supervisor-with-students'), isEmpty);
    });

    test('all locations still need official coordinates', () {
      expect(byCode('location-missing-coordinates'), hasLength(15));
    });

    test('every assignment resolves against the directory', () {
      expect(byCode('assignment-unknown-student'), isEmpty);
      expect(byCode('assignment-unknown-location'), isEmpty);
      expect(byCode('assignment-unknown-supervisor'), isEmpty);
      expect(byCode('assignment-missing-work-description'), isEmpty);
      expect(byCode('supervisor-unknown-location'), isEmpty);
    });

    test('blank library shifts are reported, never silently accepted', () {
      final blank = byCode('assignment-missing-windows');
      expect(
        blank.map((i) => i.entityId).toSet(),
        {'ASN-057', 'ASN-058', 'ASN-059'},
      );
    });

    test('allotments the sheet leaves unassigned name the affected locations', () {
      final unassigned = byCode('assignment-unassigned-supervisor');
      expect(
        unassigned.map((i) => i.entityId).toSet(),
        {'ASN-060', 'ASN-064', 'ASN-065', 'ASN-066'},
      );
      final locationsOf = {
        for (final a in mockAssignments)
          if (a.supervisorId.isEmpty) a.id: a.locationName,
      };
      expect(locationsOf.values.toSet(), {
        'Civil Lab',
        'Dispensary',
        'Incubation',
      });
    });

    test('all 68 students are assigned', () {
      expect(byCode('student-without-assignment'), isEmpty);
    });

    test('roll numbers are unique', () {
      expect(byCode('duplicate-roll-number'), isEmpty);
    });

    test('no supervisor email is on record in the official sheet', () {
      expect(byCode('supervisor-missing-email'), hasLength(10));
      expect(byCode('supervisor-email-unconfirmed'), isEmpty);
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