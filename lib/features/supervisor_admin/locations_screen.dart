import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/status_style.dart';
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContextHeader(
              greeting: 'Locations',
              trailing: AdminIdentityAvatar(),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              eyebrow: 'ZONES',
              title: 'Work locations',
              subtitle: '${filtered.length} of ${data.locations.length} shown',
            ),
            const SizedBox(height: AppSpacing.md),
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
            else
              for (var i = 0; i < filtered.length; i++) ...[
                _LocationRow(
                  location: filtered[i],
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

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.location, required this.studentCount});

  final Location location;
  final int studentCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: () => context.go('/admin/locations/${location.id}'),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconWell(icon: Icons.location_on_outlined),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      location.name,
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  StatusBadge.status(style: location.status.style),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                location.description ?? 'Campus work area',
                style: AppTextStyles.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$studentCount students stationed',
                style: AppTextStyles.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}