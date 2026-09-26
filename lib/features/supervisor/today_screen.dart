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
import 'review_sheet.dart';

/// View model for the supervisor today screen.
class SupervisorTodayData {
  const SupervisorTodayData({
    required this.supervisor,
    required this.verificationItems,
    required this.active,
    required this.myLocations,
    required this.myAssignments,
  });

  final Supervisor supervisor;
  final List<VerificationItem> verificationItems;
  final List<VerificationItem> active;
  final List<Location> myLocations;

  /// Assignments whose supervisor is the signed-in account entity.
  final List<Assignment> myAssignments;
}

final _supervisorTodayProvider =
    FutureProvider.autoDispose<SupervisorTodayData>((ref) async {
  final account = ref.watch(accountRepositoryProvider);
  final supervisors = ref.watch(supervisorRepositoryProvider);
  final assignments = ref.watch(assignmentRepositoryProvider);
  final locations = ref.watch(locationRepositoryProvider);
  final verification = ref.watch(verificationRepositoryProvider);

  final user = await account.currentUser();
  final link = await account.currentAccountLink();
  final entityId = link?.entityId;
  var supervisor =
      entityId == null ? null : await supervisors.byId(entityId);
  if (supervisor == null && !AppFlavor.useFirebase) {
    final allSupervisors = await supervisors.all();
    if (allSupervisors.isNotEmpty) {
      supervisor = allSupervisors.first;
    }
  }
  if (user == null || supervisor == null) {
    throw StateError('No supervisor linked to the signed-in account.');
  }

  final resolvedSupervisor = supervisor;
  final allAssignments = await assignments.all();
  final allLocations = await locations.all();
  final items = await verification.items();

  final myAssignments = allAssignments
      .where((a) => a.supervisorId == resolvedSupervisor.id)
      .toList();

  final active = items
      .where((v) =>
          v.type == VerificationType.checkIn &&
          v.status != ApprovalStatus.rejected)
      .toList();

  final myLocations = allLocations
      .where((l) => resolvedSupervisor.assignedLocationIds.contains(l.id))
      .toList();

  return SupervisorTodayData(
    supervisor: resolvedSupervisor,
    verificationItems: items,
    active: active,
    myLocations: myLocations,
    myAssignments: myAssignments,
  );
});

/// Supervisor Today.
///
/// Answers "who needs my attention?" first, then active students and the
/// supervisor's own work zones.
class SupervisorTodayScreen extends ConsumerWidget {
  const SupervisorTodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(_supervisorTodayProvider);

    return snapshot.when(
      loading: () => const _CenteredNote(
        icon: Icons.hourglass_empty,
        text: 'Loading today’s queue…',
      ),
      error: (error, _) => _CenteredNote(
        icon: Icons.error_outline,
        text: error.toString(),
      ),
      data: (data) => _SupervisorTodayView(data: data),
    );
  }
}

class _SupervisorTodayView extends ConsumerWidget {
  const _SupervisorTodayView({required this.data});

  final SupervisorTodayData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supervisor = data.supervisor;
    final open = data.verificationItems
        .where((v) => v.status != ApprovalStatus.approved)
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    final preview = open.take(3).toList();
    final flagged = data.verificationItems
        .where((v) => v.status == ApprovalStatus.flagged)
        .length;
    final active = data.active;

    final verifiedToday = data.verificationItems
        .where((v) => v.status == ApprovalStatus.approved)
        .length;

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
                        supervisor.name,
                        style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.marigoldLight,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: AppColors.marigold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined, size: 14, color: AppColors.marigold),
                      const SizedBox(width: 4),
                      Text(
                        'Supervisor',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.marigold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Today's Shift Hero Card (AVCOE Deep Green Container)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.avcoeGreen,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.avcoeGreen.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -10,
                    bottom: -15,
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 90,
                      color: AppColors.surface.withValues(alpha: 0.1),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 18, color: AppColors.surface),
                          const SizedBox(width: 8),
                          Text(
                            "Today's Shift",
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.surface.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '8:00 AM – 4:00 PM',
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: AppColors.surface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Text(
                            'Total Students: ',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.surface.withValues(alpha: 0.85),
                            ),
                          ),
                          Text(
                            '${data.myAssignments.length}',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.surface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 3-Metric Summary Row matching reference
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Pending Reviews',
                    value: '${open.length}',
                    color: AppColors.marigold,
                    bgColor: AppColors.marigoldLight,
                    icon: Icons.hourglass_top,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _MetricCard(
                    label: 'Verified Today',
                    value: '$verifiedToday',
                    color: AppColors.avcoeGreen,
                    bgColor: AppColors.sageLight,
                    icon: Icons.verified_outlined,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _MetricCard(
                    label: 'Flags',
                    value: '$flagged',
                    color: AppColors.clay,
                    bgColor: AppColors.clayLight,
                    icon: Icons.flag_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Quick Actions Section
            Text('Quick Actions', style: AppTextStyles.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _SupervisorActionTile(
                    icon: Icons.people_outline,
                    label: 'View Students',
                    onTap: () => context.go(RoutePaths.supervisorStudents),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SupervisorActionTile(
                    icon: Icons.calendar_month_outlined,
                    label: 'Attendance',
                    onTap: () => context.go(RoutePaths.supervisorAttendance),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _SupervisorActionTile(
                    icon: Icons.assignment_turned_in_outlined,
                    label: 'Approvals',
                    onTap: () => context.go(RoutePaths.supervisorAttendance),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SupervisorActionTile(
                    icon: Icons.bar_chart_outlined,
                    label: 'Reports',
                    onTap: () => _snack(context, 'Monthly attendance report'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Duty Zones
            _DutySurface(
              supervisor: supervisor,
              locations: data.myLocations,
              countFor: (location) => data.myAssignments
                  .where((a) => a.locationId == location.id)
                  .length,
              onLocationTap: (location) =>
                  _snack(context, '${location.name} — zone details.'),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Review Queue
            SectionHeader(
              eyebrow: 'APPROVAL QUEUE',
              title: 'Reviews',
              trailing: InkWell(
                onTap: () => context.go(RoutePaths.supervisorAttendance),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: Text(
                    'View all',
                    style: AppTextStyles.labelMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (preview.isEmpty)
              const EmptyState(
                icon: Icons.done_all,
                title: 'All clear',
                message: 'No items are waiting on a decision right now.',
              )
            else
              for (var i = 0; i < preview.length; i++) ...[
                _ReviewRow(
                  item: preview[i],
                  onTap: () => _openReview(context, ref, preview[i]),
                ),
                if (i != preview.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
            const SizedBox(height: AppSpacing.xl),

            // Active Now
            SectionHeader(
              eyebrow: 'ACTIVE NOW',
              title: 'On site',
              subtitle: active.isEmpty
                  ? 'No live check-ins right now.'
                  : '${active.length} student(s) checked in across your zones.',
            ),
            const SizedBox(height: AppSpacing.md),
            if (active.isEmpty)
              const EmptyState(
                icon: Icons.work_off_outlined,
                title: 'No one is on site',
                message: 'Live check-ins will appear here.',
              )
            else
              for (var i = 0; i < active.length; i++) ...[
                _ActiveRow(item: active[i]),
                if (i != active.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ),
      ),
    );
  }

  void _openReview(BuildContext context, WidgetRef ref, VerificationItem item) {
    if (!AppFlavor.useFirebase) {
      _snack(context, 'Review ${item.studentName} — ${item.type.label}');
      return;
    }
    final gateway = ref.read(attendanceGatewayProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => ReviewSheet(
        item: item,
        evidenceUrlBuilder: (kind) => gateway.evidenceUrl(
          sessionId: item.id,
          studentId: item.studentId,
          kind: kind,
        ),
        onSubmit: (decision, note) => gateway.review(
          sessionId: item.id,
          studentId: item.studentId,
          decision: decision,
          note: note,
        ),
      ),
    ).then((_) => ref.invalidate(_supervisorTodayProvider));
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Single surface for the supervisor's duty identity and work zones.
class _DutySurface extends StatelessWidget {
  const _DutySurface({
    required this.supervisor,
    required this.locations,
    required this.countFor,
    required this.onLocationTap,
  });

  final Supervisor supervisor;
  final List<Location> locations;
  final int Function(Location location) countFor;
  final ValueChanged<Location> onLocationTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconWell(icon: Icons.badge_outlined),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(supervisor.name, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      supervisor.departmentOrNA,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusBadge.status(style: supervisor.status.style),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1, color: AppColors.divider),
          ),
          if (locations.isEmpty)
            Text(
              'No work zones assigned.',
              style: AppTextStyles.bodySmall,
            )
          else
            for (var i = 0; i < locations.length; i++) ...[
              _LocationRow(
                location: locations[i],
                count: countFor(locations[i]),
                onTap: () => onLocationTap(locations[i]),
              ),
              if (i != locations.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Divider(height: 1, color: AppColors.divider),
                ),
            ],
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.location,
    required this.count,
    required this.onTap,
  });

  final Location location;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              const IconWell(
                icon: Icons.location_on_outlined,
                color: AppColors.sage,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(location.name, style: AppTextStyles.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '$count students at zone',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusBadge.status(style: location.status.style),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.item, required this.onTap});

  final VerificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = item.status.style;
    return ListRow(
      title: item.studentName,
      subtitle: '${item.type.label} • ${item.location}',
      leading: IconWell(icon: _typeIcon(item.type), color: style.color),
      status: StatusBadge.status(style: style),
      onTap: onTap,
    );
  }
}

class _ActiveRow extends StatelessWidget {
  const _ActiveRow({required this.item});

  final VerificationItem item;

  @override
  Widget build(BuildContext context) {
    final style = item.status.style;
    return ListRow(
      title: item.studentName,
      subtitle: item.location,
      leading: IconWell(icon: Icons.person_outline, color: style.color),
      showChevron: false,
      status: StatusBadge.status(style: style),
      trailing: Text(_clock(item.submittedAt), style: AppTextStyles.labelSmall),
    );
  }
}

IconData _typeIcon(VerificationType type) => switch (type) {
      VerificationType.checkIn => Icons.login,
      VerificationType.checkOut => Icons.logout,
      VerificationType.attendanceAudit => Icons.fact_check_outlined,
      VerificationType.correction => Icons.edit_note,
    };

class _CenteredNote extends StatelessWidget {
  const _CenteredNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: AppColors.slate),
            const SizedBox(height: AppSpacing.md),
            Text(text, style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.slate,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SupervisorActionTile extends StatelessWidget {
  const _SupervisorActionTile({
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
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
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: AppColors.ink),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _clock(DateTime t) => DateFormat('h:mm a').format(t).toLowerCase();