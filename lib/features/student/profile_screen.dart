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

/// View model for the student profile tab. Assignment and supervisor may be
/// absent for students awaiting placement — the UI renders honest empty states.
class StudentProfileData {
  const StudentProfileData({
    required this.student,
    this.assignment,
    this.supervisor,
  });

  final Student student;
  final Assignment? assignment;
  final Supervisor? supervisor;
}

final _studentProfileProvider =
    FutureProvider.autoDispose<StudentProfileData>((ref) async {
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

  return StudentProfileData(
    student: student,
    assignment: assignment,
    supervisor: supervisor,
  );
});

/// Warm-premium (accent, badge) pair for an account lifecycle state.
(Color, BadgeTone) _accountTone(AccountStatus status) => switch (status) {
      AccountStatus.active => (AppColors.forestSoft, BadgeTone.forest),
      AccountStatus.inactive => (AppColors.slateWarm, BadgeTone.slate),
      AccountStatus.pending => (AppColors.goldSoftDeep, BadgeTone.gold),
    };

/// Warm-premium badge tone for an assignment lifecycle state.
BadgeTone _assignmentTone(AssignmentStatus status) => switch (status) {
      AssignmentStatus.active => BadgeTone.forest,
      AssignmentStatus.future => BadgeTone.info,
      AssignmentStatus.temporary => BadgeTone.gold,
      AssignmentStatus.inactive => BadgeTone.slate,
      AssignmentStatus.completed => BadgeTone.slate,
    };
/// Student profile: identity, contact and the current work placement.
class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(_studentProfileProvider);

    return snapshot.when(
      loading: () => const _CenteredNote(
        icon: Icons.hourglass_empty,
        text: 'Loading your profile…',
      ),
      error: (error, _) => _CenteredNote(
        icon: Icons.error_outline,
        text: error.toString(),
      ),
      data: (data) => _StudentProfileView(data: data),
    );
  }
}

class _StudentProfileView extends StatelessWidget {
  const _StudentProfileView({required this.data});

  final StudentProfileData data;

  @override
  Widget build(BuildContext context) {
    final student = data.student;
    final assignment = data.assignment;
    final supervisor = data.supervisor;
    final email = student.email;
    final (_, statusTone) = _accountTone(student.status);

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
                  initials: student.initials,
                  gradient: AppColors.heroForest,
                  size: 52,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Student profile'),
                      const SizedBox(height: 2),
                      Text(
                        student.name,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        student.departmentOrNA,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.slateWarm),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                PremiumBadge(label: student.status.label, tone: statusTone),
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
                    label: 'Earn & Learn ID',
                    value: student.rollNumber,
                    valueColor: AppColors.goldSoftDeep,
                  ),
                  const HairDivider(),
                  InfoLine(label: 'Email', value: email ?? 'Not available'),
                  const HairDivider(),
                  InfoLine(label: 'Contact', value: student.contactOrNA),
                  const HairDivider(),
                  InfoLine(label: 'Department', value: student.departmentOrNA),
                  const HairDivider(),
                  InfoLine(label: 'Class', value: student.classOrNA),
                ],
              ),
            ),

            const SectionEyebrow(
                eyebrow: 'Placement', title: 'Current assignment'),
            if (assignment == null)
              const EmptyState(
                icon: Icons.work_off_outlined,
                title: 'Not assigned',
                message:
                    'No active work placement is linked to this account yet.',
              )
            else
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
                              const Eyebrow('Work zone'),
                              const SizedBox(height: 2),
                              Text(
                                assignment.locationName.isNotEmpty
                                    ? assignment.locationName
                                    : 'Not specified',
                                style: AppTextStyles.titleSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PremiumBadge(
                          label: assignment.status.label,
                          tone: _assignmentTone(assignment.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const HairDivider(),
                    InfoLine(
                      label: 'Supervisor',
                      value: supervisor?.name ??
                          (assignment.supervisorName.isNotEmpty
                              ? assignment.supervisorName
                              : 'Unassigned'),
                    ),
                    const HairDivider(),
                    InfoLine(label: 'Shift', value: assignment.shiftLabel),
                    const HairDivider(),
                    InfoLine(
                      label: 'Work',
                      value: assignment.workDescription.isNotEmpty
                          ? assignment.workDescription
                          : 'Not specified',
                    ),
                    const HairDivider(),
                    InfoLine(
                      label: 'Monthly ceiling',
                      value: '${assignment.maxMonthlyHours} h',
                    ),
                  ],
                ),
              ),

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
