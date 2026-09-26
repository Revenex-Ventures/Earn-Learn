import '../../core/models/models.dart';

/// Links an authenticated user (Firebase UID) to a trusted institutional
/// directory entry.
///
/// Admin accounts are unlinked (they have no student/supervisor entity). For
/// students and supervisors the [entityId] is the directory id (STU-* / SV-*);
/// the college must confirm the identity mapping before Stage 2.
class AccountLink {
  const AccountLink({required this.userId, required this.role, this.entityId});

  final String userId;
  final UserRole role;

  /// Directory id for students (STU-*) and supervisors (SV-*); null for admin
  /// or unlinked accounts.
  final String? entityId;

  @override
  bool operator ==(Object other) =>
      other is AccountLink &&
      other.userId == userId &&
      other.role == role &&
      other.entityId == entityId;

  @override
  int get hashCode => Object.hash(userId, role, entityId);
}