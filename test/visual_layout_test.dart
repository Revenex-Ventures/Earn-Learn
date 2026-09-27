import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:earn_and_learn/app.dart';
import 'package:earn_and_learn/core/routing/app_router.dart';
import 'package:earn_and_learn/core/routing/route_paths.dart';
import 'package:earn_and_learn/core/models/user_role.dart';
import 'package:earn_and_learn/features/auth/auth_session.dart';
import 'package:earn_and_learn/shared/mock_data/mock_data.dart';

/// Instrumentation-based visual QA.
///
/// Visits every screen of the real app at phone and tablet widths and
/// asserts no layout exception (which would surface a RenderFlex overflow or
/// clipping) is thrown while rendering.
class _LayoutProbe {
  const _LayoutProbe(this.size);

  final Size size;

  String get label => '${size.width.toInt()}x${size.height.toInt()}dp';
}

const _phone = _LayoutProbe(Size(393, 852));
const _narrowPhone = _LayoutProbe(Size(320, 640));
const _tablet = _LayoutProbe(Size(840, 1200));

const _studentRoutes = [
  RoutePaths.studentHome,
  RoutePaths.studentAttendance,
  RoutePaths.studentAssignment,
  RoutePaths.studentProfile,
];

const _supervisorRoutes = [
  RoutePaths.supervisorHome,
  RoutePaths.supervisorStudents,
  RoutePaths.supervisorAttendance,
  RoutePaths.supervisorProfile,
];

const _adminRoutes = [
  RoutePaths.adminOverview,
  RoutePaths.adminManage,
  RoutePaths.adminStudents,
  RoutePaths.adminSupervisors,
  RoutePaths.adminAssignments,
  RoutePaths.adminLocations,
  RoutePaths.adminCalendar,
  RoutePaths.adminPayroll,
  RoutePaths.adminReports,
  RoutePaths.adminProfile,
  RoutePaths.adminMore,
];

void main() {
  for (final probe in const [_phone, _narrowPhone, _tablet]) {
    group('no overflow or clipping at ${probe.label}', () {
      testWidgets('every screen renders without a layout exception',
          (tester) async {
        tester.view.physicalSize = probe.size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        addTearDown(tester.view.resetPhysicalSize);
        // The local credential gate blocks shell routes unless the matching
        // role has signed in; authenticate per section as we sweep it.
        addTearDown(AuthSession.signOut);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final GoRouter router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const EarnLearnApp(),
      ),
    );
        // Splash auto-navigates to role selection after ~2s.
        await tester.pumpAndSettle(const Duration(seconds: 2));
        expect(tester.takeException(), isNull, reason: 'Splash raised an exception');

        // Phone uses a bottom bar, tablet a rail.
        AuthSession.signIn(UserRole.student);
        await visit(tester, router, RoutePaths.studentHome);
        if (probe.size.width < 600) {
          expect(find.byType(NavigationBar), findsOneWidget);
          expect(find.byType(NavigationRail), findsNothing);
        } else {
          expect(find.byType(NavigationRail), findsOneWidget);
          expect(find.byType(NavigationBar), findsNothing);
        }

        for (final path in _studentRoutes) {
          await visit(tester, router, path);
        }

        for (final path in _supervisorRoutes) {
          AuthSession.signIn(UserRole.supervisor);
          await visit(tester, router, path);
        }

        // Supervisor student detail uses the demo student id.
        AuthSession.signIn(UserRole.supervisor);
        await visit(
          tester,
          router,
          '${RoutePaths.supervisorStudents}/${mockStudents.first.id}',
        );

        // Admin detail routes use the demo student and location ids.
        AuthSession.signIn(UserRole.admin);
        await visit(
          tester,
          router,
          '${RoutePaths.adminStudents}/${mockStudents.first.id}',
        );
        await visit(
          tester,
          router,
          '${RoutePaths.adminLocations}/${mockLocations.first.id}',
        );

        for (final path in _adminRoutes) {
          await visit(tester, router, path);
        }
      });
    });
  }
}

Future<void> visit(
  WidgetTester tester,
  GoRouter router,
  String path,
) async {
  await tester.pumpAndSettle();
  router.go(path);
  await tester.pumpAndSettle();
  final errorDetails = <FlutterErrorDetails>[];
  tester.binding.platformDispatcher.onError =
      (Object error, StackTrace stack) => true;
  final oldError = FlutterError.onError;
  FlutterError.onError = (details) {
    errorDetails.add(details);
    oldError?.call(details);
  };
  await tester.pumpAndSettle();
  final exception = tester.takeException();
  if (exception != null) {
    debugPrint('>>> Screen $path raised: $exception');
    if (exception is FlutterError) {
      FlutterError.dumpErrorToConsole(
        FlutterErrorDetails(exception: exception, library: 'layout sweep'),
      );
    }
  }
  FlutterError.onError = oldError;
  expect(exception, isNull, reason: 'Screen $path raised a layout exception');
}