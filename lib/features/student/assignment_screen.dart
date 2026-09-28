import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
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
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Assignment',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.slate,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        student.name,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            WarmCard(
              child: Row(
                children: [
                  const WarmIconWell(
                    icon: Icons.badge_outlined,
                    gradient: AppColors.heroForest,
                    foreground: AppColors.onHeroWarm,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('Earn & Learn ID'),
                        const SizedBox(height: 2),
                        Text(
                          student.rollNumber,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontFamily: AppTextStyles.monoFamily,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          student.departmentOrNA,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.slateWarm),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (assignment == null) ...[
              const SizedBox(height: AppSpacing.lg),
              const EmptyState(
                icon: Icons.assignment_outlined,
                title: 'No active assignment',
                message: 'You are not yet placed at a work location. Contact the Student Development Office.',
              ),
            ] else ...[
              const SectionEyebrow(eyebrow: 'Placement', title: 'Duty Assignment'),
              WarmCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const WarmIconWell(
                          icon: Icons.location_on_outlined,
                          gradient: AppColors.heroForest,
                          foreground: AppColors.onHeroWarm,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                assignment.locationName.isNotEmpty
                                    ? assignment.locationName
                                    : 'Not assigned',
                                style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Amrutvahini College of Engineering',
                                style: AppTextStyles.labelSmall.copyWith(color: AppColors.slateWarm),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        PremiumBadge(
                          label: assignment.status.label,
                          tone: _assignmentTone(assignment.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const HairDivider(),
                    const SizedBox(height: 14),
                    const Eyebrow('Duties allotted'),
                    const SizedBox(height: 6),
                    Text(
                      assignment.workDescription.isNotEmpty
                          ? assignment.workDescription
                          : 'Not specified',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkWarm,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SectionEyebrow(eyebrow: 'Schedule', title: 'Shift Timings & Duration'),
              WarmCard(
                child: Column(
                  children: [
                    InfoLine(label: 'Authoritative shift', value: assignment.shiftLabel),
                    const HairDivider(),
                    InfoLine(
                      label: 'Daily expected duration',
                      value: '${assignment.plannedHoursPerDay.toStringAsFixed(1)} hours / day',
                    ),
                    const HairDivider(),
                    InfoLine(
                      label: 'Monthly ceiling policy',
                      value: '${assignment.maxMonthlyHours} hours / month',
                    ),
                  ],
                ),
              ),
              const SectionEyebrow(eyebrow: 'Supervision', title: 'Section In-Charge'),
              WarmCard(
                child: Row(
                  children: [
                    InitialsBubble(
                      initials: supervisor != null ? supervisor.initials : '—',
                      gradient: AppColors.goldSoftGrad,
                      foreground: const Color(0xFF4A3915),
                      size: 48,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supervisor?.name ?? 'Unassigned',
                            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            supervisor?.departmentOrNA ?? 'Not specified',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.slateWarm),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Contact: ${supervisor?.contactOrNA ?? 'Not available'}',
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.inkWarm),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (supervisor != null)
                      PremiumBadge(
                        label: supervisor.status.label,
                        tone: _supervisorTone(supervisor.status),
                      )
                    else
                      const PremiumBadge(label: 'Unassigned', tone: BadgeTone.slate),
                  ],
                ),
              ),
              const SectionEyebrow(eyebrow: 'Zone context', title: 'Campus Work Zone'),
              WarmCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const WarmIconWell(
                      icon: Icons.radar,
                      gradient: AppColors.heroForest,
                      foreground: AppColors.onHeroWarm,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zone geofence: 50m radius (symbolic)',
                            style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Attendance verification evaluates your physical presence within the designated work zone during active shift hours.',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.slateWarm, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),              const SizedBox(height: AppSpacing.md),
              WarmCard(
                ivory: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const WarmIconWell(
                          icon: Icons.shield_outlined,
                          background: AppColors.goldSoftDeep,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Student Work-Study Code of Conduct',
                            style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '1. Report promptly at your assigned work location.\n'
                      '2. Perform allotted duties with integrity and discipline.\n'
                      '3. Verify check-in and check-out through your mobile app.\n'
                      '4. Monthly work hours must not exceed the ${assignment.maxMonthlyHours}-hour limit.',
                      style: AppTextStyles.bodySmall.copyWith(height: 1.6, color: AppColors.inkSoftWarm),
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
}

BadgeTone _assignmentTone(AssignmentStatus s) => switch (s) {
      AssignmentStatus.active => BadgeTone.forest,
      AssignmentStatus.future => BadgeTone.info,
      AssignmentStatus.temporary => BadgeTone.gold,
      AssignmentStatus.inactive => BadgeTone.slate,
      AssignmentStatus.completed => BadgeTone.forest,
    };

BadgeTone _supervisorTone(SupervisorStatus s) => switch (s) {
      SupervisorStatus.onDuty => BadgeTone.forest,
      SupervisorStatus.offDuty => BadgeTone.slate,
      SupervisorStatus.unavailable => BadgeTone.clay,
    };

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

