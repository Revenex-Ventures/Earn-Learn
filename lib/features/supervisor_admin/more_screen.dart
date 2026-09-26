import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ContextHeader(
              greeting: 'More',
              trailing: AdminIdentityAvatar(),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              eyebrow: 'GOVERNANCE',
              title: 'Program office',
            ),
            const SizedBox(height: AppSpacing.md),
            _HubTile(
              icon: Icons.payments_outlined,
              title: 'Payroll',
              subtitle: 'Monthly disbursement',
              onTap: () => context.go(RoutePaths.adminPayroll),
            ),
            const SizedBox(height: AppSpacing.sm),
            _HubTile(
              icon: Icons.bar_chart_outlined,
              title: 'Reports',
              subtitle: 'Coverage & disbursement',
              onTap: () => context.go(RoutePaths.adminReports),
            ),
            const SizedBox(height: AppSpacing.sm),
            _HubTile(
              icon: Icons.person_outline,
              title: 'Profile',
              subtitle: 'Administrator account',
              onTap: () => context.go(RoutePaths.adminProfile),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader(
              eyebrow: 'ABOUT',
              title: 'Earn & Learn',
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
                  _AboutRow(label: 'Version', value: '1.0.0'),
                  const Divider(height: 1, color: AppColors.divider),
                  _AboutRow(
                    label: 'Institution',
                    value: 'Amrutvahini College of Engineering (AVCOE)',
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  _AboutRow(
                    label: 'Office',
                    value: 'Student Development Office',
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  _AboutRow(
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

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      leading: IconWell(icon: icon),
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

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
            width: 96,
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