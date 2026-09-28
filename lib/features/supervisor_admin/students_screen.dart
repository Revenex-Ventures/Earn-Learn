import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/models/models.dart';
import '../../data/data.dart';
import 'admin_identity_avatar.dart';
import '../../shared/components/components.dart';

/// Roster payload for the admin students directory.
class AdminStudentsData {
  const AdminStudentsData({required this.students});

  final List<Student> students;
}

final _adminStudentsProvider = FutureProvider.autoDispose<AdminStudentsData>(
    (ref) async {
  final repo = ref.watch(studentRepositoryProvider);
  return AdminStudentsData(students: await repo.all());
});

class AdminStudentsScreen extends ConsumerStatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  ConsumerState<AdminStudentsScreen> createState() =>
      _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends ConsumerState<AdminStudentsScreen> {
  String _query = '';
  String? _department;

  List<Student> _filter(List<Student> all) {
    final q = _query.trim().toLowerCase();
    return all.where((s) {
      if (_department != null && s.departmentOrNA != _department) return false;
      if (q.isEmpty) return true;
      return s.name.toLowerCase().contains(q) ||
          s.rollNumber.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(_adminStudentsProvider);

    return snapshot.when(
      loading: () => const LoadingState(label: 'Loading students…'),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      data: (data) => _build(context, data),
    );
  }

  Widget _build(BuildContext context, AdminStudentsData data) {
    final filtered = _filter(data.students);
    final departments = {
      for (final s in data.students) s.departmentOrNA,
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
              icon: Icons.groups_outlined,
              eyebrow: 'Roster',
              title: 'Students',
            ),
            SectionEyebrow(
              eyebrow: 'Registered students',
              title: 'Institutional roster',
              trailing: PremiumBadge(
                label: '${filtered.length} of ${data.students.length}',
                tone: BadgeTone.slate,
              ),
            ),
            SearchFilterBar(
              hintText: 'Search by name or Earn & Learn ID',
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
                title: 'No students found',
                message:
                    'Try a different name, Earn & Learn ID or department filter.',
              )
            else
              for (var i = 0; i < filtered.length; i++) ...[
                _StudentRow(student: filtered[i]),
                if (i != filtered.length - 1) const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final (tone, accent) = _accountTone(student.status);
    return AccentRow(
      accent: accent,
      lead: InitialsBubble(
        initials: student.initials,
        gradient: AppColors.heroForest,
      ),
      title: student.name,
      subtitle:
          '${student.rollNumber} • ${student.departmentOrNA} • ${student.classOrNA}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PremiumBadge(label: student.status.label, tone: tone),
          const SizedBox(width: 8),
          const RowChevron(),
        ],
      ),
      onTap: () => context.go('/admin/students/${student.id}'),
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

/// Maps an [AccountStatus] to a warm badge tone and left-accent colour.
(BadgeTone, Color) _accountTone(AccountStatus status) => switch (status) {
      AccountStatus.active => (BadgeTone.forest, AppColors.forestSoftBright),
      AccountStatus.pending => (BadgeTone.gold, AppColors.goldSoftAccent),
      AccountStatus.inactive => (BadgeTone.slate, AppColors.slateWarm),
    };
