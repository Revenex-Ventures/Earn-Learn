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

    final rosterCount = data.myAssignments.length;
    final zoneCount = data.myLocations.length;
    final heroCaption = zoneCount == 0
        ? '$rosterCount ${rosterCount == 1 ? 'student' : 'students'} on your roster · no work zones assigned yet'
        : '$rosterCount ${rosterCount == 1 ? 'student' : 'students'} on your roster · $zoneCount ${zoneCount == 1 ? 'zone' : 'zones'}';

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
                  initials: supervisor.initials,
                  gradient: AppColors.heroForest,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Supervisor',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.slate,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        supervisor.name,
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
                  onTap: () => context.go(RoutePaths.supervisorProfile),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            EspressoHero(
              value: '${open.length}',
              unit: 'awaiting\nreview',
              caption: heroCaption,
              leftPill:
                  const HeroPill(label: 'Sign-off desk', icon: Icons.shield_outlined),
              rightPill: HeroPill(label: supervisor.id, gold: true),
              stats: [
                HeroStat(
                    label: 'Approved today', value: '$verifiedToday', gold: true),
                HeroStat(label: 'Flagged', value: '$flagged'),
                HeroStat(label: 'On duty', value: '${active.length}'),
              ],
            ),
            const SectionEyebrow(eyebrow: 'This desk'),
            MetricTileGrid(items: [
              MetricTileData(
                label: 'Roster',
                value: '$rosterCount',
                desc: rosterCount == 1 ? 'student assigned' : 'students assigned',
              ),
              MetricTileData(
                label: 'Work zones',
                value: '$zoneCount',
                desc: 'assigned to you',
                tone: BadgeTone.gold,
              ),
              MetricTileData(
                label: 'Pending',
                value: '${open.length}',
                desc: 'awaiting review',
                tone: BadgeTone.terra,
              ),
              MetricTileData(
                label: 'Verified',
                value: '$verifiedToday',
                desc: 'approved today',
              ),
            ]),
            const SectionEyebrow(eyebrow: 'Quick actions'),
            Row(
              children: [
                Expanded(
                  child: QuickAction(
                    icon: Icons.people_outline,
                    label: 'Students',
                    sub: 'Your roster',
                    iconGradient: AppColors.heroForest,
                    onTap: () => context.go(RoutePaths.supervisorStudents),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: QuickAction(
                    icon: Icons.assignment_turned_in_outlined,
                    label: 'Reviews',
                    sub: 'Approval queue',
                    iconColor: WarmKit.espressoBase,
                    onTap: () => context.go(RoutePaths.supervisorAttendance),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: QuickAction(
                    icon: Icons.bar_chart_outlined,
                    label: 'Reports',
                    sub: 'Monthly',
                    iconGradient: AppColors.goldSoftGrad,
                    iconFg: const Color(0xFF4A3915),
                    onTap: () => _snack(context, 'Monthly attendance report'),
                  ),
                ),
              ],
            ),
            const SectionEyebrow(eyebrow: 'Work zones'),
            if (data.myLocations.isEmpty)
              const SoftBox(
                label: 'No work zones assigned yet.',
                tone: BadgeTone.slate,
                icon: Icons.place_outlined,
              )
            else
              for (var i = 0; i < data.myLocations.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                Builder(builder: (context) {
                  final location = data.myLocations[i];
                  final count = data.myAssignments
                      .where((a) => a.locationId == location.id)
                      .length;
                  return AccentRow(
                    accent: AppColors.forestSoft,
                    lead: const WarmIconWell(
                      icon: Icons.location_on_outlined,
                      gradient: AppColors.heroForest,
                      foreground: AppColors.onHeroWarm,
                    ),
                    title: location.name,
                    subtitle:
                        '$count ${count == 1 ? 'student' : 'students'} at zone',
                    trailing: const RowChevron(),
                    onTap: () =>
                        _snack(context, '${location.name} — zone details.'),
                  );
                }),
              ],
            SectionEyebrow(
              eyebrow: 'Pending sessions',
              trailing: _ViewAll(
                onTap: () => context.go(RoutePaths.supervisorAttendance),
              ),
            ),
            if (preview.isEmpty)
              const SoftBox(
                label: 'All clear — nothing awaiting a decision.',
                tone: BadgeTone.forest,
                icon: Icons.done_all,
              )
            else
              for (var i = 0; i < preview.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                AccentRow(
                  accent: _accentFor(preview[i].status),
                  lead: InitialsBubble(
                    initials: _initials(preview[i].studentName),
                    gradient: _leadGradient(preview[i].status),
                    foreground: _leadFg(preview[i].status),
                  ),
                  title: preview[i].studentName,
                  subtitle: preview[i].summary,
                  trailing: PremiumBadge(
                    label: preview[i].status.label,
                    tone: _toneFor(preview[i].status),
                  ),
                  onTap: () => _openReview(context, ref, preview[i]),
                ),
              ],
            const SectionEyebrow(eyebrow: 'Active now'),
            if (active.isEmpty)
              const SoftBox(
                label: 'No live check-ins right now.',
                tone: BadgeTone.info,
                icon: Icons.work_off_outlined,
              )
            else
              for (var i = 0; i < active.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                AccentRow(
                  accent: AppColors.terraSpark,
                  lead: const WarmIconWell(
                    icon: Icons.person_outline,
                    gradient: AppColors.terraGrad,
                    foreground: AppColors.warmSurface,
                  ),
                  title: active[i].studentName,
                  subtitle: active[i].location,
                  trailing: Text(
                    _clock(active[i].submittedAt),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.slateWarm,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }

  void _openReview(BuildContext context, WidgetRef ref, VerificationItem item) {
    final gateway = ref.read(attendanceGatewayProvider);
    // Server evidence (signed URLs) only exists on the Firebase build; the
    // local build shows the neutral evidence placeholder instead of a broken
    // network image.
    final useServerEvidence = AppFlavor.useFirebase;
    ApprovalStatus? outcome;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => ReviewSheet(
        item: item,
        evidenceUrlBuilder: useServerEvidence
            ? (kind) => gateway.evidenceUrl(
                  sessionId: item.id,
                  studentId: item.studentId,
                  kind: kind,
                )
            : null,
        onSubmit: (decision, note) async {
          final result = await gateway.review(
            sessionId: item.id,
            studentId: item.studentId,
            decision: decision,
            note: note,
          );
          outcome = result.review;
          return result;
        },
      ),
    ).then((_) {
      ref.invalidate(_supervisorTodayProvider);
      final decided = outcome;
      if (decided != null && context.mounted) {
        _snack(context, _reviewMessage(item.studentName, decided));
      }
    });
  }

  String _reviewMessage(String name, ApprovalStatus review) => switch (review) {
        ApprovalStatus.approved => 'Verified — $name signed off.',
        ApprovalStatus.flagged => 'Flagged — sent back for another look.',
        ApprovalStatus.rejected => 'Rejected — $name notified.',
        ApprovalStatus.pending => 'Saved — still pending.',
      };

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

BadgeTone _toneFor(ApprovalStatus status) => switch (status) {
      ApprovalStatus.approved => BadgeTone.forest,
      ApprovalStatus.flagged => BadgeTone.terra,
      ApprovalStatus.rejected => BadgeTone.clay,
      ApprovalStatus.pending => BadgeTone.gold,
    };

Color _accentFor(ApprovalStatus status) => switch (status) {
      ApprovalStatus.approved => AppColors.forestSoft,
      ApprovalStatus.flagged => AppColors.terraSpark,
      ApprovalStatus.rejected => AppColors.claySoftReject,
      ApprovalStatus.pending => AppColors.goldSoftDeep,
    };

Gradient _leadGradient(ApprovalStatus status) => switch (status) {
      ApprovalStatus.approved => AppColors.heroForest,
      ApprovalStatus.pending => AppColors.goldSoftGrad,
      _ => AppColors.terraGrad,
    };

Color _leadFg(ApprovalStatus status) =>
    status == ApprovalStatus.pending ? const Color(0xFF4A3915) : AppColors.warmSurface;

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '—';
  if (parts.length == 1) {
    return parts.first.characters.take(2).toString().toUpperCase();
  }
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

String _clock(DateTime t) => DateFormat('h:mm a').format(t).toLowerCase();

class _ViewAll extends StatelessWidget {
  const _ViewAll({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'View all',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.goldSoftDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.goldSoftDeep),
          ],
        ),
      ),
    );
  }
}

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
