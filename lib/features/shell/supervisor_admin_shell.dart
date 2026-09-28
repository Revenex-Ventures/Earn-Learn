import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/routing/route_paths.dart';
import 'app_shell.dart';

/// Program-office shell: Overview, Manage, Reports, More on the center-FAB bar,
/// with an espresso "＋" action that opens the Manage hub. Manage hosts the
/// directory hubs (Students, Supervisors, Locations, Assignments, Calendar) and
/// More hosts the governance tier (Payroll, Profile).
class SupervisorAdminShell extends StatelessWidget {
  const SupervisorAdminShell({
    super.key,
    required this.child,
  });

  final Widget child;

  static const _phoneDestinations = [
    AppShellDestination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Overview',
    ),
    AppShellDestination(
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view,
      label: 'Manage',
    ),
    AppShellDestination(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: 'Reports',
    ),
    AppShellDestination(
      icon: Icons.more_horiz_outlined,
      selectedIcon: Icons.more_horiz,
      label: 'More',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentIndex: _currentIndex(context),
      onDestinationSelected: (index) => _onTap(context, index),
      destinations: _phoneDestinations,
      fabIcon: Icons.add_rounded,
      fabGradient: AppColors.heroForest,
      onFab: () => context.go(RoutePaths.adminManage),
      railHeader: const ShellMark(label: 'Admin'),
      child: child,
    );
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    // Phone bar: 0 Overview, 1 Manage, 2 Reports, 3 More.
    final isManage = location.startsWith(RoutePaths.adminStudents) ||
        location.startsWith(RoutePaths.adminSupervisors) ||
        location.startsWith(RoutePaths.adminLocations) ||
        location.startsWith(RoutePaths.adminAssignments) ||
        location.startsWith(RoutePaths.adminCalendar) ||
        location.startsWith(RoutePaths.adminManage);
    if (isManage) return 1;
    if (location.startsWith(RoutePaths.adminReports)) return 2;
    if (location.startsWith(RoutePaths.adminPayroll) ||
        location.startsWith(RoutePaths.adminProfile) ||
        location.startsWith(RoutePaths.adminMore)) {
      return 3;
    }
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(RoutePaths.adminOverview);
        break;
      case 1:
        context.go(RoutePaths.adminManage);
        break;
      case 2:
        context.go(RoutePaths.adminReports);
        break;
      case 3:
        context.go(RoutePaths.adminMore);
        break;
    }
  }
}