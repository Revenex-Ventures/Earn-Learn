import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
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
import 'notification_store.dart';
import '../../core/evidence/geofence.dart';
import '../../core/evidence/geolocation.dart';
import 'local_payroll_repository.dart';
import 'local_student_repository.dart';
import 'local_supervisor_repository.dart';
import 'local_verification_repository.dart';
import 'payroll_store.dart';
import '../../features/auth/auth_session.dart';

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
  (ref) => LocalPayrollRepository(
    students: ref.watch(studentRepositoryProvider),
    assignments: ref.watch(assignmentRepositoryProvider),
    attendance: ref.watch(attendanceRepositoryProvider),
    calendar: ref.watch(calendarRepositoryProvider),
  ),
);

/// Unread notification count for the signed-in principal, for shell badges.
final notificationUnreadProvider = FutureProvider.autoDispose<int>((ref) async {
  final store = NotificationStore.instance;
  final role = AuthSession.role;
  if (role == null) return 0;
  final entityId = switch (role) {
    UserRole.student => AuthSession.studentId,
    UserRole.supervisor => AuthSession.supervisorId,
    UserRole.admin => 'admin',
  };
  return store.unreadCount(role, entityId);
});

/// Notifications addressed to the signed-in principal, newest first.
final notificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final store = NotificationStore.instance;
  final role = AuthSession.role;
  if (role == null) return const [];
  final entityId = switch (role) {
    UserRole.student => AuthSession.studentId,
    UserRole.supervisor => AuthSession.supervisorId,
    UserRole.admin => 'admin',
  };
  return store.forRole(role, entityId).take(50).toList();
});

final leaveRepositoryProvider = Provider<LeaveRepository>(
  (ref) => LocalLeaveRepository(),
);

final auditRepositoryProvider = Provider<AuditRepository>(
  (ref) => LocalAuditRepository(),
);

/// Confirmed-only policy surface surfaced from the server-side policy object.
///
/// In the local build the per-day stipend rate is admin-configurable and lives
/// in [PayrollStore]; when set it overrides the (currently unset) policy rate,
/// so computed payroll uses the college's configured figure.
final policyConfigProvider = Provider<PolicyConfig>((ref) {
  final base = PolicyConfig.fromAppPolicy(mockAppPolicy);
  final configured = PayrollStore.instance.ratePerDay;
  if (configured == null) return base;
  return PolicyConfig(
    monthlyMaxHours: base.monthlyMaxHours,
    enforceHardCap: base.enforceHardCap,
    rollingWindow: base.rollingWindow,
    defaultRatePerDay: configured,
    locationRateTiers: PayrollStore.instance.locationRates.isEmpty
        ? base.locationRateTiers
        : PayrollStore.instance.locationRates,
    lateGrace: base.lateGrace,
    earlyCheckoutGrace: base.earlyCheckoutGrace,
    minimumAttendancePercent: base.minimumAttendancePercent,
    leaveNoticeDays: base.leaveNoticeDays,
    maxLeaveDaysPerMonth: base.maxLeaveDaysPerMonth,
    weeklyWorkingDays: base.weeklyWorkingDays,
    overnightShiftsAllowed: base.overnightShiftsAllowed,
    paidHolidayRule: base.paidHolidayRule,
    payrollApproverRequired: base.payrollApproverRequired,
    evidenceRetentionDays: base.evidenceRetentionDays,
  );
});

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

/// Campus geofence configuration for GPS validation.
///
/// Fetches the first location that has valid latitude/longitude coordinates
/// and uses it as the campus geofence center. Returns null if no location
/// has coordinates configured yet.
final campusGeofenceConfigProvider = FutureProvider.autoDispose<CampusGeofenceConfig?>((ref) async {
  final locationRepository = ref.watch(locationRepositoryProvider);
  final locations = await locationRepository.all();

  final points = locations
      .where((l) =>
          l.latitude != null && l.longitude != null && l.radiusMeters > 0)
      .toList();
  if (points.isEmpty) return null;

  // Single campus fence = centroid of every configured work zone, with a
  // radius that reaches the farthest zone (plus that zone's own radius and a
  // GPS-error margin). The seeded coordinates are offset-derived approximations
  // around the campus anchor, so a covering fence tolerates that slack while
  // still rejecting a genuinely off-campus check-in. Swap to per-zone fences
  // only once each location has a surveyed coordinate.
  final centerLat =
      points.map((l) => l.latitude!).reduce((a, b) => a + b) / points.length;
  final centerLng =
      points.map((l) => l.longitude!).reduce((a, b) => a + b) / points.length;

  final center = Geofence(
    latitude: centerLat,
    longitude: centerLng,
    radiusMeters: 0,
  );
  var maxReachMeters = 0.0;
  for (final l in points) {
    final reach =
        center.distanceTo(l.latitude!, l.longitude!) + l.radiusMeters;
    if (reach > maxReachMeters) maxReachMeters = reach;
  }

  const gpsMarginMeters = 100.0;
  return CampusGeofenceConfig(
    latitude: centerLat,
    longitude: centerLng,
    radiusMeters: maxReachMeters + gpsMarginMeters,
  );
});

/// Resolves the duty photograph for one attendance day, for the shared student
/// dossier.
///
/// Returns null whenever no servable image exists — a local-mode backend, a
/// lost upload, or a gateway error — so the dossier renders an honest
/// "Photo not available" tile rather than a broken image. Only real http(s)
/// evidence URLs are handed to the image loader.
DayEvidenceResolver buildDayEvidenceResolver(AttendanceGateway gateway) {
  return (record) async {
    if (record.evidenceRef == null) return null;
    try {
      final url = await gateway.evidenceUrl(
        sessionId: record.evidenceRef!,
        studentId: record.studentId,
        kind: 'checkin',
      );
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        return null;
      }
      return url;
    } catch (_) {
      return null;
    }
  };
}