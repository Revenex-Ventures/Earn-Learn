/// Centralized route names for type-safe navigation.
class RouteNames {
  const RouteNames._();

  static const splash = 'splash';
  static const auth = 'auth';
  static const demo = 'demo';

  // Student
  static const studentHome = 'studentHome';
  static const studentAttendance = 'studentAttendance';
  static const studentAssignment = 'studentAssignment';
  static const studentProfile = 'studentProfile';

  // Supervisor
  static const supervisorHome = 'supervisorHome';
  static const supervisorDashboard = supervisorHome;
  static const supervisorStudents = 'supervisorStudents';
  static const supervisorAttendance = 'supervisorAttendance';
  static const supervisorApprovals = supervisorAttendance;
  static const supervisorProfile = 'supervisorProfile';
  static const supervisorStudentDetail = 'supervisorStudentDetail';

  // Admin
  static const adminOverview = 'adminOverview';
  static const adminManage = 'adminManage';
  static const adminStudents = 'adminStudents';
  static const adminStudentDetail = 'adminStudentDetail';
  static const adminSupervisors = 'adminSupervisors';
  static const adminAssignments = 'adminAssignments';
  static const adminLocations = 'adminLocations';
  static const adminLocationDetail = 'adminLocationDetail';
  static const adminCalendar = 'adminCalendar';
  static const adminPayroll = 'adminPayroll';
  static const adminReports = 'adminReports';
  static const adminProfile = 'adminProfile';
  static const adminMore = 'adminMore';
}