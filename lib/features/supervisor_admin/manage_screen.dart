import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/routing/route_paths.dart';
import '../../data/data.dart';
import 'admin_identity_avatar.dart';
import '../../shared/components/components.dart';

/// Directory counts for the management hub, driven by the real repositories.
class AdminManageData {
  const AdminManageData({
    required this.students,
    required this.supervisors,
    required this.locations,
    required this.assignments,
    required this.monthEvents,
  });

  final int students;
  final int supervisors;
  final int locations;
  final int assignments;
  final int monthEvents;
}

final _adminManageProvider = FutureProvider.autoDispose<AdminManageData>(
    (ref) async {
  final students = ref.watch(studentRepositoryProvider);
  final supervisors = ref.watch(supervisorRepositoryProvider);
  final locations = ref.watch(locationRepositoryProvider);
  final assignments = ref.watch(assignmentRepositoryProvider);
  final calendar = ref.watch(calendarRepositoryProvider);

  final now = DateTime.now();
  final events =
      await calendar.eventsForMonth(DateTime(now.year, now.month));

  return AdminManageData(
    students: (await students.all()).length,
    supervisors: (await supervisors.all()).length,
    locations: (await locations.all()).length,
    assignments: (await assignments.all()).length,
    monthEvents: events.length,
  );
});

class AdminManageScreen extends ConsumerWidget {
  const AdminManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(_adminManageProvider);

    return snapshot.when(
      loading: () => const LoadingState(label: 'Loading directories…'),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      data: (data) => _AdminManageView(data: data),
    );
  }
}

class _AdminManageView extends StatelessWidget {
  const _AdminManageView({required this.data});

  final AdminManageData data;

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
                        'Manage',
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
              eyebrow: 'Directory',
              title: 'Program records',
            ),
            _DirectoryRow(
              icon: Icons.school_outlined,
              title: 'Students',
              subtitle: 'Registered roster',
              count: data.students,
              accent: AppColors.forestSoft,
              gradient: AppColors.heroForest,
              onTap: () => context.go(RoutePaths.adminStudents),
            ),
            const SizedBox(height: 10),
            _DirectoryRow(
              icon: Icons.supervisor_account_outlined,
              title: 'Supervisors',
              subtitle: 'Duty staff',
              count: data.supervisors,
              accent: AppColors.goldSoftAccent,
              gradient: AppColors.goldSoftGrad,
              iconFg: const Color(0xFF4A3915),
              onTap: () => context.go(RoutePaths.adminSupervisors),
            ),
            const SizedBox(height: 10),
            _DirectoryRow(
              icon: Icons.location_on_outlined,
              title: 'Locations',
              subtitle: 'Work zones',
              count: data.locations,
              accent: AppColors.infoSoft,
              background: AppColors.infoSoft,
              onTap: () => context.go(RoutePaths.adminLocations),
            ),
            const SizedBox(height: 10),
            _DirectoryRow(
              icon: Icons.assignment_outlined,
              title: 'Assignments',
              subtitle: 'Active shifts',
              count: data.assignments,
              accent: AppColors.forestSoftBright,
              background: AppColors.forestSoftBright,
              onTap: () => context.go(RoutePaths.adminAssignments),
            ),
            const SizedBox(height: 10),
            _DirectoryRow(
              icon: Icons.event_note_outlined,
              title: 'Calendar',
              subtitle: 'Off days & holidays this month',
              count: data.monthEvents,
              accent: AppColors.claySoftReject,
              background: AppColors.claySoftReject,
              onTap: () => context.go(RoutePaths.adminCalendar),
            ),
          ],
        ),
      ),
    );
  }
}

/// Directory entry point: gradient/solid [WarmIconWell] lead, title/subtitle
/// and the real live count next to a chevron.
class _DirectoryRow extends StatelessWidget {
  const _DirectoryRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.accent,
    required this.onTap,
    this.gradient,
    this.background,
    this.iconFg = AppColors.onHeroWarm,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final Color accent;
  final VoidCallback onTap;
  final Gradient? gradient;
  final Color? background;
  final Color iconFg;

  @override
  Widget build(BuildContext context) {
    return AccentRow(
      accent: accent,
      lead: WarmIconWell(
        icon: icon,
        gradient: gradient,
        background: background,
        foreground: iconFg,
      ),
      title: title,
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: AppTextStyles.statSmall.copyWith(
              fontFamily: AppTextStyles.monoFamily,
              color: AppColors.inkWarm,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const RowChevron(),
        ],
      ),
      onTap: onTap,
    );
  }
}
