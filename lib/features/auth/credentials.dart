import '../../core/models/user_role.dart';
import '../../shared/mock_data/mock_data.dart';

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

  /// Resolves the signed-in entity id for a valid attempt, or null when the
  /// credentials don't match any seeded principal for [role].
  ///
  /// This is what turns a single demo login into 68 student + 10 supervisor
  /// logins: any roster student (matched by Earn & Learn ID `EL2627-###` or
  /// internal `STU-###`) and any roster supervisor (matched by `SV-##`) can
  /// sign in with the shared sandbox password. Admin has no per-entity id.
  static String? resolveIdentity({
    required UserRole role,
    required String username,
  }) {
    final u = username.trim().toLowerCase();
    switch (role) {
      case UserRole.student:
        for (final s in mockStudents) {
          if (s.rollNumber.toLowerCase() == u || s.id.toLowerCase() == u) {
            return s.id;
          }
        }
        return null;
      case UserRole.supervisor:
        for (final sv in mockSupervisors) {
          if (sv.id.toLowerCase() == u) return sv.id;
        }
        return null;
      case UserRole.admin:
        return null;
    }
  }

  /// Validates a sign-in attempt for [role]. The password must match the
  /// shared sandbox password exactly; the username is matched case-insensitively
  /// against the whole seeded roster (students, supervisors) or the officer
  /// email (admin).
  static bool validate({
    required UserRole role,
    required String username,
    required String password,
  }) {
    if (password != DemoCredentials.password) return false;
    switch (role) {
      case UserRole.student:
      case UserRole.supervisor:
        return resolveIdentity(role: role, username: username) != null;
      case UserRole.admin:
        return username.trim().toLowerCase() == mockAdminEmail.toLowerCase();
    }
  }
}
