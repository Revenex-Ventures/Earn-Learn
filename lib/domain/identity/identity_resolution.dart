import '../../core/models/models.dart';
import 'account_link.dart';

/// Outcome of resolving a signed-in account to its directory entity.
class IdentityResolution {
  const IdentityResolution({
    required this.user,
    required this.role,
    this.student,
    this.supervisor,
    this.isUnlinked = false,
  });

  final UserProfile user;
  final UserRole role;
  final Student? student;
  final Supervisor? supervisor;

  /// True when the account has no confirmed directory link yet.
  final bool isUnlinked;

  String? get entityId => student?.id ?? supervisor?.id;

  String get displayName {
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!;
    }
    return student?.name ?? supervisor?.name ?? 'User';
  }
}

/// Pure resolution: an optional account link maps to a directory entity.
///
/// Never fabricates a link; a missing link or a missing entity surfaces as an
/// unlinked resolution, never as an assumed identity.
IdentityResolution resolveIdentity({
  required UserProfile user,
  List<Student> students = const [],
  List<Supervisor> supervisors = const [],
  AccountLink? link,
}) {
  if (link == null || link.entityId == null) {
    return IdentityResolution(user: user, role: user.role, isUnlinked: true);
  }
  for (final s in students) {
    if (s.id == link.entityId) {
      return IdentityResolution(user: user, role: user.role, student: s);
    }
  }
  for (final s in supervisors) {
    if (s.id == link.entityId) {
      return IdentityResolution(user: user, role: user.role, supervisor: s);
    }
  }
  return IdentityResolution(user: user, role: user.role, isUnlinked: true);
}