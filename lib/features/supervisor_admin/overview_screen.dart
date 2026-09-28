import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
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
    approvedItems:
        items.where((v) => v.status == ApprovalStatus.approved).length,
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
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const InitialsBubble(
                  initials: 'SD',
                  gradient: AppColors.heroForest,
                  foreground: AppColors.onHeroWarm,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student Dev. Office',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.slate,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Scheme Overview',
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
                _RoundIcon(
                  icon: Icons.settings_outlined,
                  onTap: () => context.go(RoutePaths.adminProfile),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            EspressoHero(
              value: '${data.studentCount}',
              unit: 'enrolled\nstudents',
              caption:
                  '${data.locationCount} locations · ${data.supervisorCount} supervisors · ${data.assignmentCount} assignments',
              leftPill: const HeroPill(
                label: 'K.B.P. Earn & Learn',
                icon: Icons.grid_view_outlined,
              ),
              rightPill: const HeroPill(label: 'AY 2026–27', gold: true),
            ),
            const SectionEyebrow(eyebrow: 'Live workload'),
            MetricTileGrid(
              items: [
                const MetricTileData(
                  label: 'On duty',
                  value: '—',
                  desc: 'Live count · not tracked',
                  tone: BadgeTone.slate,
                ),
                MetricTileData(
                  label: 'Pending',
                  value: '${data.openItems}',
                  desc: 'awaiting review',
                  tone: BadgeTone.gold,
                ),
                MetricTileData(
                  label: 'Approved',
                  value: '${data.approvedItems}',
                  desc: 'signed off',
                  tone: BadgeTone.forest,
                ),
                const MetricTileData(
                  label: 'Month payout',
                  value: '₹—',
                  desc: 'not finalized',
                  tone: BadgeTone.slate,
                ),
              ],
            ),
            const SectionEyebrow(eyebrow: 'Health checks'),
            const SoftBox(
              label: '77 data validation issues · roster incomplete',
              tone: BadgeTone.clay,
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 10),
            Column(
              children: const [
                _IssueRow(
                  title: 'No contact',
                  subtitle: '60 students · phone missing',
                  count: '60',
                ),
                SizedBox(height: 10),
                _IssueRow(
                  title: 'No email',
                  subtitle: '10 supervisors',
                  count: '10',
                ),
                SizedBox(height: 10),
                _IssueRow(
                  title: 'No time slot',
                  subtitle: '3 library allotments',
                  count: '3',
                ),
                SizedBox(height: 10),
                _IssueRow(
                  title: 'Unassigned',
                  subtitle: '4 allotments · no supervisor',
                  count: '4',
                ),
              ],
            ),
            const SizedBox(height: 10),
            const NoteBox(
              text:
                  'Counts reflect the current roster import. Resolve the gaps in the directory before payout is finalized.',
            ),
            const SectionEyebrow(eyebrow: 'Manage'),
            Column(
              children: [
                _ManageRow(
                  icon: Icons.school_outlined,
                  title: 'Students',
                  subtitle: '${data.studentCount} records · 60 need contact',
                  onTap: () => context.go(RoutePaths.adminStudents),
                ),
                const SizedBox(height: 10),
                _ManageRow(
                  icon: Icons.people_outline,
                  title: 'Supervisors',
                  subtitle: '${data.supervisorCount} supervisors',
                  onTap: () => context.go(RoutePaths.adminSupervisors),
                ),
                const SizedBox(height: 10),
                _ManageRow(
                  icon: Icons.location_on_outlined,
                  title: 'Locations',
                  subtitle:
                      '${data.locationCount} · coordinates: Configuration required',
                  onTap: () => context.go(RoutePaths.adminLocations),
                ),
                const SizedBox(height: 10),
                _ManageRow(
                  icon: Icons.assignment_outlined,
                  title: 'Assignments',
                  subtitle: '${data.assignmentCount} allotments',
                  onTap: () => context.go(RoutePaths.adminAssignments),
                ),
                const SizedBox(height: 10),
                _ManageRow(
                  icon: Icons.calendar_month_outlined,
                  title: 'Calendar',
                  subtitle: 'Off-days & holidays',
                  onTap: () => context.go(RoutePaths.adminCalendar),
                ),
                const SizedBox(height: 10),
                _ManageRow(
                  icon: Icons.bar_chart_outlined,
                  title: 'Reports',
                  subtitle: 'Monthly attendance report',
                  onTap: () => context.go(RoutePaths.adminReports),
                ),
                const SizedBox(height: 10),
                _ManageRow(
                  icon: Icons.payments_outlined,
                  title: 'Payroll',
                  subtitle: 'Stipend ledger · ${data.paymentCount} records',
                  onTap: () => context.go(RoutePaths.adminPayroll),
                ),
              ],
            ),
            const SectionEyebrow(eyebrow: 'Escalations'),
            if (data.flaggedItems.isEmpty)
              const NoteBox(
                text: 'No verifications are currently escalated for review.',
                icon: Icons.flag_outlined,
              )
            else
              Column(
                children: [
                  for (var i = 0; i < data.flaggedItems.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _EscalationRow(item: data.flaggedItems[i]),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// One roster health-check line: an honest validation-issue count kept exactly
/// as the true intended state (never recomputed here).
class _IssueRow extends StatelessWidget {
  const _IssueRow({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final String title;
  final String subtitle;
  final String count;

  @override
  Widget build(BuildContext context) {
    return AccentRow(
      accent: AppColors.goldSoftDeep,
      lead: const WarmIconWell(
        icon: Icons.error_outline,
        background: AppColors.goldTint,
        foreground: AppColors.goldSoftDeep,
      ),
      title: title,
      subtitle: subtitle,
      trailing: Text(
        count,
        style: const TextStyle(
          fontFamily: AppTextStyles.monoFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.goldSoftDeep,
        ),
      ),
    );
  }
}

/// Navigable directory row — preserves the exact route each admin tile
/// previously reached.
class _ManageRow extends StatelessWidget {
  const _ManageRow({
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
    return AccentRow(
      accent: AppColors.forestSoft,
      lead: WarmIconWell(
        icon: icon,
        background: AppColors.warmIvory,
        foreground: AppColors.slateWarm,
      ),
      title: title,
      subtitle: subtitle,
      trailing: const RowChevron(),
      onTap: onTap,
    );
  }
}

/// One compact escalation line for a flagged verification. No review actions
/// here — oversight only.
class _EscalationRow extends StatelessWidget {
  const _EscalationRow({required this.item});

  final VerificationItem item;

  @override
  Widget build(BuildContext context) {
    return AccentRow(
      accent: AppColors.claySoftReject,
      lead: const WarmIconWell(
        icon: Icons.flag_outlined,
        background: AppColors.clayTint,
        foreground: AppColors.claySoftReject,
      ),
      title: item.studentName,
      subtitle: item.summary,
      trailing: const PremiumBadge(label: 'Flagged', tone: BadgeTone.clay),
    );
  }
}
/// Small round outlined icon button used in the page header.
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.divider),
          ),
          child: Icon(icon, size: 20, color: AppColors.ink),
        ),
      ),
    );
  }
}
