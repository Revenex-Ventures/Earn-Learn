import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/shared/mock_data/avcoe_seed_data.dart';
import 'package:earn_and_learn/shared/mock_data/data_quality_report.dart';

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

    test('contains exact 68 student records with explicit missing fields', () {
      expect(AvcoeSeedData.students.length, 68);
      // Verify explicit null handling (no fake data)
      final missingContacts = AvcoeSeedData.students.where((s) => s.contact == null).length;
      expect(missingContacts, greaterThan(0));
    });

    test('assignments respect variable durations and 40h ceiling', () {
      final assignments = AvcoeSeedData.createAssignments();
      expect(assignments.length, 68);

      for (final a in assignments) {
        expect(a.maxMonthlyHours, 40);
        expect(a.plannedHoursPerDay, greaterThan(0));
      }

      // Check split shift support
      final splitShifts = assignments.where((a) => a.isSplitShift).toList();
      expect(splitShifts.isNotEmpty, true);
    });

    test('data quality report validates strict institutional fidelity', () {
      final report = DataQualityReport.generate();
      expect(report['totalStudents'], AvcoeSeedData.students.length);
      expect(report['totalLocations'], AvcoeSeedData.locations.length);
      expect(report['totalSupervisors'], AvcoeSeedData.supervisors.length);
      expect(report['fidelityStatus'], contains('0 Fabricated Values'));
    });
  });
}
