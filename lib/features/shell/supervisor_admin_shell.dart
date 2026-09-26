import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/route_paths.dart';
import 'app_shell.dart';

/// Program-office shell: Overview, Manage, Reports, More on the phone bar;
/// the full 9 destinations on wide rails. Manage hosts the directory hubs
/// (Students, Supervisors, Locations, Assignments, Calendar) and More hosts
/// the governance tier (Payroll, Profile) on phones.
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

  static const _railDestinations = [
    AppShellDestination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Overview',
    ),
    AppShellDestination(
      icon: Icons.school_outlined,
      selectedIcon: Icons.school,
      label: 'Students',
    ),
    AppShellDestination(
      icon: Icons.supervisor_account_outlined,
      selectedIcon: Icons.supervisor_account,
      label: 'Supervisors',
    ),
    AppShellDestination(
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment,
      label: 'Assignments',
    ),
    AppShellDestination(
      icon: Icons.location_on_outlined,
      selectedIcon: Icons.location_on,
      label: 'Locations',
    ),
    AppShellDestination(
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note,
      label: 'Calendar',
    ),
    AppShellDestination(
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
      label: 'Payroll',
    ),
    AppShellDestination(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: 'Reports',
    ),
    AppShellDestination(
      icon: Icons.person_outlined,
      selectedIcon: Icons.person,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentIndex: _currentIndex(context),
      onDestinationSelected: (index) => _onTap(context, index),
      destinations: _phoneDestinations,
      railDestinations: _railDestinations,
      railHeader: const ShellMark(label: 'Admin'),
      child: child,
    );
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final wide = MediaQuery.sizeOf(context).width >= AppShell.breakpoint;
    if (!wide) {
      // Phone bar: 0 Overview, 1 Manage, 2 Reports, 3 More.
      final isManage =
          location.startsWith(RoutePaths.adminStudents) ||
          location.startsWith(RoutePaths.adminSupervisors) ||
          location.startsWith(RoutePaths.adminLocations) ||
          location.startsWith(RoutePaths.adminAssignments) ||
          location.startsWith(RoutePaths.adminCalendar);
      if (isManage) return 1;
      if (location.startsWith(RoutePaths.adminReports)) return 2;
      if (location.startsWith(RoutePaths.adminPayroll) ||
          location.startsWith(RoutePaths.adminProfile) ||
          location.startsWith(RoutePaths.adminMore)) {
        return 3;
      }
      return 0;
    }
    if (location.startsWith(RoutePaths.adminStudents)) return 1;
    if (location.startsWith(RoutePaths.adminSupervisors)) return 2;
    if (location.startsWith(RoutePaths.adminAssignments)) return 3;
    if (location.startsWith(RoutePaths.adminLocations)) return 4;
    if (location.startsWith(RoutePaths.adminCalendar)) return 5;
    if (location.startsWith(RoutePaths.adminPayroll)) return 6;
    if (location.startsWith(RoutePaths.adminReports)) return 7;
    if (location.startsWith(RoutePaths.adminProfile)) return 8;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    final wide = MediaQuery.sizeOf(context).width >= AppShell.breakpoint;
    if (!wide) {
      // Phone bar: 0 Overview, 1 Manage, 2 Reports, 3 More.
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
      return;
    }
    switch (index) {
      case 0:
        context.go(RoutePaths.adminOverview);
        break;
      case 1:
        context.go(RoutePaths.adminStudents);
        break;
      case 2:
        context.go(RoutePaths.adminSupervisors);
        break;
      case 3:
        context.go(RoutePaths.adminAssignments);
        break;
      case 4:
        context.go(RoutePaths.adminLocations);
        break;
      case 5:
        context.go(RoutePaths.adminCalendar);
        break;
      case 6:
        context.go(RoutePaths.adminPayroll);
        break;
      case 7:
        context.go(RoutePaths.adminReports);
        break;
      case 8:
        context.go(RoutePaths.adminProfile);
        break;
    }
  }
}