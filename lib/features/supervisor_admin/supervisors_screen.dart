import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/models/models.dart';
import '../../data/data.dart';
import 'admin_identity_avatar.dart';
import 'roster_actions.dart';
import '../../shared/components/components.dart';

/// Team payload for the admin supervisors directory with coverage joins.
class AdminSupervisorsData {
  const AdminSupervisorsData({
    required this.supervisors,
    required this.locationCounts,
    required this.studentCounts,
  });

  final List<Supervisor> supervisors;

  /// Locations joined via `supervisor.assignedLocationIds`.
  final Map<String, int> locationCounts;

  /// Students joined via the assignment directory (by supervisorId).
  final Map<String, int> studentCounts;
}

final _adminSupervisorsProvider =
    FutureProvider.autoDispose<AdminSupervisorsData>((ref) async {
  final supervisors = ref.watch(supervisorRepositoryProvider);
  final locations = ref.watch(locationRepositoryProvider);
  final assignments = ref.watch(assignmentRepositoryProvider);

  final allSup = await supervisors.all();
  final allLoc = await locations.all();
  final allAsn = await assignments.all();

  return AdminSupervisorsData(
    supervisors: allSup,
    locationCounts: {
      for (final s in allSup)
        s.id: allLoc.where((l) => s.assignedLocationIds.contains(l.id)).length,
    },
    studentCounts: {
      for (final s in allSup)
        s.id: allAsn.where((a) => a.supervisorId == s.id).length,
    },
  );
});

class AdminSupervisorsScreen extends ConsumerStatefulWidget {
  const AdminSupervisorsScreen({super.key});

  @override
  ConsumerState<AdminSupervisorsScreen> createState() =>
      _AdminSupervisorsScreenState();
}

class _AdminSupervisorsScreenState extends ConsumerState<AdminSupervisorsScreen> {
  String _query = '';
  String? _department;

  List<Supervisor> _filter(List<Supervisor> all) {
    final q = _query.trim().toLowerCase();
    return all.where((s) {
      if (_department != null && s.departmentOrNA != _department) return false;
      if (q.isEmpty) return true;
      return s.name.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(_adminSupervisorsProvider);

    return snapshot.when(
      loading: () => const LoadingState(label: 'Loading supervisors…'),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      data: (data) => _build(context, data),
    );
  }

  Widget _build(BuildContext context, AdminSupervisorsData data) {
    final filtered = _filter(data.supervisors);
    final departments = {
      for (final s in data.supervisors) s.departmentOrNA,
    }.toList()
      ..sort();
    final options = <SearchFilterOption>[
      const SearchFilterOption(label: 'All'),
      for (final d in departments) SearchFilterOption(label: d, value: d),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DirectoryHeader(
              icon: Icons.badge_outlined,
              eyebrow: 'Team',
              title: 'Supervisors',
            ),
            SectionEyebrow(
              eyebrow: 'Duty staff',
              title: 'In-charge directory',
              trailing: PremiumBadge(
                label: '${filtered.length} of ${data.supervisors.length}',
                tone: BadgeTone.slate,
              ),
            ),
            SearchFilterBar(
              hintText: 'Search by name or department',
              initialQuery: _query,
              onQueryChanged: (value) => setState(() => _query = value),
              filters: options,
              selected: _department,
              onFilterSelected: (value) =>
                  setState(() => _department = value as String?),
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => showAddSupervisorSheet(context, ref),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add supervisor'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.avcoeGreen,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (filtered.isEmpty)
              const EmptyState(
                icon: Icons.person_search_outlined,
                title: 'No supervisors found',
                message: 'Try a different name or department filter.',
              )
            else
              for (var i = 0; i < filtered.length; i++) ...[
                _SupervisorRow(
                  supervisor: filtered[i],
                  locationCount: data.locationCounts[filtered[i].id] ?? 0,
                  studentCount: data.studentCounts[filtered[i].id] ?? 0,
                  onRemove: () => confirmRemoveSupervisor(
                    context,
                    ref,
                    supervisor: filtered[i],
                  ),
                ),
                if (i != filtered.length - 1) const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _SupervisorRow extends StatelessWidget {
  const _SupervisorRow({
    required this.supervisor,
    required this.locationCount,
    required this.studentCount,
    required this.onRemove,
  });

  final Supervisor supervisor;
  final int locationCount;
  final int studentCount;
  final VoidCallback onRemove;

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
      subtitle:
          '${supervisor.departmentOrNA} • $locationCount locations • $studentCount students',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PremiumBadge(label: supervisor.status.label, tone: tone),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Manage',
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) {
              if (value == 'remove') onRemove();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'remove',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_remove_alt_1),
                  title: Text('Remove'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Warm-premium page header for the admin directory screens.
class _DirectoryHeader extends StatelessWidget {
  const _DirectoryHeader({
    required this.icon,
    required this.eyebrow,
    required this.title,
  });

  final IconData icon;
  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        WarmIconWell(
          icon: icon,
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
              Eyebrow(eyebrow),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  color: AppColors.inkWarm,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const AdminIdentityAvatar(),
      ],
    );
  }
}

/// Maps a [SupervisorStatus] to a warm badge tone and left-accent colour.
(BadgeTone, Color) _supervisorTone(SupervisorStatus status) => switch (status) {
      SupervisorStatus.onDuty => (BadgeTone.forest, AppColors.forestSoftBright),
      SupervisorStatus.offDuty => (BadgeTone.slate, AppColors.slateWarm),
      SupervisorStatus.unavailable =>
        (BadgeTone.clay, AppColors.claySoftReject),
    };
