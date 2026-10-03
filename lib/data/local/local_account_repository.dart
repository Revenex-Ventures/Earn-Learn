import '../../core/models/models.dart';
import '../../domain/domain.dart';
import '../../features/auth/auth_session.dart';
import '../../shared/mock_data/mock_data.dart';
import '../dev_only.dart';

/// Directory-links for the demo identities (mirrors the mock user fixtures).
const List<AccountLink> demoAccountLinks = [
  AccountLink(userId: 'u-stu-001', role: UserRole.student, entityId: 'STU-001'),
  AccountLink(userId: 'u-sup-001', role: UserRole.supervisor, entityId: 'SV-01'),
  AccountLink(userId: 'u-admin-001', role: UserRole.admin),
];

@DevOnly('Demo identities: student/supervisor/admin fixtures from mock_data.')
class LocalAccountRepository implements AccountRepository {
  LocalAccountRepository({UserProfile? user}) : user = user ?? mockStudentUser;

  final UserProfile user;

  @override
  Future<UserProfile?> currentUser() async => user;

  @override
  Future<AccountLink?> currentAccountLink() async {
    // Resolve the signed-in entity first, so each of the 68 student / 10
    // supervisor logins maps to its own roster record rather than a shared
    // demo fixture. Falls back to the seeded demo links for the plain preview.
    switch (user.role) {
      case UserRole.student:
        final id = AuthSession.studentId;
        if (id != null) {
          return AccountLink(
            userId: user.uid,
            role: UserRole.student,
            entityId: id,
          );
        }
      case UserRole.supervisor:
        final id = AuthSession.supervisorId;
        if (id != null) {
          return AccountLink(
            userId: user.uid,
            role: UserRole.supervisor,
            entityId: id,
          );
        }
      case UserRole.admin:
        break;
    }
    for (final link in demoAccountLinks) {
      if (link.userId == user.uid) return link;
    }
    for (final link in demoAccountLinks) {
      if (link.role == user.role) return link;
    }
    return null;
  }
}