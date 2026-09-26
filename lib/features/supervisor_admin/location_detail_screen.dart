import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';
import '../../data/data.dart';
import '../../shared/components/components.dart';

/// Location dossier payload: description, supervisors, stationed students and
/// the unique shift windows present at the location.
class AdminLocationDetailData {
  const AdminLocationDetailData({
    this.location,
    required this.supervisors,
    required this.stationedStudents,
    required this.shiftLabels,
  });

  final Location? location;
  final List<Supervisor> supervisors;
  final List<Student> stationedStudents;
  final List<String> shiftLabels;
}

final _adminLocationDetailProvider = FutureProvider.autoDispose
    .family<AdminLocationDetailData?, String>((ref, locationId) async {
  final locations = ref.watch(locationRepositoryProvider);
  final supervisors = ref.watch(supervisorRepositoryProvider);
  final students = ref.watch(studentRepositoryProvider);
  final assignments = ref.watch(assignmentRepositoryProvider);

  final location = await locations.byId(locationId);
  if (location == null) return null;

  final allSupervisors = await supervisors.all();
  final allStudents = await students.all();
  final allAssignments = await assignments.all();

  final locationSupervisors = [
    for (final id in location.supervisorIds)
      for (final s in allSupervisors)
        if (s.id == id) s,
  ];
  final stationedIds = allAssignments
      .where((a) => a.locationId == locationId)
      .map((a) => a.studentId)
      .toSet();
  final stationedStudents = [
    for (final s in allStudents)
      if (stationedIds.contains(s.id)) s,
  ];
  final shiftLabels = allAssignments
      .where((a) => a.locationId == locationId)
      .map((a) => a.shiftLabel)
      .toSet()
      .toList()
    ..sort();

  return AdminLocationDetailData(
    location: location,
    supervisors: locationSupervisors,
    stationedStudents: stationedStudents,
    shiftLabels: shiftLabels,
  );
});

class AdminLocationDetailScreen extends ConsumerWidget {
  const AdminLocationDetailScreen({super.key, required this.locationId});

  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(_adminLocationDetailProvider(locationId));

    return snapshot.when(
      loading: () => const LoadingState(label: 'Loading location…'),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      data: (data) => data == null || data.location == null
          ? const SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: EmptyState(
                icon: Icons.location_off_outlined,
                title: 'Location not found',
                message:
                    'This work zone is not present in the institutional list.',
              ),
            )
          : _AdminLocationDetailView(data: data),
    );
  }
}

class _AdminLocationDetailView extends StatelessWidget {
  const _AdminLocationDetailView({required this.data});

  final AdminLocationDetailData data;

  @override
  Widget build(BuildContext context) {
    final location = data.location!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContextHeader(
              greeting: location.name,
              trailing: StatusBadge.status(style: location.status.style),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              eyebrow: 'ZONE',
              title: 'Description',
            ),
            const SizedBox(height: AppSpacing.md),
            ListRow(
              leading: const IconWell(icon: Icons.location_on_outlined),
              title: location.description ?? 'Campus work area',
              showChevron: false,
            ),
            const SizedBox(height: AppSpacing.xxl),
            SectionHeader(
              eyebrow: 'SUPERVISORS',
              title: 'Supervisors in charge',
              subtitle: '${data.supervisors.length} assigned',
            ),
            const SizedBox(height: AppSpacing.md),
            if (data.supervisors.isEmpty)
              const EmptyState(
                icon: Icons.person_search_outlined,
                title: 'No supervisors',
                message: 'No supervisor is assigned to this work zone.',
              )
            else
              for (var i = 0; i < data.supervisors.length; i++) ...[
                _SupervisorRow(supervisor: data.supervisors[i]),
                if (i != data.supervisors.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
            const SizedBox(height: AppSpacing.xxl),
            SectionHeader(
              eyebrow: 'STATIONED',
              title: 'Students stationed',
              subtitle: '${data.stationedStudents.length} assigned',
            ),
            const SizedBox(height: AppSpacing.md),
            if (data.stationedStudents.isEmpty)
              const EmptyState(
                icon: Icons.person_off_outlined,
                title: 'No students stationed',
                message: 'No assignment currently routes students here.',
              )
            else
              for (var i = 0; i < data.stationedStudents.length; i++) ...[
                ListRow(
                  leading: const IconWell(icon: Icons.person_outline),
                  title: data.stationedStudents[i].name,
                  subtitle: data.stationedStudents[i].rollNumber,
                  showChevron: false,
                ),
                if (i != data.stationedStudents.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
            const SizedBox(height: AppSpacing.xxl),
            const SectionHeader(
              eyebrow: 'SHIFTS',
              title: 'Shift windows',
              subtitle: 'Labels present across this location’s assignments.',
            ),
            const SizedBox(height: AppSpacing.md),
            if (data.shiftLabels.isEmpty)
              const EmptyState(
                icon: Icons.schedule_outlined,
                title: 'No shifts',
                message: 'No shift windows are defined for this location.',
              )
            else
              for (var i = 0; i < data.shiftLabels.length; i++) ...[
                ListRow(
                  leading: const IconWell(icon: Icons.schedule_outlined),
                  title: data.shiftLabels[i],
                  showChevron: false,
                ),
                if (i != data.shiftLabels.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ),
      ),
    );
  }
}

class _SupervisorRow extends StatelessWidget {
  const _SupervisorRow({required this.supervisor});

  final Supervisor supervisor;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      leading: const IconWell(icon: Icons.badge_outlined),
      title: supervisor.name,
      subtitle: supervisor.departmentOrNA,
      status: StatusBadge.status(style: supervisor.status.style),
      showChevron: false,
    );
  }
}