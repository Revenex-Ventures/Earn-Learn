import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';
import '../../data/data.dart';
import '../../shared/components/components.dart';
import 'roster_actions.dart';

/// Full student dossier payload for the admin detail screen. Attendance is
/// strictly scoped to this student: golden STU-001 rows are never leaked.
class AdminStudentDetailData {
  const AdminStudentDetailData({
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

final _adminStudentDetailProvider = FutureProvider.autoDispose
    .family<AdminStudentDetailData?, String>((ref, studentId) async {
  final students = ref.watch(studentRepositoryProvider);
  final assignments = ref.watch(assignmentRepositoryProvider);
  final attendanceRepo = ref.watch(attendanceRepositoryProvider);
  final supervisors = ref.watch(supervisorRepositoryProvider);

  final student = await students.byId(studentId);
  if (student == null) return null;

  final assignment = await assignments.forStudent(studentId);
  final now = DateTime.now();
  final month = DateTime(now.year, now.month);
  final raw = await attendanceRepo.recordsForMonth(
    studentId: studentId,
    month: month,
  );
  final records = raw
      .where((r) => r.studentId == studentId)
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  final Supervisor? supervisor = assignment == null
      ? null
      : await supervisors.byId(assignment.supervisorId);

  return AdminStudentDetailData(
    student: student,
    assignment: assignment,
    supervisor: supervisor,
    records: records,
    month: month,
  );
});

class AdminStudentDetailScreen extends ConsumerWidget {
  const AdminStudentDetailScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(_adminStudentDetailProvider(studentId));

    return snapshot.when(
      loading: () => const LoadingState(label: 'Loading student…'),
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      data: (data) => data == null
          ? const SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: EmptyState(
                icon: Icons.person_off_outlined,
                title: 'Student not found',
                message:
                    'This student is not present in the institutional roster.',
              ),
            )
          : _AdminStudentDetailView(
            data: data,
            resolveEvidence: buildDayEvidenceResolver(
              ref.watch(attendanceGatewayProvider),
            ),
            onEditShift: data.assignment == null
                ? null
                : () => showEditShiftDialog(
                      context,
                      ref,
                      studentId: data.student.id,
                      assignment: data.assignment!,
                    ),
            onRemove: () => confirmRemoveStudent(
              context,
              ref,
              student: data.student,
            ),
          ),
    );
  }
}

class _AdminStudentDetailView extends StatelessWidget {
  const _AdminStudentDetailView({
    required this.data,
    this.resolveEvidence,
    this.onEditShift,
    this.onRemove,
  });

  final AdminStudentDetailData data;
  final DayEvidenceResolver? resolveEvidence;
  final VoidCallback? onEditShift;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final student = data.student;
    final supervisor = data.supervisor;
    final (tone, _) = _accountTone(student.status);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsBubble(
                  initials: student.initials,
                  gradient: AppColors.heroForest,
                  size: 44,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Student dossier'),
                      const SizedBox(height: 2),
                      Text(
                        student.name,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          color: AppColors.inkWarm,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                PremiumBadge(label: student.status.label, tone: tone),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (onEditShift != null || onRemove != null) ...[
              Row(
                children: [
                  if (onEditShift != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEditShift,
                        icon: const Icon(Icons.schedule, size: 18),
                        label: const Text('Adjust shift'),
                      ),
                    ),
                  if (onEditShift != null && onRemove != null)
                    const SizedBox(width: 10),
                  if (onRemove != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onRemove,
                        icon: const Icon(Icons.person_remove_alt_1, size: 18),
                        label: const Text('Remove'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            StudentDossierView(
              data: StudentDossierData(
                student: student,
                assignment: data.assignment,
                records: data.records,
                month: data.month,
                maxMonthlyHours: data.assignment?.maxMonthlyHours ?? 40,
                resolveEvidence: resolveEvidence,
                headerTrailing: supervisor == null
                    ? null
                    : StatusBadge.status(style: supervisor.status.style),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Maps an [AccountStatus] to a warm badge tone and left-accent colour.
(BadgeTone, Color) _accountTone(AccountStatus status) => switch (status) {
      AccountStatus.active => (BadgeTone.forest, AppColors.forestSoftBright),
      AccountStatus.pending => (BadgeTone.gold, AppColors.goldSoftAccent),
      AccountStatus.inactive => (BadgeTone.slate, AppColors.slateWarm),
    };
