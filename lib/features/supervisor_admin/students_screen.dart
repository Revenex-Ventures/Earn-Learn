import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';
import '../../data/data.dart';
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContextHeader(
              greeting: 'Students',
              trailing: InitialsAvatar(name: 'SDO In-Charge'),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              eyebrow: 'ROSTER',
              title: 'Registered students',
              subtitle: '${filtered.length} of ${data.students.length} shown',
            ),
            const SizedBox(height: AppSpacing.md),
            SearchFilterBar(
              hintText: 'Search by name or roll number',
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
                    'Try a different name, roll number or department filter.',
              )
            else
              for (var i = 0; i < filtered.length; i++) ...[
                _StudentRow(student: filtered[i]),
                if (i != filtered.length - 1)
                  const SizedBox(height: AppSpacing.sm),
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
    return ListRow(
      leading: const IconWell(icon: Icons.person_outline),
      title: student.name,
      subtitle:
          '${student.rollNumber} • ${student.departmentOrNA} • ${student.classOrNA}',
      status: StatusBadge.status(style: student.status.style),
      onTap: () => context.go('/admin/students/${student.id}'),
    );
  }
}