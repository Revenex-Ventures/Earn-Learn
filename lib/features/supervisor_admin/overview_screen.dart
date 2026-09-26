import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';
import '../../core/routing/route_paths.dart';
import '../../data/data.dart';
import '../../shared/components/components.dart';

/// Summary view-model for the admin overview dashboard, computed purely from
/// the real repository directories and verification queue.
class AdminOverviewData {
  const AdminOverviewData({
    required this.studentCount,
    required this.locationCount,
    required this.supervisorCount,
    required this.assignmentCount,
    required this.openItems,
    required this.approvedItems,
    required this.paymentCount,
    required this.staffedLocationCount,
    required this.flaggedItems,
  });

  final int studentCount;
  final int locationCount;
  final int supervisorCount;
  final int assignmentCount;
  final int openItems;
  final int approvedItems;
  final int paymentCount;
  final int staffedLocationCount;
  final List<VerificationItem> flaggedItems;
}

final _adminOverviewProvider = FutureProvider.autoDispose<AdminOverviewData>(
    (ref) async {
  final students = ref.watch(studentRepositoryProvider);
  final supervisors = ref.watch(supervisorRepositoryProvider);
  final locations = ref.watch(locationRepositoryProvider);
  final assignments = ref.watch(assignmentRepositoryProvider);
  final verification = ref.watch(verificationRepositoryProvider);
  final payroll = ref.watch(payrollRepositoryProvider);

  final allStudents = await students.all();
  final allSupervisors = await supervisors.all();
  final allLocations = await locations.all();
  final allAssignments = await assignments.all();
  final items = await verification.items();
  final now = DateTime.now();
  final payments = await payroll.recordsForMonth(DateTime(now.year, now.month));

  return AdminOverviewData(
    studentCount: allStudents.length,
    locationCount: allLocations.length,
    supervisorCount: allSupervisors.length,
    assignmentCount: allAssignments.length,
    openItems: items.where((v) => v.status != ApprovalStatus.approved).length,
    approvedItems: items.where((v) => v.status == ApprovalStatus.approved).length,
    paymentCount: payments.length,
    staffedLocationCount: allLocations
        .where((l) => allAssignments.any((a) => a.locationId == l.id))
        .length,
    flaggedItems:
        items.where((v) => v.status == ApprovalStatus.flagged).toList(),
  );
});

class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(_adminOverviewProvider);

    return snapshot.when(
      loading: () => const LoadingState(label: 'Loading program overview…'),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      data: (data) => _AdminOverviewView(data: data),
    );
  }
}

class _AdminOverviewView extends StatelessWidget {
  const _AdminOverviewView({required this.data});

  final AdminOverviewData data;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Brand Header
            const BrandHeader(
              logoHeight: 38,
              portraitSize: 42,
              title: 'Earn & Learn',
              subtitle: 'AVCOE',
            ),
            const SizedBox(height: AppSpacing.md),

            // Greeting + Role Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good Morning,',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate),
                      ),
                      Text(
                        'Admin',
                        style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: AppColors.ink.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.security, size: 14, color: AppColors.ink),
                      const SizedBox(width: 4),
                      Text(
                        'Administrator',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // 2 Hero Metric Cards Row matching reference
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.avcoeGreen,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.avcoeGreen.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Students',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.surface.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${data.studentCount}',
                          style: AppTextStyles.headlineLarge.copyWith(
                            color: AppColors.surface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.ink.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Supervisors',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.surface.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${data.supervisorCount}',
                          style: AppTextStyles.headlineLarge.copyWith(
                            color: AppColors.surface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // 6-Item Quick Navigation Grid (2 rows x 3 cols)
            Row(
              children: [
                Expanded(
                  child: _AdminNavTile(
                    icon: Icons.school_outlined,
                    label: 'Students',
                    onTap: () => context.go(RoutePaths.adminStudents),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _AdminNavTile(
                    icon: Icons.people_outline,
                    label: 'Supervisors',
                    onTap: () => context.go(RoutePaths.adminSupervisors),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _AdminNavTile(
                    icon: Icons.location_on_outlined,
                    label: 'Locations',
                    onTap: () => context.go(RoutePaths.adminLocations),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _AdminNavTile(
                    icon: Icons.assignment_outlined,
                    label: 'Assignments',
                    onTap: () => context.go(RoutePaths.adminAssignments),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _AdminNavTile(
                    icon: Icons.calendar_month_outlined,
                    label: 'Calendar',
                    onTap: () => context.go(RoutePaths.adminCalendar),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _AdminNavTile(
                    icon: Icons.bar_chart_outlined,
                    label: 'Reports',
                    onTap: () => context.go(RoutePaths.adminReports),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Payroll Tile
            InkWell(
              onTap: () => context.go(RoutePaths.adminPayroll),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.marigoldLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.payments_outlined, size: 20, color: AppColors.marigold),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payroll', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                          Text('Monthly stipend approvals (${data.paymentCount} records)',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20, color: AppColors.slate),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Operations & Escalations
            const SectionHeader(
              eyebrow: 'OPERATIONS',
              title: 'Live workload',
            ),
            const SizedBox(height: AppSpacing.md),
            MetricGroup(
              items: [
                MetricItem(
                  label: 'Open verifications',
                  value: '${data.openItems}',
                  icon: Icons.fact_check_outlined,
                  tone: data.openItems == 0
                      ? StatusTone.positive
                      : StatusTone.attention,
                ),
                MetricItem(
                  label: 'Approved items',
                  value: '${data.approvedItems}',
                  icon: Icons.verified_outlined,
                  tone: StatusTone.positive,
                ),
                MetricItem(
                  label: 'Staffed locations',
                  value: '${data.staffedLocationCount}',
                  icon: Icons.storefront_outlined,
                  tone: StatusTone.neutral,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Flagged Items
            const SectionHeader(
              eyebrow: 'ESCALATIONS',
              title: 'Flagged verifications',
            ),
            const SizedBox(height: AppSpacing.md),
            if (data.flaggedItems.isEmpty)
              const EmptyState(
                icon: Icons.flag_outlined,
                title: 'No flagged items',
                message: 'Nothing is currently escalated for review.',
              )
            else
              for (var i = 0; i < data.flaggedItems.length; i++) ...[
                _EscalationTile(item: data.flaggedItems[i]),
                if (i != data.flaggedItems.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ),
      ),
    );
  }
}

class _AdminNavTile extends StatelessWidget {
  const _AdminNavTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// One compact escalation line: student, kind • location, one-line summary
/// and the flagged badge. Intentional — one row max, no review actions here.
class _EscalationTile extends StatelessWidget {
  const _EscalationTile({required this.item});

  final VerificationItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.clay.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconWell(
            icon: Icons.flag_outlined,
            color: AppColors.clay,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.studentName,
                        style: AppTextStyles.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    StatusBadge.status(style: ApprovalStatus.flagged.style),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.type.label} • ${item.location}',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.summary,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}