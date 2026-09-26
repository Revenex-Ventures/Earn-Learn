import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_paths.dart';
import '../../data/data.dart';
import 'app_shell.dart';

/// Open verification count for the Reviews badge, derived from the active
/// (mock or Firestore-backed) verification repository — never a hard-coded
/// fixture.
final supervisorOpenCountProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(verificationRepositoryProvider).openCount();
});

class SupervisorShell extends ConsumerWidget {
  const SupervisorShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final openCount = ref.watch(supervisorOpenCountProvider).valueOrNull ?? 0;

    return AppShell(
      currentIndex: _currentIndex(context),
      onDestinationSelected: (index) => _onTap(context, index),
      destinations: [
        const AppShellDestination(
          icon: Icons.today_outlined,
          selectedIcon: Icons.today,
          label: 'Today',
        ),
        const AppShellDestination(
          icon: Icons.people_outlined,
          selectedIcon: Icons.people,
          label: 'Students',
        ),
        AppShellDestination(
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check,
          label: 'Reviews',
          badgeCount: openCount,
        ),
        const AppShellDestination(
          icon: Icons.person_outlined,
          selectedIcon: Icons.person,
          label: 'Profile',
        ),
      ],
      railHeader: const ShellMark(label: 'Supervisor'),
      child: child,
    );
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith(RoutePaths.supervisorStudents)) return 1;
    if (location.startsWith(RoutePaths.supervisorAttendance)) return 2;
    if (location.startsWith(RoutePaths.supervisorProfile)) return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(RoutePaths.supervisorHome);
        break;
      case 1:
        context.go(RoutePaths.supervisorStudents);
        break;
      case 2:
        context.go(RoutePaths.supervisorAttendance);
        break;
      case 3:
        context.go(RoutePaths.supervisorProfile);
        break;
    }
  }
}