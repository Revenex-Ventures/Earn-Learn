import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';
import '../../core/routing/route_paths.dart';
import '../../data/data.dart';
import '../../shared/components/components.dart';

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

  @override
  Widget build(BuildContext context) {
    final displayName = user.displayName ?? 'SDO In-Charge';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContextHeader(
              greeting: displayName,
              trailing: InitialsAvatar(name: displayName),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              eyebrow: 'IDENTITY',
              title: 'Administrator account',
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  _Info(label: 'Email', value: user.email ?? 'Not available'),
                  const Divider(height: 1, color: AppColors.divider),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: _BadgeRow(
                      label: 'Role',
                      badge: StatusBadge(
                        label: user.role == UserRole.admin
                            ? 'Program Administrator'
                            : user.role.name,
                        style: styleFor(
                          StatusTone.neutral,
                          icon: Icons.admin_panel_settings_outlined,
                          label: 'Program Administrator',
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: _BadgeRow(
                      label: 'Status',
                      badge: StatusBadge.status(style: user.status.style),
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  _Info(
                    label: 'Joined',
                    value: DateFormat('d MMM yyyy').format(user.createdAt),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            PrimaryButton(
              label: 'Sign out',
              onTap: () => context.go(RoutePaths.auth),
              isSecondary: true,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.label, required this.badge});

  final String label;
  final StatusBadge badge;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(letterSpacing: 0.8),
          ),
        ),
        Expanded(child: badge),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label.toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(letterSpacing: 0.8),
            ),
          ),
          Expanded(
            child: Text(value, style: AppTextStyles.bodyMedium),
          ),
        ],
      ),
    );
  }
}