import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_shell.dart';

class StudentShell extends StatelessWidget {
  const StudentShell({
    super.key,
    required this.child,
  });

  final Widget child;

  static const _destinations = [
    AppShellDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
    AppShellDestination(
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      label: 'Attendance',
    ),
    AppShellDestination(
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment,
      label: 'Assignment',
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
      destinations: _destinations,
      railHeader: const ShellMark(label: 'Student'),
      child: child,
    );
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/student/attendance')) return 1;
    if (location.startsWith('/student/assignment')) return 2;
    if (location.startsWith('/student/profile')) return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/student');
        break;
      case 1:
        context.go('/student/attendance');
        break;
      case 2:
        context.go('/student/assignment');
        break;
      case 3:
        context.go('/student/profile');
        break;
    }
  }
}