import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/models/models.dart';
import '../../data/data.dart';
import '../../shared/components/components.dart';
import '../supervisor_admin/roster_actions.dart';

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

/// Warm-premium (accent, badge) pair for a daily attendance state.
(Color, BadgeTone) _attendanceTone(AttendanceStatus status) => switch (status) {
      AttendanceStatus.present => (AppColors.forestSoft, BadgeTone.forest),
      AttendanceStatus.late => (AppColors.terraSpark, BadgeTone.terra),
      AttendanceStatus.absent => (AppColors.claySoftReject, BadgeTone.clay),
      AttendanceStatus.flagged => (AppColors.claySoftReject, BadgeTone.clay),
      AttendanceStatus.pending => (AppColors.goldSoftDeep, BadgeTone.gold),
      AttendanceStatus.leave => (AppColors.slateWarm, BadgeTone.slate),
      AttendanceStatus.scheduled => (AppColors.slateWarm, BadgeTone.slate),
    };

String _hours(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _dayLabel(DateTime d) => '${d.day} ${_monthAbbr[d.month - 1]}';

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
      data: (data) => _StudentDetailView(
        data: data,
        onEditShift: data.assignment == null
            ? null
            : () => showEditShiftDialog(
                  context,
                  ref,
                  studentId: data.student.id,
                  assignment: data.assignment!,
                ),
      ),
    );
  }
}

class _StudentDetailView extends StatelessWidget {
  const _StudentDetailView({required this.data, this.onEditShift});

  final _StudentDetailData data;
  final VoidCallback? onEditShift;

  @override
  Widget build(BuildContext context) {
    final student = data.student;
    final assignment = data.assignment;
    final records = data.records;

    final verified =
        records.fold<double>(0, (sum, r) => sum + r.verifiedHours);
    final daysWorked = records.where((r) => r.verifiedHours > 0).length;
    final pendingReview = records.where((r) => r.needsReview).length;
    final ceiling = assignment?.maxMonthlyHours;
    final ceilingCaption = ceiling != null && ceiling > 0
        ? '${_hours(verified)} of $ceiling-hour monthly ceiling'
        : 'Monthly ceiling: Not specified';

    final history = [...records]..sort((a, b) => b.date.compareTo(a.date));

    final (_, assignTone) = assignment == null
        ? (AppColors.slateWarm, BadgeTone.slate)
        : _assignmentTone(assignment.status);

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
                      const Eyebrow('Student dossier'),
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
                        student.rollNumber,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.slateWarm,
                          fontFamily: AppTextStyles.monoFamily,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                PremiumBadge(
                  label: assignment?.status.label ?? 'Not assigned',
                  tone: assignTone,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Verified-hours summary hero.
            EspressoHero(
              value: _hours(verified),
              unit: 'verified\nhours',
              caption: ceilingCaption,
              leftPill:
                  const HeroPill(label: 'Monthly tally', icon: Icons.schedule),
              stats: [
                HeroStat(label: 'Days worked', value: '$daysWorked'),
                HeroStat(label: 'Verified', value: '${_hours(verified)} h'),
                HeroStat(
                  label: 'Ceiling',
                  value: ceiling != null && ceiling > 0 ? '$ceiling h' : '—',
                ),
              ],
            ),

            // Assignment details.
            const SectionEyebrow(eyebrow: 'Assignment', title: 'Current duty'),
            WarmCard(
              child: Column(
                children: [
                  InfoLine(
                    label: 'Location',
                    value: assignment == null ||
                            assignment.locationName.trim().isEmpty
                        ? 'Not assigned'
                        : assignment.locationName,
                  ),
                  const HairDivider(),
                  InfoLine(
                    label: 'Supervisor',
                    value: data.supervisor?.name ??
                        (assignment != null &&
                                assignment.supervisorName.trim().isNotEmpty
                            ? assignment.supervisorName
                            : 'Not assigned'),
                  ),
                  const HairDivider(),
                  InfoLine(
                    label: 'Shift',
                    value: assignment == null
                        ? 'Not specified'
                        : assignment.shiftLabel,
                  ),
                  const HairDivider(),
                  InfoLine(
                    label: 'Work',
                    value: assignment == null ||
                            assignment.workDescription.trim().isEmpty
                        ? 'Not specified'
                        : assignment.workDescription,
                  ),
                  const HairDivider(),
                  InfoLine(label: 'Department', value: student.departmentOrNA),
                  const HairDivider(),
                  InfoLine(label: 'Class', value: student.classOrNA),
                ],
              ),
            ),
            if (onEditShift != null) ...[
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onEditShift,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: const Text('Adjust shift'),
                ),
              ),
            ],

            // Monthly metrics.
            const SectionEyebrow(eyebrow: 'This month', title: 'At a glance'),
            MetricTileGrid(
              items: [
                MetricTileData(
                  label: 'Days worked',
                  value: '$daysWorked',
                  desc: 'verified duty days',
                ),
                MetricTileData(
                  label: 'Verified',
                  value: _hours(verified),
                  desc: 'hours this month',
                  tone: BadgeTone.gold,
                ),
                MetricTileData(
                  label: 'Records',
                  value: '${records.length}',
                  desc: 'attendance entries',
                  tone: BadgeTone.slate,
                ),
                MetricTileData(
                  label: 'To review',
                  value: '$pendingReview',
                  desc: 'awaiting sign-off',
                  tone: pendingReview > 0 ? BadgeTone.clay : BadgeTone.forest,
                ),
              ],
            ),

            // Attendance register.
            const SectionEyebrow(
                eyebrow: 'Attendance register', title: 'This month'),
            if (history.isEmpty)
              const NoteBox(
                text: 'No attendance recorded for this month yet.',
                icon: Icons.event_note_outlined,
              )
            else
              for (var i = 0; i < history.length; i++) ...[
                _RecordRow(record: history[i]),
                if (i != history.length - 1) const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

IconData _attendanceIcon(AttendanceStatus status) => switch (status) {
      AttendanceStatus.present => Icons.check_circle_outline,
      AttendanceStatus.late => Icons.access_time,
      AttendanceStatus.absent => Icons.cancel_outlined,
      AttendanceStatus.flagged => Icons.flag_outlined,
      AttendanceStatus.pending => Icons.hourglass_empty,
      AttendanceStatus.leave => Icons.event_busy_outlined,
      AttendanceStatus.scheduled => Icons.more_horiz,
    };

/// Warm-premium badge tone for a supervisor review outcome.
BadgeTone _reviewTone(ApprovalStatus status) => switch (status) {
      ApprovalStatus.approved => BadgeTone.forest,
      ApprovalStatus.pending => BadgeTone.gold,
      ApprovalStatus.rejected => BadgeTone.clay,
      ApprovalStatus.flagged => BadgeTone.clay,
    };

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final (accent, _) = _attendanceTone(record.status);
    final hoursStr = record.verifiedHours > 0
        ? '${_hours(record.verifiedHours)} h verified'
        : (record.hours > 0 ? '${_hours(record.hours)} h recorded' : 'No hours');
    return AccentRow(
      accent: accent,
      lead: WarmIconWell(
        icon: _attendanceIcon(record.status),
        background: accent,
        foreground: AppColors.onHeroWarm,
      ),
      title: _dayLabel(record.date),
      subtitle: '${record.status.label} · $hoursStr',
      trailing: PremiumBadge(label: record.review.label, tone: _reviewTone(record.review)),
    );
  }
}

/// Warm-premium (accent, badge) pair for an assignment lifecycle state.
(Color, BadgeTone) _assignmentTone(AssignmentStatus status) => switch (status) {
      AssignmentStatus.active => (AppColors.forestSoft, BadgeTone.forest),
      AssignmentStatus.completed => (AppColors.forestSoft, BadgeTone.forest),
      AssignmentStatus.future => (AppColors.goldSoftDeep, BadgeTone.gold),
      AssignmentStatus.temporary => (AppColors.terraSpark, BadgeTone.terra),
      AssignmentStatus.inactive => (AppColors.slateWarm, BadgeTone.slate),
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
            Text(text, style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}
