import 'account_status.dart';
import 'user_role.dart';

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.displayName,
    this.photoUrl,
    this.lastLoginAt,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final UserRole role;
  final AccountStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;

  static const String collection = 'users';
}