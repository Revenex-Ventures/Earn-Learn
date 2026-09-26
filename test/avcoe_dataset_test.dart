import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/shared/mock_data/avcoe_seed_data.dart';
import 'package:earn_and_learn/shared/mock_data/data_quality_report.dart';

/// Allotments whose time slots are blank in the official sheet. These must be
/// represented honestly as "Shift unassigned" with 0 planned hours instead of
/// being padded with invented shifts.
const List<String> kShiftlessAssignmentIds = ['ASN-057', 'ASN-058', 'ASN-059'];

/// Allotments at locations the sheet leaves without a named supervisor.
const List<String> kUnassignedSupervisorIds = [
  'ASN-060',
  'ASN-064',
  'ASN-065',
  'ASN-066',
];

void main() {
  group('AVCOE Authentic Dataset Integrity', () {
    test('contains exact 15 official institutional locations', () {
      expect(AvcoeSeedData.locations.length, 15);
      final names = AvcoeSeedData.locations.map((l) => l.name).toList();
      expect(names, contains('Library'));
      expect(names, contains('Kalsubai Hostel (Old)'));
      expect(names, contains('Krushnavanti Hostel (New)'));
      expect(names, contains('Study Hall'));
      expect(names, contains('Play Ground and Gardening'));
      expect(names, contains('Harishchandragadh Hostel'));
      expect(names, contains('Sinhagad Hostel'));
      expect(names, contains('Sajjangad Hostel'));
      expect(names, contains('Civil Lab'));
      expect(names, contains('SDO'));
      expect(names, contains('Gymkhana'));
      expect(names, contains('Dispensary'));
      expect(names, contains('Incubation'));
      expect(names, contains('Guest House'));
      expect(names, contains('TPO Office'));
    });

    test('contains exact 10 named institutional supervisors', () {
      expect(AvcoeSeedData.supervisors.length, 10);
      final names = AvcoeSeedData.supervisors.map((s) => s.name).toSet();
      expect(names.length, 10, reason: 'supervisor names must be unique');
      expect(AvcoeSeedData.supervisors.every((s) => s.name.isNotEmpty), true);
      expect(
        AvcoeSeedData.supervisors.every((s) => s.department != null),
        true,
        reason: 'every named supervisor has a department in the sheet',
      );
    });

    test('contains exact 68 student records with explicit missing fields', () {
      expect(AvcoeSeedData.students.length, 68);
      expect(AvcoeSeedData.students.every((s) => s.name.isNotEmpty), true);
    });

    test('every student carries a unique sequential Earn & Learn ID', () {
      final rolls = AvcoeSeedData.students.map((s) => s.rollNumber).toList();
      expect(rolls.toSet().length, 68, reason: 'roll numbers must be unique');
      expect(
        rolls,
        List.generate(
          68,
          (i) => 'EL2627-${(i + 1).toString().padLeft(3, '0')}',
        ),
        reason:
            'the sheet gives no roll numbers, so enrolment IDs must be '
            'contiguous EL2627-001..EL2627-068',
      );
      expect(AvcoeSeedData.students.map((s) => s.id).toSet().length, 68);
    });

    test('missing contact, department and class stay explicit nulls', () {
      final students = AvcoeSeedData.students;
      // Only the 8 office-location students have a contact in the sheet.
      expect(students.where((s) => s.contact == null).length, 60);
      expect(students.where((s) => s.department == null).length, 60);
      expect(students.where((s) => s.className == null).length, 60);

      final withContact = students
          .where((s) => s.contact != null)
          .map((s) => s.id)
          .toList();
      expect(withContact, [
        'STU-061',
        'STU-062',
        'STU-063',
        'STU-064',
        'STU-065',
        'STU-066',
        'STU-067',
        'STU-068',
      ]);

      // No empty-string stand-ins for absent data.
      expect(
        students.any(
          (s) => s.contact == '' || s.department == '' || s.className == '',
        ),
        false,
      );
    });

    test('assignments respect variable durations and 40h ceiling', () {
      final assignments = AvcoeSeedData.createAssignments();
      expect(assignments.length, 68);

      for (final a in assignments) {
        expect(a.maxMonthlyHours, 40);
        expect(a.plannedHoursPerDay, lessThanOrEqualTo(40));
      }

      final timed = assignments
          .where((a) => a.shiftWindows.isNotEmpty)
          .toList();
      expect(timed.length, 65);
      for (final a in timed) {
        expect(a.plannedHoursPerDay, greaterThan(0));
      }
    });

    test('blank library shifts are reported as unassigned, never invented', () {
      final assignments = AvcoeSeedData.createAssignments();
      final shiftless = assignments
          .where((a) => a.shiftWindows.isEmpty)
          .map((a) => a.id)
          .toList();
      expect(shiftless, kShiftlessAssignmentIds);
      expect(
        assignments
            .where((a) => a.shiftWindows.isEmpty)
            .every(
              (a) =>
                  a.plannedHoursPerDay == 0 &&
                  a.shiftLabel == 'Shift unassigned',
            ),
        true,
      );
    });

    test('supports split shifts exactly where the sheet splits them', () {
      final splitShifts = AvcoeSeedData.createAssignments()
          .where((a) => a.isSplitShift)
          .toList();
      expect(splitShifts.length, 1);
      expect(splitShifts.single.id, 'ASN-056');
      expect(splitShifts.single.shiftWindows.length, 2);
      expect(splitShifts.single.plannedHoursPerDay, 2.0);
    });

    test('locations without a named supervisor stay unstaffed and flagged', () {
      final unstaffed = AvcoeSeedData.locations
          .where((l) => l.supervisorIds.isEmpty)
          .map((l) => l.id)
          .toList();
      expect(unstaffed, ['LOC-09', 'LOC-12', 'LOC-13']);

      final assignments = AvcoeSeedData.createAssignments();
      final unassigned = assignments
          .where((a) => a.supervisorId.isEmpty)
          .map((a) => a.id)
          .toList();
      expect(unassigned, kUnassignedSupervisorIds);
      expect(
        assignments
            .where((a) => a.supervisorId.isEmpty)
            .every((a) => a.supervisorName == 'Not assigned'),
        true,
      );
    });

    test('no fabricated geofence coordinates are set', () {
      expect(
        AvcoeSeedData.locations.any(
          (l) => l.latitude != null || l.longitude != null,
        ),
        false,
        reason:
            'coordinates must stay null so check-in shows '
            '"Configuration required" until real values are provided',
      );
    });

    test('every reference resolves to a real record', () {
      final locationIds = AvcoeSeedData.locations.map((l) => l.id).toSet();
      final supervisorIds = AvcoeSeedData.supervisors.map((s) => s.id).toSet();
      final studentIds = AvcoeSeedData.students.map((s) => s.id).toSet();
      final assignments = AvcoeSeedData.createAssignments();

      for (final a in assignments) {
        expect(locationIds, contains(a.locationId), reason: a.id);
        expect(studentIds, contains(a.studentId), reason: a.id);
        if (a.supervisorId.isNotEmpty) {
          expect(supervisorIds, contains(a.supervisorId), reason: a.id);
        }
        expect(
          AvcoeSeedData.locations.firstWhere((l) => l.id == a.locationId).name,
          a.locationName,
          reason: '${a.id} must display the official location name',
        );
      }

      // 1:1 student-to-allotment coverage.
      expect(assignments.map((a) => a.studentId).toSet().length, 68);
      expect(assignments.map((a) => a.id).toSet().length, 68);
      expect(
        assignments.every(
          (a) => a.effectiveTo == null && a.status.name == 'active',
        ),
        true,
      );
    });

    test('supervisor and location cross-links stay consistent', () {
      final locations = AvcoeSeedData.locations;
      final supervisors = AvcoeSeedData.supervisors;
      final locationIds = locations.map((l) => l.id).toSet();
      final supervisorIds = supervisors.map((s) => s.id).toSet();

      for (final s in supervisors) {
        for (final id in s.assignedLocationIds) {
          expect(locationIds, contains(id), reason: '${s.id} -> $id');
          expect(
            locations.firstWhere((l) => l.id == id).supervisorIds,
            contains(s.id),
            reason: '${s.id} -> $id must be mirrored on the location',
          );
        }
      }
      for (final l in locations) {
        for (final id in l.supervisorIds) {
          expect(supervisorIds, contains(id), reason: '${l.id} -> $id');
          expect(
            supervisors.firstWhere((s) => s.id == id).assignedLocationIds,
            contains(l.id),
            reason: '${l.id} -> $id must be mirrored on the supervisor',
          );
        }
      }
    });

    test('data quality report validates strict institutional fidelity', () {
      final report = DataQualityReport.generate();
      expect(report['totalStudents'], 68);
      expect(report['totalLocations'], 15);
      expect(report['totalSupervisors'], 10);
      expect(report['totalAssignments'], 68);
      expect(report['missingContactsExplicit'], 60);
      expect(report['missingDepartmentsExplicit'], 60);
      expect(report['missingClassesExplicit'], 60);
      expect(report['splitShiftsCount'], 1);
      expect(report['unassignedShiftsCount'], 3);
      expect(report['totalPlannedHoursDaily'], 185.0);
      expect(report['fidelityStatus'], contains('0 Fabricated Values'));
    });
  });
}
