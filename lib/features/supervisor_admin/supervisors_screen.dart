import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';
import '../../data/data.dart';
import 'admin_identity_avatar.dart';
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContextHeader(
              greeting: 'Supervisors',
              trailing: AdminIdentityAvatar(),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              eyebrow: 'TEAM',
              title: 'Duty staff',
              subtitle: '${filtered.length} of ${data.supervisors.length} shown',
            ),
            const SizedBox(height: AppSpacing.md),
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
            if (filtered.isEmpty)
              const EmptyState(
                icon: Icons.person_search_outlined,
                title: 'No supervisors found',
                message:
                    'Try a different name or department filter.',
              )
            else
              for (var i = 0; i < filtered.length; i++) ...[
                _SupervisorRow(
                  supervisor: filtered[i],
                  locationCount:
                      data.locationCounts[filtered[i].id] ?? 0,
                  studentCount: data.studentCounts[filtered[i].id] ?? 0,
                ),
                if (i != filtered.length - 1)
                  const SizedBox(height: AppSpacing.sm),
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
  });

  final Supervisor supervisor;
  final int locationCount;
  final int studentCount;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      leading: const IconWell(icon: Icons.badge_outlined),
      title: supervisor.name,
      subtitle:
          '${supervisor.departmentOrNA} • $locationCount locations',
      status: StatusBadge.status(style: supervisor.status.style),
      trailing: Text(
        '$studentCount',
        style: AppTextStyles.statSmall,
      ),
      showChevron: false,
    );
  }
}