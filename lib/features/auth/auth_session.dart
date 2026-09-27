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

  static bool get isAuthenticated => role != null;

  static void signIn(UserRole r) => role = r;

  static void signOut() => role = null;
}
