import '../../core/models/user_role.dart';

/// A sandbox demo credential for the local (non-Firebase) build.
///
/// These are NOT institutional passwords. They are demo sign-in details for the
/// offline review build, grounded in real seed identifiers (Earn & Learn ID,
/// supervisor ID, officer email) and surfaced on the login screen so reviewers
/// can enter each role. In the Firebase build, real Google sign-in governs
/// access and these values are unused.
class DemoCredential {
  const DemoCredential({
    required this.role,
    required this.username,
    required this.password,
    required this.displayName,
    required this.identifierLabel,
  });

  final UserRole role;
  final String username;
  final String password;
  final String displayName;
  final String identifierLabel;
}

class DemoCredentials {
  DemoCredentials._();

  /// Shared sandbox password for every demo role.
  static const String password = 'avcoe@2627';

  /// One demo account per role, keyed to real seed identifiers:
  /// student -> Earn & Learn ID (EL2627-001, STU-001), supervisor -> SV-01,
  /// admin -> the Student Development Officer email.
  static const Map<UserRole, DemoCredential> byRole = {
    UserRole.student: DemoCredential(
      role: UserRole.student,
      username: 'EL2627-001',
      password: password,
      displayName: 'DHANWATE RUTUJA NITIN',
      identifierLabel: 'Earn & Learn ID',
    ),
    UserRole.supervisor: DemoCredential(
      role: UserRole.supervisor,
      username: 'SV-01',
      password: password,
      displayName: 'Mr. K.J. Dhage',
      identifierLabel: 'Supervisor ID',
    ),
    UserRole.admin: DemoCredential(
      role: UserRole.admin,
      username: 'sdo@avcoe.edu.in',
      password: password,
      displayName: 'Dr. B.R. Borkar',
      identifierLabel: 'Officer email',
    ),
  };

  static DemoCredential of(UserRole role) => byRole[role]!;

  /// Validates a sign-in attempt for [role]. Username match is
  /// case-insensitive and trimmed; password must match exactly.
  static bool validate({
    required UserRole role,
    required String username,
    required String password,
  }) {
    final cred = byRole[role];
    if (cred == null) return false;
    return username.trim().toLowerCase() == cred.username.toLowerCase() &&
        password == cred.password;
  }
}
