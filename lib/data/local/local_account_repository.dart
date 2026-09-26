import '../../core/models/models.dart';
import '../../domain/domain.dart';
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
    for (final link in demoAccountLinks) {
      if (link.userId == user.uid) return link;
    }
    for (final link in demoAccountLinks) {
      if (link.role == user.role) return link;
    }
    return null;
  }
}