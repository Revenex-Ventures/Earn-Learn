import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data.dart';
import '../../shared/components/components.dart';
import '../../shared/mock_data/mock_data.dart';

/// Header avatar for the supervisory-admin surfaces.
///
/// Shows the signed-in administrator. When no account is linked to the session
/// it falls back to the real Student Development Officer recorded on the
/// allotment sheet — never a placeholder stand-in name, so no screen can render
/// an invented identity.
class AdminIdentityAvatar extends ConsumerWidget {
  const AdminIdentityAvatar({super.key, this.size = 44, this.radius});

  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName =
        ref.watch(accountDisplayNameProvider).valueOrNull ?? mockAdminName;
    return InitialsAvatar(name: displayName, size: size, radius: radius);
  }
}
