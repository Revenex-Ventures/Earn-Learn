import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/role_selection/role_selection_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/demo/demo_scenario_screen.dart';
import '../../features/shell/student_shell.dart';
import '../../features/shell/supervisor_admin_shell.dart';
import '../../features/shell/supervisor_shell.dart';
import '../../features/student/assignment_screen.dart';
import '../../features/student/attendance_screen.dart';
import '../../features/student/home_screen.dart';
import '../../features/student/profile_screen.dart';
import '../../features/supervisor/attendance_screen.dart';
import '../../features/supervisor/profile_screen.dart';
import '../../features/supervisor/student_detail_screen.dart';
import '../../features/supervisor/students_screen.dart';
import '../../features/supervisor/today_screen.dart';
import '../../features/supervisor_admin/assignments_screen.dart';
import '../../features/supervisor_admin/calendar_screen.dart';
import '../../features/supervisor_admin/location_detail_screen.dart';
import '../../features/supervisor_admin/locations_screen.dart';
import '../../features/supervisor_admin/manage_screen.dart';
import '../../features/supervisor_admin/more_screen.dart';
import '../../features/supervisor_admin/overview_screen.dart';
import '../../features/supervisor_admin/payroll_screen.dart';
import '../../features/supervisor_admin/profile_screen.dart';
import '../../features/supervisor_admin/reports_screen.dart';
import '../../features/supervisor_admin/student_detail_screen.dart';
import '../../features/supervisor_admin/students_screen.dart';
import '../../features/supervisor_admin/supervisors_screen.dart';
import 'route_names.dart';
import 'route_paths.dart';

/// Central router configuration using go_router.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: RoutePaths.splash,
    routes: [
      // Splash screen
      GoRoute(
        path: RoutePaths.splash,
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Role selection / Auth entry point
      GoRoute(
        path: RoutePaths.auth,
        name: RouteNames.auth,
        builder: (context, state) => const RoleSelectionScreen(),
      ),

      // Live isolated end-to-end demo flow
      GoRoute(
        path: RoutePaths.demo,
        name: RouteNames.demo,
        builder: (context, state) => const DemoScenarioScreen(),
      ),

      // Student shell
      ShellRoute(
        builder: (context, state, child) => StudentShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.studentHome,
            name: RouteNames.studentHome,
            builder: (context, state) => const StudentHomeScreen(),
          ),
          GoRoute(
            path: RoutePaths.studentAttendance,
            name: RouteNames.studentAttendance,
            builder: (context, state) => const StudentAttendanceScreen(),
          ),
          GoRoute(
            path: RoutePaths.studentAssignment,
            name: RouteNames.studentAssignment,
            builder: (context, state) => const StudentAssignmentScreen(),
          ),
          GoRoute(
            path: RoutePaths.studentProfile,
            name: RouteNames.studentProfile,
            builder: (context, state) => const StudentProfileScreen(),
          ),
        ],
      ),

      // Supervisor shell
      ShellRoute(
        builder: (context, state, child) => SupervisorShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.supervisorHome,
            name: RouteNames.supervisorHome,
            builder: (context, state) => const SupervisorTodayScreen(),
          ),
          GoRoute(
            path: RoutePaths.supervisorStudents,
            name: RouteNames.supervisorStudents,
            builder: (context, state) => const SupervisorStudentsScreen(),
          ),
          GoRoute(
            path: RoutePaths.supervisorStudentDetail,
            name: RouteNames.supervisorStudentDetail,
            builder: (context, state) => SupervisorStudentDetailScreen(
              studentId: state.pathParameters['studentId'] ?? '',
            ),
          ),
          GoRoute(
            path: RoutePaths.supervisorAttendance,
            name: RouteNames.supervisorAttendance,
            builder: (context, state) => const SupervisorAttendanceScreen(),
          ),
          GoRoute(
            path: RoutePaths.supervisorProfile,
            name: RouteNames.supervisorProfile,
            builder: (context, state) => const SupervisorProfileScreen(),
          ),
        ],
      ),

      // Admin shell
      ShellRoute(
        builder: (context, state, child) => SupervisorAdminShell(child: child),
        routes: [
          GoRoute(
            path: RoutePaths.adminOverview,
            name: RouteNames.adminOverview,
            builder: (context, state) => const AdminOverviewScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminManage,
            name: RouteNames.adminManage,
            builder: (context, state) => const AdminManageScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminStudents,
            name: RouteNames.adminStudents,
            builder: (context, state) => const AdminStudentsScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminStudentDetail,
            name: RouteNames.adminStudentDetail,
            builder: (context, state) => AdminStudentDetailScreen(
              studentId: state.pathParameters['studentId'] ?? '',
            ),
          ),
          GoRoute(
            path: RoutePaths.adminSupervisors,
            name: RouteNames.adminSupervisors,
            builder: (context, state) => const AdminSupervisorsScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminAssignments,
            name: RouteNames.adminAssignments,
            builder: (context, state) => const AdminAssignmentsScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminLocations,
            name: RouteNames.adminLocations,
            builder: (context, state) => const AdminLocationsScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminLocationDetail,
            name: RouteNames.adminLocationDetail,
            builder: (context, state) => AdminLocationDetailScreen(
              locationId: state.pathParameters['locationId'] ?? '',
            ),
          ),
          GoRoute(
            path: RoutePaths.adminCalendar,
            name: RouteNames.adminCalendar,
            builder: (context, state) => const AdminCalendarScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminPayroll,
            name: RouteNames.adminPayroll,
            builder: (context, state) => const AdminPayrollScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminReports,
            name: RouteNames.adminReports,
            builder: (context, state) => const AdminReportsScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminProfile,
            name: RouteNames.adminProfile,
            builder: (context, state) => const AdminProfileScreen(),
          ),
          GoRoute(
            path: RoutePaths.adminMore,
            name: RouteNames.adminMore,
            builder: (context, state) => const AdminMoreScreen(),
          ),
        ],
      ),
    ],
  );

  return router;
});