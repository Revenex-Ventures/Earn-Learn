import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_colors.dart';
import '../student/home_screen.dart';
import 'app_shell.dart';

class StudentShell extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    // Watching here keeps the student duty data alive across every student tab,
    // so the center action button can start the real Check-In / Check-Out flow
    // (not just navigate) from any page in this section.
    ref.watch(studentHomeProvider);

    return AppShell(
      currentIndex: _currentIndex(context),
      onDestinationSelected: (index) => _onTap(context, index),
      destinations: _destinations,
      fabIcon: Icons.power_settings_new,
      fabGradient: AppColors.terraGrad,
      onFab: () => _onFab(context, ref),
      railHeader: const ShellMark(label: 'Student'),
      child: child,
    );
  }

  /// The center power button performs the student's live duty action. When the
  /// duty data is ready it opens the Check-In/Check-Out evidence sheet directly;
  /// until it has loaded (or on error) it falls back to the Home tab, which
  /// surfaces the loading/error state.
  void _onFab(BuildContext context, WidgetRef ref) {
    final data = ref.read(studentHomeProvider).valueOrNull;
    if (data != null) {
      studentPrimaryAction(context, ref, data);
    } else {
      context.go('/student');
    }
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
