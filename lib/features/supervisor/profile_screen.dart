import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';
import '../../core/routing/route_paths.dart';
import '../../data/data.dart';
import '../../shared/components/components.dart';
import '../auth/auth_session.dart';

class _ProfileData {
  const _ProfileData({
    required this.user,
    required this.supervisor,
    required this.locations,
  });

  final UserProfile user;
  final Supervisor supervisor;
  final List<Location> locations;
}

final _supervisorProfileProvider =
    FutureProvider.autoDispose<_ProfileData>((ref) async {
  final account = ref.watch(accountRepositoryProvider);
  final supervisors = ref.watch(supervisorRepositoryProvider);
  final locations = ref.watch(locationRepositoryProvider);

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
  final all = await locations.all();
  final mine = all
      .where((l) => resolvedSupervisor.assignedLocationIds.contains(l.id))
      .toList();

  return _ProfileData(user: user, supervisor: resolvedSupervisor, locations: mine);
});

/// Supervisor profile: identity, contact and the work zones under them.
class SupervisorProfileScreen extends ConsumerWidget {
  const SupervisorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(_supervisorProfileProvider);

    return snapshot.when(
      loading: () => const _CenteredNote(
        icon: Icons.hourglass_empty,
        text: 'Loading your profile…',
      ),
      error: (error, _) => _CenteredNote(
        icon: Icons.error_outline,
        text: error.toString(),
      ),
      data: (data) => _SupervisorProfileView(data: data),
    );
  }
}

class _SupervisorProfileView extends StatelessWidget {
  const _SupervisorProfileView({required this.data});

  final _ProfileData data;

  @override
  Widget build(BuildContext context) {
    final supervisor = data.supervisor;
    final email = data.user.email ?? supervisor.email;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContextHeader(
              greeting: supervisor.name,
              dateLine: 'Supervisor profile',
              trailing: InitialsAvatar(name: supervisor.name),
            ),
            const SizedBox(height: AppSpacing.lg),
            IdentityRow(
              label: 'Supervisor ID',
              value: supervisor.id,
              accent: AppColors.gold,
              icon: Icons.verified_user_outlined,
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      InitialsAvatar(name: supervisor.name, size: 56),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              supervisor.name,
                              style: AppTextStyles.titleLarge,
                            ),
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
                  ProfileInfoRow(
                    label: 'Email',
                    value: email ?? 'Not available',
                  ),
                  ProfileInfoRow(
                    label: 'Contact',
                    value: supervisor.contactOrNA,
                  ),
                  ProfileInfoRow(
                    label: 'Department',
                    value: supervisor.departmentOrNA,
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SectionHeader(
              eyebrow: 'COVERAGE',
              title: 'My locations',
            ),
            const SizedBox(height: AppSpacing.md),
            if (data.locations.isEmpty)
              const EmptyState(
                icon: Icons.location_off_outlined,
                title: 'No work zones',
                message: 'No locations are assigned to this account.',
              )
            else
              for (var i = 0; i < data.locations.length; i++) ...[
                _LocationRow(location: data.locations[i]),
                if (i != data.locations.length - 1)
                  const SizedBox(height: AppSpacing.sm),
              ],
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {
                  AuthSession.signOut();
                  context.go(RoutePaths.auth);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.divider),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.location});

  final Location location;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: location.name,
      subtitle: location.description ?? location.status.label,
      leading: const IconWell(
        icon: Icons.location_on_outlined,
        color: AppColors.sage,
      ),
      showChevron: false,
      status: StatusBadge.status(style: location.status.style),
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