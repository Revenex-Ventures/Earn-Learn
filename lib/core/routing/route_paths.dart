/// Centralized route path strings.
class RoutePaths {
  const RoutePaths._();

  static const splash = '/';
  static const auth = '/auth';
  static const demo = '/demo';

  // Student (Home, Attendance, Assignment, Profile)
  static const studentHome = '/student';
  static const studentAttendance = '/student/attendance';
  static const studentAssignment = '/student/assignment';
  static const studentProfile = '/student/profile';

  // Supervisor (Today, Students, Attendance review, Profile)
  static const supervisorHome = '/supervisor';
  static const supervisorDashboard = supervisorHome;
  static const supervisorStudents = '/supervisor/students';
  static const supervisorAttendance = '/supervisor/attendance';
  static const supervisorApprovals = supervisorAttendance;
  static const supervisorProfile = '/supervisor/profile';
  static const supervisorStudentDetail = '/supervisor/students/:studentId';

  // Admin (Overview, Manage hub, Reports, More/Governance on phones;
  // full 9 destinations on wide rails)
  static const adminOverview = '/admin';
  static const adminManage = '/admin/manage';
  static const adminStudents = '/admin/students';
  static const adminStudentDetail = '/admin/students/:studentId';
  static const adminSupervisors = '/admin/supervisors';
  static const adminAssignments = '/admin/assignments';
  static const adminLocations = '/admin/locations';
  static const adminLocationDetail = '/admin/locations/:locationId';
  static const adminCalendar = '/admin/calendar';
  static const adminPayroll = '/admin/payroll';
  static const adminReports = '/admin/reports';
  static const adminProfile = '/admin/profile';
  static const adminMore = '/admin/more';
}