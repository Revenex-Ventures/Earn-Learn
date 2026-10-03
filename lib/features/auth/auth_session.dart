import '../../core/models/user_role.dart';

/// Tracks which role (if any) has passed the local credential gate.
///
/// Local/sandbox build only. When `AppFlavor.useFirebase` is true the Firebase
/// auth gate governs access and this holder is not consulted. It is a static
/// store (mirroring [ActiveRoleStore]) so the value survives GoRouter redirect
/// evaluations and in-process widget rebuilds.
class AuthSession {
  AuthSession._();

  /// The role that successfully signed in, or null when signed out.
  static UserRole? role;

  /// Entity id of the signed-in principal within its role's roster:
  /// student -> `STU-###`, supervisor -> `SV-##`. Null for admin or when
  /// signed out. This is what lets each of the 68 students / 10 supervisors
  /// see their own data instead of a shared demo record.
  static String? studentId;
  static String? supervisorId;

  static bool get isAuthenticated => role != null;

  /// Signs a principal in and records which roster entity they are.
  static void signIn(UserRole r, {String? entityId}) {
    role = r;
    switch (r) {
      case UserRole.student:
        studentId = entityId;
        supervisorId = null;
      case UserRole.supervisor:
        supervisorId = entityId;
        studentId = null;
      case UserRole.admin:
        studentId = null;
        supervisorId = null;
    }
  }

  static void signOut() {
    role = null;
    studentId = null;
    supervisorId = null;
  }
}
