import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/models/models.dart';
import '../../core/routing/route_paths.dart';
import '../../data/data.dart';
import '../../shared/components/components.dart';
import '../../shared/mock_data/mock_data.dart';
import '../auth/auth_session.dart';

final _adminProfileProvider = FutureProvider.autoDispose<UserProfile?>(
    (ref) async {
  final account = ref.watch(accountRepositoryProvider);
  return account.currentUser();
});

class AdminProfileScreen extends ConsumerWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(_adminProfileProvider);

    return snapshot.when(
      loading: () => const LoadingState(label: 'Loading profile…'),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      data: (user) => user == null
          ? const SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: EmptyState(
                icon: Icons.person_off_outlined,
                title: 'Profile not available',
                message: 'No administrator account is linked to this session.',
              ),
            )
          : _AdminProfileView(user: user),
    );
  }
}

class _AdminProfileView extends StatelessWidget {
  const _AdminProfileView({required this.user});

  final UserProfile user;

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '—';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = user.displayName ?? mockAdminName;
    final roleLabel = user.role == UserRole.admin
        ? 'Program Administrator'
        : user.role.name;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsBubble(
                  initials: _initials(displayName),
                  gradient: AppColors.heroForest,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Administrator',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.slateWarm,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        displayName,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            WarmCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: 13),
              child: Row(
                children: [
                  const WarmIconWell(
                    icon: Icons.admin_panel_settings_outlined,
                    background: AppColors.infoSoft,
                    foreground: AppColors.onHeroWarm,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('Officer email'),
                        const SizedBox(height: 2),
                        Text(
                          user.email ?? 'Not available',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontFamily: AppTextStyles.monoFamily,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SectionEyebrow(
              eyebrow: 'Identity',
              title: 'Administrator account',
            ),
            WarmCard(
              child: Column(
                children: [
                  InfoLine(
                    label: 'Email',
                    value: user.email ?? 'Not available',
                  ),
                  const HairDivider(),
                  _BadgeLine(
                    label: 'Role',
                    badge: PremiumBadge(label: roleLabel, tone: BadgeTone.slate),
                  ),
                  const HairDivider(),
                  _BadgeLine(
                    label: 'Status',
                    badge: PremiumBadge(
                      label: user.status.label,
                      tone: user.status == AccountStatus.active
                          ? BadgeTone.forest
                          : BadgeTone.slate,
                      dot: true,
                    ),
                  ),
                  const HairDivider(),
                  InfoLine(
                    label: 'Joined',
                    value: DateFormat('d MMM yyyy').format(user.createdAt),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: 'Sign out',
              onTap: () {
                AuthSession.signOut();
                context.go(RoutePaths.auth);
              },
              isSecondary: true,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}

/// A label + trailing badge row that lines up with [InfoLine].
class _BadgeLine extends StatelessWidget {
  const _BadgeLine({required this.label, required this.badge});

  final String label;
  final Widget badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.slateWarm,
              ),
            ),
          ),
          const SizedBox(width: 12),
          badge,
        ],
      ),
    );
  }
}
