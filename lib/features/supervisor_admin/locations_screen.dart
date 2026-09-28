import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/models/models.dart';
import '../../data/data.dart';
import 'admin_identity_avatar.dart';
import '../../shared/components/components.dart';

/// Work-zone payload with stationed-student counts from the assignment join.
class AdminLocationsData {
  const AdminLocationsData({
    required this.locations,
    required this.studentCounts,
  });

  final List<Location> locations;

  /// Number of students stationed at each location (from assignments).
  final Map<String, int> studentCounts;
}

final _adminLocationsProvider =
    FutureProvider.autoDispose<AdminLocationsData>((ref) async {
  final locations = ref.watch(locationRepositoryProvider);
  final assignments = ref.watch(assignmentRepositoryProvider);

  final allLoc = await locations.all();
  final allAsn = await assignments.all();

  return AdminLocationsData(
    locations: allLoc,
    studentCounts: {
      for (final l in allLoc)
        l.id: allAsn.where((a) => a.locationId == l.id).length,
    },
  );
});

class AdminLocationsScreen extends ConsumerStatefulWidget {
  const AdminLocationsScreen({super.key});

  @override
  ConsumerState<AdminLocationsScreen> createState() =>
      _AdminLocationsScreenState();
}

class _AdminLocationsScreenState extends ConsumerState<AdminLocationsScreen> {
  String _query = '';

  List<Location> _filter(List<Location> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((l) =>
            l.name.toLowerCase().contains(q) ||
            (l.description ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(_adminLocationsProvider);

    return snapshot.when(
      loading: () => const LoadingState(label: 'Loading locations…'),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      data: (data) => _build(context, data),
    );
  }

  Widget _build(BuildContext context, AdminLocationsData data) {
    final filtered = _filter(data.locations);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DirectoryHeader(
              icon: Icons.location_on_outlined,
              eyebrow: 'Zones',
              title: 'Locations',
            ),
            SectionEyebrow(
              eyebrow: 'Work locations',
              title: 'Duty sites',
              trailing: PremiumBadge(
                label: '${filtered.length} of ${data.locations.length}',
                tone: BadgeTone.slate,
              ),
            ),
            SearchFilterBar(
              hintText: 'Search by name or description',
              initialQuery: _query,
              onQueryChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: AppSpacing.md),
            if (filtered.isEmpty)
              const EmptyState(
                icon: Icons.location_off_outlined,
                title: 'No locations found',
                message: 'Try a different search term.',
              )
            else ...[
              // Grouped by staffing, because "no supervisor assigned" is the
              // actionable fact an administrator opens this screen for. The
              // data carries no zone or building field, so grouping by one
              // would mean inventing it.
              _LocationGroup(
                title: 'Needs a supervisor',
                eyebrow: 'Unstaffed',
                locations:
                    filtered.where((l) => l.supervisorIds.isEmpty).toList(),
                studentCounts: data.studentCounts,
                emptyMessage: 'Every work location has a supervisor assigned.',
              ),
              _LocationGroup(
                title: 'Supervised',
                eyebrow: 'Staffed',
                locations:
                    filtered.where((l) => l.supervisorIds.isNotEmpty).toList(),
                studentCounts: data.studentCounts,
                emptyMessage: 'No supervised locations match this search.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocationGroup extends StatelessWidget {
  const _LocationGroup({
    required this.title,
    required this.eyebrow,
    required this.locations,
    required this.studentCounts,
    required this.emptyMessage,
  });

  final String title;
  final String eyebrow;
  final List<Location> locations;
  final Map<String, int> studentCounts;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionEyebrow(
          eyebrow: eyebrow,
          title: title,
          trailing: PremiumBadge(
            label: '${locations.length}',
            tone: BadgeTone.slate,
          ),
        ),
        if (locations.isEmpty)
          NoteBox(text: emptyMessage)
        else
          for (var i = 0; i < locations.length; i++) ...[
            _LocationRow(
              location: locations[i],
              studentCount: studentCounts[locations[i].id] ?? 0,
            ),
            if (i != locations.length - 1) const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.location, required this.studentCount});

  final Location location;
  final int studentCount;

  @override
  Widget build(BuildContext context) {
    final unstaffed = location.supervisorIds.isEmpty;
    final accent =
        unstaffed ? AppColors.claySoftReject : AppColors.forestSoftBright;
    final subtitle = unstaffed
        ? '$studentCount students • Supervisor: Not assigned'
        : '$studentCount students • ${location.supervisorIds.length} '
            'supervisor${location.supervisorIds.length == 1 ? '' : 's'}';

    return AccentRow(
      accent: accent,
      lead: WarmIconWell(
        icon: Icons.location_on_outlined,
        background: unstaffed ? AppColors.slateWarm : null,
        gradient: unstaffed ? null : AppColors.heroForest,
        foreground: AppColors.onHeroWarm,
      ),
      title: location.name,
      subtitle: subtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PremiumBadge(
            label: unstaffed ? 'Unassigned' : location.status.label,
            tone: _locationTone(unstaffed, location.status),
          ),
          const SizedBox(width: 8),
          const RowChevron(),
        ],
      ),
      onTap: () => context.go('/admin/locations/${location.id}'),
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

/// Badge tone for a location row: unstaffed reads as clay, otherwise by status.
BadgeTone _locationTone(bool unstaffed, LocationStatus status) {
  if (unstaffed) return BadgeTone.clay;
  return switch (status) {
    LocationStatus.active => BadgeTone.forest,
    LocationStatus.attention => BadgeTone.gold,
    LocationStatus.inactive => BadgeTone.slate,
  };
}
