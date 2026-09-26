import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';
import '../../data/data.dart';
import '../../shared/components/components.dart';

/// View model for the assignment tab. The assignment may be absent for
/// students waiting to be placed — the UI renders an honest empty state.
class StudentAssignmentData {
  const StudentAssignmentData({
    required this.student,
    this.assignment,
    this.supervisor,
  });

  final Student student;
  final Assignment? assignment;
  final Supervisor? supervisor;
}

final _studentAssignmentProvider = FutureProvider.autoDispose<StudentAssignmentData>((ref) async {
  final account = ref.watch(accountRepositoryProvider);
  final students = ref.watch(studentRepositoryProvider);
  final assignments = ref.watch(assignmentRepositoryProvider);
  final supervisors = ref.watch(supervisorRepositoryProvider);

  final user = await account.currentUser();
  final link = await account.currentAccountLink();
  final entityId = link?.entityId;
  var student = entityId == null ? null : await students.byId(entityId);
  if (student == null && !AppFlavor.useFirebase) {
    final allStudents = await students.all();
    if (allStudents.isNotEmpty) {
      student = allStudents.first;
    }
  }
  if (user == null || student == null) {
    throw StateError('No student linked to the signed-in account.');
  }

  final assignment = await assignments.forStudent(student.id);
  Supervisor? supervisor;
  if (assignment != null && assignment.supervisorId.isNotEmpty) {
    supervisor = await supervisors.byId(assignment.supervisorId);
  }

  return StudentAssignmentData(
    student: student,
    assignment: assignment,
    supervisor: supervisor,
  );
});

class StudentAssignmentScreen extends ConsumerWidget {
  const StudentAssignmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(_studentAssignmentProvider);

    return snapshot.when(
      loading: () => const _CenteredNote(
        icon: Icons.hourglass_empty,
        text: 'Loading your assignment…',
      ),
      error: (error, _) => _CenteredNote(
        icon: Icons.error_outline,
        text: error.toString(),
      ),
      data: (data) => _StudentAssignmentView(data: data),
    );
  }
}

class _StudentAssignmentView extends StatelessWidget {
  const _StudentAssignmentView({required this.data});

  final StudentAssignmentData data;

  @override
  Widget build(BuildContext context) {
    final student = data.student;
    final assignment = data.assignment;
    final supervisor = data.supervisor;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContextHeader(
              greeting: 'My Assignment',
              dateLine: '${student.rollNumber} • ${student.departmentOrNA}',
              trailing: InitialsAvatar(name: student.name),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (assignment == null)
              const EmptyState(
                icon: Icons.assignment_outlined,
                title: 'No active assignment',
                message: 'You are not yet placed at a work location. Contact the Student Development Office.',
              )
            else ...[
              _assignmentHeader(assignment),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(
                eyebrow: 'SCHEDULE',
                title: 'Shift Timings & Duration',
              ),
              const SizedBox(height: AppSpacing.md),
              _Surface(
                child: Column(
                  children: [
                    _infoRow(
                      icon: Icons.schedule,
                      label: 'Authoritative Shift',
                      value: assignment.shiftLabel,
                    ),
                    const Divider(color: AppColors.divider, height: 20),
                    _infoRow(
                      icon: Icons.timer_outlined,
                      label: 'Daily Expected Duration',
                      value: '${assignment.plannedHoursPerDay.toStringAsFixed(1)} hours / day',
                    ),
                    const Divider(color: AppColors.divider, height: 20),
                    _infoRow(
                      icon: Icons.rule,
                      label: 'Monthly Ceiling Policy',
                      value: '${assignment.maxMonthlyHours} hours maximum / month',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(
                eyebrow: 'SUPERVISION',
                title: 'Section In-Charge',
              ),
              const SizedBox(height: AppSpacing.md),
              _Surface(
                child: Row(
                  children: [
                    InitialsAvatar(name: supervisor?.name ?? 'Unassigned', radius: 24),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(supervisor?.name ?? 'Unassigned', style: AppTextStyles.titleMedium),
                          const SizedBox(height: 2),
                          Text(
                            supervisor?.departmentOrNA ?? 'Not specified',
                            style: AppTextStyles.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Contact: ${supervisor?.contactOrNA ?? 'Not available'}',
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.ink),
                          ),
                        ],
                      ),
                    ),
                    if (supervisor != null) StatusBadge.status(style: supervisor.status.style),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(
                eyebrow: 'ZONE CONTEXT',
                title: 'Campus Work Zone',
              ),
              const SizedBox(height: AppSpacing.md),
              _Surface(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const IconWell(icon: Icons.radar, color: AppColors.ink),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Zone Geofence: 50m radius (Symbolic)', style: AppTextStyles.titleSmall),
                          const SizedBox(height: 4),
                          Text(
                            'Attendance verification evaluates your physical presence within the designated work zone during active shift hours.',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 18, color: AppColors.ink),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Student Work-Study Code of Conduct',
                            style: AppTextStyles.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '1. Report promptly at your assigned work location.\n'
                      '2. Perform allotted duties with integrity and discipline.\n'
                      '3. Verify check-in and check-out through your mobile app.\n'
                      '4. Monthly work hours must not exceed the ${assignment.maxMonthlyHours}-hour limit.',
                      style: AppTextStyles.bodySmall.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _assignmentHeader(Assignment assignment) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconWell(icon: Icons.location_on_outlined, color: AppColors.sage),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.locationName.isNotEmpty
                          ? assignment.locationName
                          : 'Assigned Location',
                      style: AppTextStyles.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    Text('Amrutvahini College of Engineering', style: AppTextStyles.labelSmall),
                  ],
                ),
              ),
              StatusBadge.status(style: assignment.status.style),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: AppSpacing.lg),
          Text('DUTIES ALLOTTED', style: AppTextStyles.labelSmall),
          const SizedBox(height: 4),
          Text(
            assignment.workDescription,
            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: AppColors.ink),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.labelSmall),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
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
            Text(text, style: AppTextStyles.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}