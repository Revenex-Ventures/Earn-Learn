import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
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
    final hasCoords = location.latitude != null && location.longitude != null;
    final coords = hasCoords
        ? '${location.latitude!.toStringAsFixed(5)}, '
            '${location.longitude!.toStringAsFixed(5)}'
        : 'Configuration required';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const WarmIconWell(
                  icon: Icons.location_on_outlined,
                  gradient: AppColors.heroForest,
                  foreground: AppColors.onHeroWarm,
                  size: 44,
                  radius: 14,
                  iconSize: 20,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Work zone'),
                      const SizedBox(height: 2),
                      Text(
                        location.name,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          color: AppColors.inkWarm,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                PremiumBadge(
                  label: location.status.label,
                  tone: _locationTone(location.status),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            WarmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('Zone dossier'),
                  const SizedBox(height: 6),
                  InfoLine(
                    label: 'Description',
                    value: location.description ?? 'Not specified',
                  ),
                  const HairDivider(),
                  InfoLine(
                    label: 'Coordinates',
                    value: coords,
                    valueColor: hasCoords ? null : AppColors.claySoftReject,
                  ),
                  const HairDivider(),
                  InfoLine(
                    label: 'Geofence radius',
                    value: '${location.radiusMeters.toStringAsFixed(0)} m',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            MetricTileGrid(
              items: [
                MetricTileData(
                  label: 'Supervisors',
                  value: '${data.supervisors.length}',
                  desc: 'in charge',
                  tone: BadgeTone.forest,
                ),
                MetricTileData(
                  label: 'Stationed',
                  value: '${data.stationedStudents.length}',
                  desc: 'students',
                  tone: BadgeTone.gold,
                ),
                MetricTileData(
                  label: 'Shifts',
                  value: '${data.shiftLabels.length}',
                  desc: 'windows',
                  tone: BadgeTone.info,
                ),
              ],
            ),
            if (!hasCoords) ...[
              const SizedBox(height: 14),
              const NoteBox(
                icon: Icons.place_outlined,
                text:
                    'Geofence coordinates are Configuration required for this '
                    'site — zone verification stays dormant until they are set.',
              ),
            ],
            SectionEyebrow(
              eyebrow: 'Supervisors',
              title: 'In charge',
              trailing: PremiumBadge(
                label: '${data.supervisors.length}',
                tone: BadgeTone.slate,
              ),
            ),
            if (data.supervisors.isEmpty)
              const NoteBox(
                text: 'No supervisor is assigned to this work zone.',
              )
            else
              for (var i = 0; i < data.supervisors.length; i++) ...[
                _SupervisorRow(supervisor: data.supervisors[i]),
                if (i != data.supervisors.length - 1)
                  const SizedBox(height: 10),
              ],
            SectionEyebrow(
              eyebrow: 'Stationed',
              title: 'Students stationed',
              trailing: PremiumBadge(
                label: '${data.stationedStudents.length}',
                tone: BadgeTone.slate,
              ),
            ),
            if (data.stationedStudents.isEmpty)
              const NoteBox(
                text: 'No assignment currently routes students here.',
              )
            else
              for (var i = 0; i < data.stationedStudents.length; i++) ...[
                AccentRow(
                  accent: AppColors.forestSoftBright,
                  lead: InitialsBubble(
                    initials: data.stationedStudents[i].initials,
                    gradient: AppColors.heroForest,
                  ),
                  title: data.stationedStudents[i].name,
                  subtitle: data.stationedStudents[i].rollNumber,
                ),
                if (i != data.stationedStudents.length - 1)
                  const SizedBox(height: 10),
              ],
            SectionEyebrow(
              eyebrow: 'Shifts',
              title: 'Shift windows',
              trailing: PremiumBadge(
                label: '${data.shiftLabels.length}',
                tone: BadgeTone.slate,
              ),
            ),
            if (data.shiftLabels.isEmpty)
              const NoteBox(
                text: 'No shift windows are defined for this location.',
              )
            else
              for (var i = 0; i < data.shiftLabels.length; i++) ...[
                AccentRow(
                  accent: AppColors.goldSoftAccent,
                  lead: const WarmIconWell(
                    icon: Icons.schedule_outlined,
                    gradient: AppColors.goldSoftGrad,
                    foreground: Color(0xFF4A3915),
                  ),
                  title: data.shiftLabels[i],
                  subtitle: 'Shift window',
                ),
                if (i != data.shiftLabels.length - 1)
                  const SizedBox(height: 10),
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
    final (tone, accent) = _supervisorTone(supervisor.status);
    return AccentRow(
      accent: accent,
      lead: InitialsBubble(
        initials: supervisor.initials,
        gradient: AppColors.goldSoftGrad,
        foreground: const Color(0xFF4A3915),
      ),
      title: supervisor.name,
      subtitle: supervisor.departmentOrNA,
      trailing: PremiumBadge(label: supervisor.status.label, tone: tone),
    );
  }
}

/// Badge tone for a [LocationStatus].
BadgeTone _locationTone(LocationStatus status) => switch (status) {
      LocationStatus.active => BadgeTone.forest,
      LocationStatus.attention => BadgeTone.gold,
      LocationStatus.inactive => BadgeTone.slate,
    };

/// Maps a [SupervisorStatus] to a warm badge tone and left-accent colour.
(BadgeTone, Color) _supervisorTone(SupervisorStatus status) => switch (status) {
      SupervisorStatus.onDuty => (BadgeTone.forest, AppColors.forestSoftBright),
      SupervisorStatus.offDuty => (BadgeTone.slate, AppColors.slateWarm),
      SupervisorStatus.unavailable =>
        (BadgeTone.clay, AppColors.claySoftReject),
    };
