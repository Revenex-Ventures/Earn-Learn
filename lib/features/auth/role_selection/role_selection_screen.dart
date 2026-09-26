import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_radius.dart';
import '../../../core/design_system/app_spacing.dart';
import '../../../core/design_system/app_text_styles.dart';
import '../../../core/models/user_role.dart';
import '../../../shared/components/brand_header.dart';
import 'role_selector_provider.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 360;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? AppSpacing.md : AppSpacing.xl,
                vertical: isCompact ? AppSpacing.sm : AppSpacing.md,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (isCompact ? 16 : 32),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Top Brand Header: Prominent AVCOE Logo (Left) + Bhaurao Patil Portrait (Right)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            AvcoeLogo(height: isCompact ? 48 : 58),
                            BhauraoPortrait(size: isCompact ? 52 : 64),
                          ],
                        ),
                      ),
                      SizedBox(height: isCompact ? AppSpacing.md : AppSpacing.xl),

                      // 2. Central Title Section
                      Center(
                        child: Column(
                          children: [
                            Text(
                              'WELCOME',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.slate,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2.0,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Choose Your Role',
                              style: AppTextStyles.headlineMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                                fontSize: isCompact ? 22 : 26,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select your role to continue',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.slate,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isCompact ? AppSpacing.md : AppSpacing.xl),

                      // 3. Role Cards: Student, Supervisor, Admin
                      _RoleTile(
                        icon: Icons.school_outlined,
                        title: 'Student',
                        subtitle: 'Track attendance, assignments and work',
                        color: AppColors.avcoeGreen,
                        onTap: () {
                          ref.read(roleSelectorProvider.notifier).select(UserRole.student);
                          context.go('/student');
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      _RoleTile(
                        icon: Icons.people_outline,
                        title: 'Supervisor',
                        subtitle: 'Manage students and approvals',
                        color: AppColors.marigold,
                        onTap: () {
                          ref.read(roleSelectorProvider.notifier).select(UserRole.supervisor);
                          context.go('/supervisor');
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      _RoleTile(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Admin',
                        subtitle: 'Oversee operations, records and reports',
                        color: AppColors.info,
                        onTap: () {
                          ref.read(roleSelectorProvider.notifier).select(UserRole.admin);
                          context.go('/admin');
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // 4. Live End-to-End Demo Option
                      _DemoTile(
                        onTap: () => context.go('/demo'),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // 5. Information Note
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              size: 16,
                              color: AppColors.avcoeGreen,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Role selection provides sandbox profile switching. In production, '
                                'your institutional credentials determine access permissions.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.slate,
                                  fontSize: 11,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),
                      const SizedBox(height: AppSpacing.md),

                      // 6. Subtle Institutional Footer Grounding
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 32,
                              height: 2,
                              decoration: BoxDecoration(
                                color: AppColors.avcoeGreen.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'AVCOE  |  Earn & Learn',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.slate.withValues(alpha: 0.7),
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Amrutvahini College of Engineering',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.slate.withValues(alpha: 0.5),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Compact, elegant role option tile matching the reference design.
class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color = AppColors.ink,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.slate,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.slate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  const _DemoTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.marigold.withValues(alpha: 0.4),
              width: 1.2,
            ),
            color: AppColors.marigoldLight.withValues(alpha: 0.3),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.marigold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.play_circle_fill,
                  size: 20,
                  color: AppColors.marigold,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Live End-to-End Demo',
                            style: AppTextStyles.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.avcoeGreen,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SCENARIO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Student Onboard → Shift → Review → Audit',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 11,
                        color: AppColors.slate,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppColors.slate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}