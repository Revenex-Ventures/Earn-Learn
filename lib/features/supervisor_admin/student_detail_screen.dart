import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';
import '../../data/data.dart';
import '../../shared/components/components.dart';

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
          ),
    );
  }
}

class _AdminStudentDetailView extends StatelessWidget {
  const _AdminStudentDetailView({required this.data, this.resolveEvidence});

  final AdminStudentDetailData data;
  final DayEvidenceResolver? resolveEvidence;

  @override
  Widget build(BuildContext context) {
    final student = data.student;
    final supervisor = data.supervisor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContextHeader(
              greeting: student.name,
              trailing: InitialsAvatar(name: student.name),
            ),
            const SizedBox(height: AppSpacing.lg),
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