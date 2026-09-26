import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/routing/route_paths.dart';
import '../../data/data.dart';
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ContextHeader(
              greeting: 'Manage',
              trailing: InitialsAvatar(name: 'SDO In-Charge'),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              eyebrow: 'DIRECTORIES',
              title: 'Program records',
              subtitle: 'Every directory with its current live count.',
            ),
            const SizedBox(height: AppSpacing.md),
            _DirectoryTile(
              icon: Icons.school_outlined,
              title: 'Students',
              subtitle: 'Registered roster',
              count: data.students,
              color: AppColors.sage,
              onTap: () => context.go(RoutePaths.adminStudents),
            ),
            const SizedBox(height: AppSpacing.sm),
            _DirectoryTile(
              icon: Icons.supervisor_account_outlined,
              title: 'Supervisors',
              subtitle: 'Duty staff',
              count: data.supervisors,
              color: AppColors.marigold,
              onTap: () => context.go(RoutePaths.adminSupervisors),
            ),
            const SizedBox(height: AppSpacing.sm),
            _DirectoryTile(
              icon: Icons.location_on_outlined,
              title: 'Locations',
              subtitle: 'Work zones',
              count: data.locations,
              color: AppColors.info,
              onTap: () => context.go(RoutePaths.adminLocations),
            ),
            const SizedBox(height: AppSpacing.sm),
            _DirectoryTile(
              icon: Icons.assignment_outlined,
              title: 'Assignments',
              subtitle: 'Active shifts',
              count: data.assignments,
              color: AppColors.inkSoft,
              onTap: () => context.go(RoutePaths.adminAssignments),
            ),
            const SizedBox(height: AppSpacing.sm),
            _DirectoryTile(
              icon: Icons.event_note_outlined,
              title: 'Calendar',
              subtitle: 'Off days & holidays this month',
              count: data.monthEvents,
              color: AppColors.clay,
              onTap: () => context.go(RoutePaths.adminCalendar),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hub tile: IconWell, title, description and the real trailing count.
class _DirectoryTile extends StatelessWidget {
  const _DirectoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.onTap,
    this.color = AppColors.ink,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              IconWell(icon: icon, color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('$count', style: AppTextStyles.statMedium),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.slate),
            ],
          ),
        ),
      ),
    );
  }
}