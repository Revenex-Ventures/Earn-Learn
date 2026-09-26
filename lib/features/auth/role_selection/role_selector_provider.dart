import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user_role.dart';

/// Static holder that persists the active role across in-process widget rebuilds
/// and provides quick access during activity recreation.
class ActiveRoleStore {
  ActiveRoleStore._();
  static UserRole? role;
}

/// Development role selector provider.
/// In production, this will be replaced by a backend-derived role
/// from the authenticated user's account.
final roleSelectorProvider =
    StateNotifierProvider<RoleSelectorNotifier, UserRole?>(
  (ref) => RoleSelectorNotifier(),
);

class RoleSelectorNotifier extends StateNotifier<UserRole?> {
  RoleSelectorNotifier() : super(ActiveRoleStore.role);

  void select(UserRole role) {
    ActiveRoleStore.role = role;
    state = role;
  }

  void clear() {
    ActiveRoleStore.role = null;
    state = null;
  }
}