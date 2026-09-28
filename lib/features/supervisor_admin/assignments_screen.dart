import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/models/models.dart';
import '../../data/data.dart';
import 'admin_identity_avatar.dart';
import '../../shared/components/components.dart';

/// Shift payload with resolved student and supervisor display names.
class AdminAssignmentsData {
  const AdminAssignmentsData({
    required this.assignments,
    required this.studentsById,
    required this.supervisorsById,
  });

  final List<Assignment> assignments;
  final Map<String, Student> studentsById;
  final Map<String, Supervisor> supervisorsById;
}

final _adminAssignmentsProvider =
    FutureProvider.autoDispose<AdminAssignmentsData>((ref) async {
  final assignments = ref.watch(assignmentRepositoryProvider);
  final students = ref.watch(studentRepositoryProvider);
  final supervisors = ref.watch(supervisorRepositoryProvider);

  final allAsn = await assignments.all();
  final allStudents = await students.all();
  final allSup = await supervisors.all();

  return AdminAssignmentsData(
    assignments: allAsn,
    studentsById: {for (final s in allStudents) s.id: s},
    supervisorsById: {for (final s in allSup) s.id: s},
  );
});

class AdminAssignmentsScreen extends ConsumerStatefulWidget {
  const AdminAssignmentsScreen({super.key});

  @override
  ConsumerState<AdminAssignmentsScreen> createState() =>
      _AdminAssignmentsScreenState();
}

class _AdminAssignmentsScreenState
    extends ConsumerState<AdminAssignmentsScreen> {
  String _query = '';
  AssignmentStatus? _status;

  List<Assignment> _filter(AdminAssignmentsData data) {
    final q = _query.trim().toLowerCase();
    return data.assignments.where((a) {
      if (_status != null && a.status != _status) return false;
      if (q.isEmpty) return true;
      final student = data.studentsById[a.studentId];
      if (student != null && student.name.toLowerCase().contains(q)) {
        return true;
      }
      return a.locationName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(_adminAssignmentsProvider);

    return snapshot.when(
      loading: () => const LoadingState(label: 'Loading assignments…'),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      data: (data) => _build(context, data),
    );
  }

  Widget _build(BuildContext context, AdminAssignmentsData data) {
    final filtered = _filter(data);
    final statuses = {
      for (final a in data.assignments) a.status,
    }.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final options = <SearchFilterOption>[
      const SearchFilterOption(label: 'All'),
      for (final s in statuses) SearchFilterOption(label: s.label, value: s),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _DirectoryHeader(
              icon: Icons.work_outline,
              eyebrow: 'Shifts',
              title: 'Assignments',
            ),
            SectionEyebrow(
              eyebrow: 'All assignments',
              title: 'Duty allotments',
              trailing: PremiumBadge(
                label: '${filtered.length} of ${data.assignments.length}',
                tone: BadgeTone.slate,
              ),
            ),
            SearchFilterBar(
              hintText: 'Search by student or location',
              initialQuery: _query,
              onQueryChanged: (value) => setState(() => _query = value),
              filters: options,
              selected: _status,
              onFilterSelected: (value) =>
                  setState(() => _status = value as AssignmentStatus?),
            ),
            const SizedBox(height: AppSpacing.md),
            if (filtered.isEmpty)
              const EmptyState(
                icon: Icons.assignment_outlined,
                title: 'No assignments found',
                message: 'Try a different student, location or status filter.',
              )
            else
              for (var i = 0; i < filtered.length; i++) ...[
                _AssignmentRow(
                  assignment: filtered[i],
                  student: data.studentsById[filtered[i].studentId],
                  supervisor: data.supervisorsById[filtered[i].supervisorId],
                ),
                if (i != filtered.length - 1) const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow({
    required this.assignment,
    required this.student,
    required this.supervisor,
  });

  final Assignment assignment;
  final Student? student;
  final Supervisor? supervisor;

  @override
  Widget build(BuildContext context) {
    final studentName = student?.name ?? assignment.studentId;
    final supervisorName = assignment.supervisorName.isNotEmpty
        ? assignment.supervisorName
        : (supervisor?.name ?? 'Unassigned');
    final locationName = assignment.locationName.isNotEmpty
        ? assignment.locationName
        : assignment.locationId;
    final (tone, accent) = _assignmentTone(assignment.status);

    return AccentRow(
      accent: accent,
      lead: InitialsBubble(
        initials: student?.initials ?? '—',
        gradient: AppColors.heroForest,
      ),
      title: studentName,
      subtitle: '$locationName • ${assignment.shiftLabel} • $supervisorName',
      trailing: PremiumBadge(label: assignment.status.label, tone: tone),
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

/// Maps an [AssignmentStatus] to a warm badge tone and left-accent colour.
(BadgeTone, Color) _assignmentTone(AssignmentStatus status) => switch (status) {
      AssignmentStatus.active => (BadgeTone.forest, AppColors.forestSoftBright),
      AssignmentStatus.completed =>
        (BadgeTone.forest, AppColors.forestSoftBright),
      AssignmentStatus.future => (BadgeTone.info, AppColors.infoSoft),
      AssignmentStatus.temporary => (BadgeTone.gold, AppColors.goldSoftAccent),
      AssignmentStatus.inactive => (BadgeTone.slate, AppColors.slateWarm),
    };
