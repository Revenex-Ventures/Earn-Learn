import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/data/data.dart';
import 'package:earn_and_learn/domain/domain.dart';
import 'package:earn_and_learn/features/supervisor_admin/locations_screen.dart';

class _StubLocationRepository implements LocationRepository {
  _StubLocationRepository(this._locations);

  final List<Location> _locations;

  @override
  Future<List<Location>> all() async => _locations;

  @override
  Future<Location?> byId(String id) async =>
      _locations.where((l) => l.id == id).firstOrNull;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} unused');
}

class _StubAssignmentRepository implements AssignmentRepository {
  @override
  Future<List<Assignment>> all() async => const [];

  @override
  Future<Assignment?> forStudent(String studentId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} unused');
}

const _staffed = Location(
  id: 'LOC-01',
  name: 'Main Library',
  status: LocationStatus.active,
  supervisorIds: ['SV-01'],
);

const _alsoStaffed = Location(
  id: 'LOC-02',
  name: 'Gymkhana',
  status: LocationStatus.active,
  supervisorIds: ['SV-02', 'SV-03'],
);

const _unstaffed = Location(
  id: 'LOC-03',
  name: 'Guest House',
  status: LocationStatus.attention,
);

const _secondUnstaffed = Location(
  id: 'LOC-04',
  name: 'Workshop',
  status: LocationStatus.inactive,
);

Widget _host(List<Location> locations) {
  return ProviderScope(
    overrides: [
      locationRepositoryProvider.overrideWithValue(
        _StubLocationRepository(locations),
      ),
      assignmentRepositoryProvider.overrideWithValue(
        _StubAssignmentRepository(),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(body: AdminLocationsScreen()),
    ),
  );
}

void main() {
  group('Admin locations grouping', () {
    testWidgets('separates unstaffed from supervised work areas',
        (tester) async {
      await tester.pumpWidget(
        _host(const [_staffed, _alsoStaffed, _unstaffed, _secondUnstaffed]),
      );
      await tester.pumpAndSettle();

      expect(find.text('UNSTAFFED'), findsOneWidget);
      expect(find.text('STAFFED'), findsOneWidget);
      expect(find.text('Needs a supervisor'), findsOneWidget);
      expect(find.text('Supervised'), findsOneWidget);
    });

    testWidgets('an unstaffed area says so on its own row', (tester) async {
      await tester.pumpWidget(_host(const [_unstaffed]));
      await tester.pumpAndSettle();

      expect(find.text('No supervisor assigned'), findsOneWidget);
    });

    testWidgets('a staffed area reports its supervisor count, not a warning',
        (tester) async {
      await tester.pumpWidget(_host(const [_staffed, _alsoStaffed]));
      await tester.pumpAndSettle();

      expect(find.text('No supervisor assigned'), findsNothing);
      expect(find.text('1 supervisor'), findsOneWidget);
      expect(find.text('2 supervisors'), findsOneWidget);
    });

    testWidgets('the empty state is honest about which group is full',
        (tester) async {
      await tester.pumpWidget(_host(const [_staffed]));
      await tester.pumpAndSettle();

      expect(
        find.text('Every work location has a supervisor assigned.'),
        findsOneWidget,
      );
      expect(
        find.text('No supervised locations match this search.'),
        findsNothing,
      );
    });

    testWidgets('group counts are shown', (tester) async {
      await tester.pumpWidget(
        _host(const [_staffed, _alsoStaffed, _unstaffed]),
      );
      await tester.pumpAndSettle();

      // Two supervised, one not.
      final counts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      expect(counts.where((c) => c == '2').length, greaterThanOrEqualTo(1));
      expect(counts.where((c) => c == '1').length, greaterThanOrEqualTo(1));
    });

    testWidgets('a search that matches nothing shows the empty state',
        (tester) async {
      await tester.pumpWidget(_host(const [_staffed]));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.pumpAndSettle();

      expect(find.text('No locations found'), findsOneWidget);
    });
  });
}
