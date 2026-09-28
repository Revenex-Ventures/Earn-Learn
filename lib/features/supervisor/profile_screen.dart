import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
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

/// Warm-premium (accent, badge) pair for a supervisor duty state.
(Color, BadgeTone) _supervisorTone(SupervisorStatus status) => switch (status) {
      SupervisorStatus.onDuty => (AppColors.forestSoft, BadgeTone.forest),
      SupervisorStatus.offDuty => (AppColors.slateWarm, BadgeTone.slate),
      SupervisorStatus.unavailable => (AppColors.claySoftReject, BadgeTone.clay),
    };

/// Warm-premium (accent, badge) pair for a work-zone state.
(Color, BadgeTone) _locationTone(LocationStatus status) => switch (status) {
      LocationStatus.active => (AppColors.forestSoft, BadgeTone.forest),
      LocationStatus.attention => (AppColors.goldSoftDeep, BadgeTone.gold),
      LocationStatus.inactive => (AppColors.slateWarm, BadgeTone.slate),
    };

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
    final (_, statusTone) = _supervisorTone(supervisor.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Identity header.
            Row(
              children: [
                InitialsBubble(
                  initials: supervisor.initials,
                  gradient: AppColors.heroForest,
                  size: 52,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Supervisor profile'),
                      const SizedBox(height: 2),
                      Text(
                        supervisor.name,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        supervisor.departmentOrNA,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.slateWarm),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                PremiumBadge(label: supervisor.status.label, tone: statusTone),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Identity + contact details.
            WarmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('Identity'),
                  const SizedBox(height: 4),
                  InfoLine(
                    label: 'Supervisor ID',
                    value: supervisor.id,
                    valueColor: AppColors.goldSoftDeep,
                  ),
                  const HairDivider(),
                  InfoLine(label: 'Email', value: email ?? 'Not available'),
                  const HairDivider(),
                  InfoLine(label: 'Contact', value: supervisor.contactOrNA),
                  const HairDivider(),
                  InfoLine(label: 'Department', value: supervisor.departmentOrNA),
                ],
              ),
            ),

            const SectionEyebrow(eyebrow: 'Coverage', title: 'My locations'),
            if (data.locations.isEmpty)
              const EmptyState(
                icon: Icons.location_off_outlined,
                title: 'No work zones',
                message: 'No locations are assigned to this account.',
              )
            else
              for (var i = 0; i < data.locations.length; i++) ...[
                _LocationRow(location: data.locations[i]),
                if (i != data.locations.length - 1) const SizedBox(height: 10),
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
    final (accent, tone) = _locationTone(location.status);
    return AccentRow(
      accent: accent,
      lead: const WarmIconWell(
        icon: Icons.location_on_outlined,
        gradient: AppColors.heroForest,
        foreground: AppColors.onHeroWarm,
      ),
      title: location.name,
      subtitle: location.description ?? location.status.label,
      trailing: PremiumBadge(label: location.status.label, tone: tone),
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
