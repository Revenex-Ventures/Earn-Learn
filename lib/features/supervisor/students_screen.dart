import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/models/models.dart';
import '../../data/data.dart';
import '../../shared/components/components.dart';

class _RosterEntry {
  const _RosterEntry({required this.student, required this.assignment});

  final Student student;
  final Assignment assignment;
}

final _rosterProvider = FutureProvider.autoDispose<List<_RosterEntry>>(
  (ref) async {
    final account = ref.watch(accountRepositoryProvider);
    final studentsRepo = ref.watch(studentRepositoryProvider);
    final supervisors = ref.watch(supervisorRepositoryProvider);
    final assignmentsRepo = ref.watch(assignmentRepositoryProvider);

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
    final allAssignments = await assignmentsRepo.all();
    final allStudents = await studentsRepo.all();
    final mine = allAssignments
        .where((a) => a.supervisorId == resolvedSupervisor.id)
        .toList();

    final roster = <_RosterEntry>[];
    for (final a in mine) {
      for (final s in allStudents) {
        if (s.id == a.studentId) {
          roster.add(_RosterEntry(student: s, assignment: a));
          break;
        }
      }
    }
    roster.sort((a, b) => a.student.name.compareTo(b.student.name));
    return roster;
  },
);

/// Warm-premium (accent, badge) pair for an assignment lifecycle state.
(Color, BadgeTone) _assignmentTone(AssignmentStatus status) => switch (status) {
      AssignmentStatus.active => (AppColors.forestSoft, BadgeTone.forest),
      AssignmentStatus.completed => (AppColors.forestSoft, BadgeTone.forest),
      AssignmentStatus.future => (AppColors.goldSoftDeep, BadgeTone.gold),
      AssignmentStatus.temporary => (AppColors.terraSpark, BadgeTone.terra),
      AssignmentStatus.inactive => (AppColors.slateWarm, BadgeTone.slate),
    };

/// Roster of the students assigned to the signed-in supervisor.
class SupervisorStudentsScreen extends ConsumerStatefulWidget {
  const SupervisorStudentsScreen({super.key});

  @override
  ConsumerState<SupervisorStudentsScreen> createState() =>
      _SupervisorStudentsScreenState();
}

class _SupervisorStudentsScreenState
    extends ConsumerState<SupervisorStudentsScreen> {
  String _query = '';
  String _selectedFilter = 'All';

  List<_RosterEntry> _apply(List<_RosterEntry> roster) {
    var list = roster;
    if (_selectedFilter == 'Active') {
      list = list.where((e) => e.assignment.status == AssignmentStatus.active).toList();
    } else if (_selectedFilter == 'Future') {
      list = list.where((e) => e.assignment.status == AssignmentStatus.future).toList();
    } else if (_selectedFilter == 'Completed') {
      list = list.where((e) => e.assignment.status == AssignmentStatus.completed).toList();
    }

    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return [
      for (final e in list)
        if (e.student.name.toLowerCase().contains(q) ||
            e.student.rollNumber.toLowerCase().contains(q) ||
            e.student.departmentOrNA.toLowerCase().contains(q))
          e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rosterAsync = ref.watch(_rosterProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: title + Bhaurao portrait (preserved).
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Students',
                        style: AppTextStyles.headlineSmall
                            .copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 1),
                    Text('Assigned duty roster',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.slateWarm)),
                  ],
                ),
                const BhauraoPortrait(size: 40),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Search bar (preserved).
            SearchFilterBar(
              hintText: 'Search by name or ID...',
              initialQuery: _query,
              onQueryChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: AppSpacing.md),

            // Filter chips (preserved).
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final filter in ['All', 'Active', 'Pending', 'Completed']) ...[
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: _selectedFilter == filter,
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedFilter = filter);
                        },
                        selectedColor: AppColors.avcoeGreen,
                        labelStyle: AppTextStyles.labelSmall.copyWith(
                          color: _selectedFilter == filter ? AppColors.surface : AppColors.ink,
                          fontWeight: _selectedFilter == filter ? FontWeight.w700 : FontWeight.w500,
                        ),
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          side: BorderSide(
                            color: _selectedFilter == filter ? AppColors.avcoeGreen : AppColors.divider,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            rosterAsync.when(
              loading: () => const _CenteredNote(
                icon: Icons.people_outline,
                text: 'Loading your team…',
              ),
              error: (error, _) => _CenteredNote(
                icon: Icons.error_outline,
                text: error.toString(),
              ),
              data: (roster) {
                final filtered = _apply(roster);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionEyebrow(
                      eyebrow: 'Assigned roster',
                      title: 'Assigned students',
                      trailing: Text(
                        '${filtered.length} of ${roster.length}',
                        style: AppTextStyles.labelMedium
                            .copyWith(color: AppColors.slateWarm),
                      ),
                    ),
                    if (filtered.isEmpty)
                      const EmptyState(
                        icon: Icons.search_off,
                        title: 'No matching students',
                        message: 'Try adjusting your search criteria.',
                      )
                    else
                      for (var i = 0; i < filtered.length; i++) ...[
                        _RosterRow(entry: filtered[i]),
                        if (i != filtered.length - 1) const SizedBox(height: 10),
                      ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.entry});

  final _RosterEntry entry;

  @override
  Widget build(BuildContext context) {
    final assignment = entry.assignment;
    final (accent, tone) = _assignmentTone(assignment.status);
    return AccentRow(
      accent: accent,
      lead: InitialsBubble(
        initials: entry.student.initials,
        gradient: AppColors.heroForest,
      ),
      title: entry.student.name,
      subtitle: '${entry.student.rollNumber} · ${entry.student.departmentOrNA}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PremiumBadge(label: assignment.status.label, tone: tone),
          const SizedBox(width: 8),
          const RowChevron(),
        ],
      ),
      onTap: () => context.go('/supervisor/students/${entry.student.id}'),
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
