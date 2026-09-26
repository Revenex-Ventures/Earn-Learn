import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';
import '../../data/data.dart';
import '../../shared/components/components.dart';

class _StudentDetailData {
  const _StudentDetailData({
    required this.student,
    this.assignment,
    this.supervisor,
    required this.records,
    required this.month,
  });

  final Student student;
  final Assignment? assignment;
  final Supervisor? supervisor;
  final List<AttendanceRecord> records;
  final DateTime month;
}

final _studentDetailProvider =
    FutureProvider.autoDispose.family<_StudentDetailData, String>(
  (ref, studentId) async {
    final students = ref.watch(studentRepositoryProvider);
    final assignments = ref.watch(assignmentRepositoryProvider);
    final attendanceRepo = ref.watch(attendanceRepositoryProvider);
    final supervisors = ref.watch(supervisorRepositoryProvider);

    final student = await students.byId(studentId);
    if (student == null) {
      throw StateError('Student $studentId not found.');
    }

    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    final assignment = await assignments.forStudent(studentId);
    final records = (await attendanceRepo.recordsForMonth(
      studentId: studentId,
      month: month,
    ))
        .where((r) => r.studentId == studentId)
        .toList();

    final supervisor = assignment == null
        ? null
        : await supervisors.byId(assignment.supervisorId);

    return _StudentDetailData(
      student: student,
      assignment: assignment,
      supervisor: supervisor,
      records: records,
      month: month,
    );
  },
);

/// Full student dossier for the supervisor: identity, current duty, monthly
/// verified hours and the attendance register.
class SupervisorStudentDetailScreen extends ConsumerWidget {
  const SupervisorStudentDetailScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(_studentDetailProvider(studentId));

    return snapshot.when(
      loading: () => const _CenteredNote(
        icon: Icons.hourglass_empty,
        text: 'Loading student dossier…',
      ),
      error: (error, _) => _CenteredNote(
        icon: Icons.error_outline,
        text: error.toString(),
      ),
      data: (data) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ResponsivePage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ContextHeader(
                greeting: data.student.name,
                dateLine: 'Student dossier',
                trailing: InitialsAvatar(name: data.student.name),
              ),
              const SizedBox(height: AppSpacing.lg),
              StudentDossierView(
                data: StudentDossierData(
                  student: data.student,
                  assignment: data.assignment,
                  records: data.records,
                  month: data.month,
                  maxMonthlyHours: data.assignment?.maxMonthlyHours ?? 40,
                  headerTrailing: data.assignment == null
                      ? null
                      : StatusBadge.status(
                          style: data.assignment!.status.style,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
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