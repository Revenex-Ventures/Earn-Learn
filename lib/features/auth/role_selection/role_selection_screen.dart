import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/app_colors.dart';
import '../../../core/design_system/app_spacing.dart';
import '../../../core/routing/route_paths.dart';
import '../../../shared/components/brand_header.dart';
import '../../../shared/components/warm_premium_kit.dart';

/// Full-page role selector — lives OUTSIDE the AppShell, so it keeps its own
/// Scaffold. Restyled to the warm-premium editorial look; all navigation
/// wiring (context.go to each login route + the demo route) is unchanged.
class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 360;
    final logoHeight = isCompact ? 52.0 : 60.0;

    return Scaffold(
      backgroundColor: AppColors.warmCanvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? AppSpacing.lg : AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Institutional header — big background-removed AVCOE crest
                  //    (left) + custodian portrait (right). Marks untouched.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AvcoeLogo(height: logoHeight),
                      const SizedBox(width: 12),
                      Container(
                        width: 1.5,
                        height: logoHeight * 0.62,
                        color: AppColors.warmLine,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'AVCOE',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                                color: AppColors.slateWarm,
                              ),
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              'Earn & Learn',
                              style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                                color: AppColors.inkWarm,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      BhauraoPortrait(
                        size: isCompact ? 46 : 50,
                        borderWidth: 2.0,
                        borderColor: AppColors.warmSurface,
                      ),
                    ],
                  ),

                  SizedBox(height: isCompact ? AppSpacing.lg : AppSpacing.xl),

                  // 2. Editorial title block
                  const Eyebrow('Welcome'),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Choose Your Role',
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      fontSize: isCompact ? 26 : 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      height: 1.05,
                      color: AppColors.inkWarm,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Select how you sign in to continue.',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slateWarm,
                    ),
                  ),

                  SizedBox(height: isCompact ? AppSpacing.lg : AppSpacing.xl),

                  // 3. Role choices — Student / Supervisor / Admin
                  _RoleTile(
                    icon: Icons.school_outlined,
                    title: 'Student',
                    subtitle: 'Track attendance, assignments and work',
                    color: AppColors.forestSoft,
                    onTap: () => context.go(RoutePaths.login('student')),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  _RoleTile(
                    icon: Icons.people_outline,
                    title: 'Supervisor',
                    subtitle: 'Manage students and approvals',
                    color: AppColors.goldSoftDeep,
                    onTap: () => context.go(RoutePaths.login('supervisor')),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  _RoleTile(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Admin',
                    subtitle: 'Oversee operations, records and reports',
                    color: AppColors.info,
                    onTap: () => context.go(RoutePaths.login('admin')),
                  ),

                  // 4. Guided end-to-end demo entry (subtle row)
                  const SectionEyebrow(eyebrow: 'Guided demo'),
                  _DemoTile(
                    onTap: () => context.go('/demo'),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 5. Advisory note
                  const NoteBox(
                    icon: Icons.shield_outlined,
                    text:
                        'Role selection provides sandbox profile switching. '
                        'In production, your institutional credentials '
                        'determine access permissions.',
                  ),

                  SizedBox(height: isCompact ? AppSpacing.lg : AppSpacing.xl),

                  // 6. Institutional footer grounding
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 32,
                          height: 2,
                          decoration: BoxDecoration(
                            color: AppColors.goldSoftAccent
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'AVCOE  |  Earn & Learn',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: AppColors.slateWarm,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Amrutvahini College of Engineering',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.slateWarm.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Warm-premium role option — a left-accent list row with a tinted icon well
/// and chevron. The [onTap] wiring is preserved exactly.
class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color = AppColors.inkWarm,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AccentRow(
      accent: color,
      lead: WarmIconWell(
        icon: icon,
        gradient: AppColors.accentGradient(color),
      ),
      title: title,
      subtitle: subtitle,
      trailing: const RowChevron(),
      onTap: onTap,
    );
  }
}

/// Subtle tappable demo entry card. The [onTap] wiring is preserved exactly.
class _DemoTile extends StatelessWidget {
  const _DemoTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WarmCard(
      ivory: true,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          const WarmIconWell(
            icon: Icons.play_circle_fill,
            gradient: AppColors.heroForest,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Live End-to-End Demo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.inkWarm,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const PremiumBadge(
                      label: 'SCENARIO',
                      tone: BadgeTone.forest,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Student Onboard → Shift → Review → Audit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slateWarm,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const RowChevron(),
        ],
      ),
    );
  }
}
