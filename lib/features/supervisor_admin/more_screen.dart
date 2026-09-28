import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/routing/route_paths.dart';
import '../../shared/components/components.dart';
import 'admin_identity_avatar.dart';

/// Phone-only governance hub: Payroll, Profile and Reports plus the app
/// about card. Deliberately excludes directory/student-review features.
class AdminMoreScreen extends StatelessWidget {
  const AdminMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Program office'),
                      const SizedBox(height: 2),
                      Text(
                        'More',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const AdminIdentityAvatar(),
              ],
            ),
            const SectionEyebrow(
              eyebrow: 'Governance',
              title: 'Program office',
            ),
            AccentRow(
              accent: AppColors.goldSoftAccent,
              lead: const WarmIconWell(
                icon: Icons.payments_outlined,
                gradient: AppColors.goldSoftGrad,
                foreground: Color(0xFF4A3915),
              ),
              title: 'Payroll',
              subtitle: 'Monthly disbursement',
              trailing: const RowChevron(),
              onTap: () => context.go(RoutePaths.adminPayroll),
            ),
            const SizedBox(height: 10),
            AccentRow(
              accent: AppColors.infoSoft,
              lead: const WarmIconWell(
                icon: Icons.bar_chart_outlined,
                background: AppColors.infoSoft,
                foreground: AppColors.onHeroWarm,
              ),
              title: 'Reports',
              subtitle: 'Coverage & disbursement',
              trailing: const RowChevron(),
              onTap: () => context.go(RoutePaths.adminReports),
            ),
            const SizedBox(height: 10),
            AccentRow(
              accent: AppColors.forestSoft,
              lead: const WarmIconWell(
                icon: Icons.person_outline,
                gradient: AppColors.heroForest,
                foreground: AppColors.onHeroWarm,
              ),
              title: 'Profile',
              subtitle: 'Administrator account',
              trailing: const RowChevron(),
              onTap: () => context.go(RoutePaths.adminProfile),
            ),
            const SectionEyebrow(
              eyebrow: 'About',
              title: 'Earn & Learn',
            ),
            const WarmCard(
              child: Column(
                children: [
                  InfoLine(label: 'Version', value: '1.0.0'),
                  HairDivider(),
                  InfoLine(
                    label: 'Institution',
                    value: 'Amrutvahini College of Engineering (AVCOE)',
                  ),
                  HairDivider(),
                  InfoLine(
                    label: 'Office',
                    value: 'Student Development Office',
                  ),
                  HairDivider(),
                  InfoLine(
                    label: 'SDO contact',
                    value: 'sdo@amrutvahini.edu.in',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
