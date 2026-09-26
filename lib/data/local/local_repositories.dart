import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/domain.dart';
import '../../features/auth/role_selection/role_selector_provider.dart';
import '../../shared/mock_data/mock_data.dart';
import '../app_flavor.dart';
import '../firebase/firebase_repositories.dart';
import '../firebase/attendance_gateway.dart';
import 'local_account_repository.dart';
import 'local_assignment_repository.dart';
import 'local_attendance_gateway.dart';
import 'local_attendance_repository.dart';
import 'local_audit_repository.dart';
import 'local_calendar_repository.dart';
import 'local_leave_repository.dart';
import 'local_location_repository.dart';
import 'local_payroll_repository.dart';
import 'local_student_repository.dart';
import 'local_supervisor_repository.dart';
import 'local_verification_repository.dart';

/// Stage 2A repository wiring.
///
/// The provider NAMES below are stable app-wide (the UI never knows which
/// backend backs them). By default the local `@DevOnly` repositories from
/// Stage 1B are bound; with `--dart-define=FIREBASE=true` the same names bind
/// the Firestore-backed implementations. Contracts live in
/// `lib/domain/repositories`.
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  if (AppFlavor.useFirebase) {
    return FirestoreAccountRepository(
      store: ref.watch(firestoreDataStoreProvider),
      uid: () => ref.read(firebaseAuthUidProvider),
    );
  }
  return LocalAccountRepository(
    user: mockUserForRole(ref.watch(roleSelectorProvider)),
  );
});

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  if (AppFlavor.useFirebase) {
    return FirestoreStudentRepository(ref.watch(firestoreDataStoreProvider));
  }
  return LocalStudentRepository(mockStudents);
});

final supervisorRepositoryProvider = Provider<SupervisorRepository>((ref) {
  if (AppFlavor.useFirebase) {
    return FirestoreSupervisorRepository(ref.watch(firestoreDataStoreProvider));
  }
  return LocalSupervisorRepository(mockSupervisors);
});

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  if (AppFlavor.useFirebase) {
    return FirestoreLocationRepository(ref.watch(firestoreDataStoreProvider));
  }
  return LocalLocationRepository(mockLocations);
});

final assignmentRepositoryProvider = Provider<AssignmentRepository>((ref) {
  if (AppFlavor.useFirebase) {
    return FirestoreAssignmentRepository(ref.watch(firestoreDataStoreProvider));
  }
  return LocalAssignmentRepository(mockAssignments);
});

final localAttendanceRepositoryProvider = Provider<LocalAttendanceRepository>((ref) {
  return LocalAttendanceRepository(goldenRecords: mockAttendance);
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  if (AppFlavor.useFirebase) {
    return FirestoreAttendanceRepository(
      store: ref.watch(firestoreDataStoreProvider),
    );
  }
  return ref.watch(localAttendanceRepositoryProvider);
});

final attendanceGatewayProvider = Provider<AttendanceGateway>((ref) {
  if (AppFlavor.useFirebase) {
    return CloudAttendanceGateway(host: AppFlavor.emulatorHost);
  }
  return LocalAttendanceGateway(
    attendanceRepository: ref.watch(localAttendanceRepositoryProvider),
  );
});

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => const LocalCalendarRepository(),
);

final verificationRepositoryProvider = Provider<VerificationRepository>((ref) {
  if (AppFlavor.useFirebase) {
    return FirestoreVerificationRepository(ref.watch(attendanceGatewayProvider));
  }
  return const LocalVerificationRepository();
});

final payrollRepositoryProvider = Provider<PayrollRepository>(
  (ref) => const LocalPayrollRepository(),
);

final leaveRepositoryProvider = Provider<LeaveRepository>(
  (ref) => LocalLeaveRepository(),
);

final auditRepositoryProvider = Provider<AuditRepository>(
  (ref) => LocalAuditRepository(),
);

/// Confirmed-only policy surface surfaced from the server-side policy object.
final policyConfigProvider = Provider<PolicyConfig>(
  (ref) => PolicyConfig.fromAppPolicy(mockAppPolicy),
);

/// Display name of the signed-in account, for shell headers and avatars.
///
/// Falls back to the real Student Development Officer rather than a
/// placeholder, so no surface can ever render an invented identity.
final accountDisplayNameProvider = FutureProvider.autoDispose<String>((ref) async {
  final account = ref.watch(accountRepositoryProvider);
  final name = (await account.currentUser())?.displayName;
  if (name != null && name.trim().isNotEmpty) return name;
  return mockAdminName;
});