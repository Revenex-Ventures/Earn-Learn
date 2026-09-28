import 'dart:async';

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
import '../../domain/domain.dart';
import '../../shared/components/components.dart';
import 'attendance_flow_sheet.dart';
import 'check_in_controller.dart';

/// View model assembled from the account/domain repositories.
class StudentHomeData {
  const StudentHomeData({
    required this.studentId,
    required this.rollNumber,
    required this.name,
    required this.location,
    required this.supervisorName,
    required this.windows,
    required this.workDescription,
    required this.todayRecord,
    required this.approval,
    required this.isOffDay,
    required this.verifiedHours,
    required this.maxMonthlyHours,
    required this.month,
    required this.attendance,
    required this.calendar,
    required this.tomorrowLocation,
    required this.tomorrowSubtitle,
  });

  final String studentId;
  final String rollNumber;
  final String name;
  final String location;
  final String supervisorName;
  final List<ShiftWindow> windows;
  final String workDescription;
  final AttendanceRecord? todayRecord;
  final ApprovalStatus approval;
  final bool isOffDay;
  final double verifiedHours;
  final int maxMonthlyHours;
  final DateTime month;
  final List<AttendanceRecord> attendance;
  final List<CalendarEvent> calendar;
  final String tomorrowLocation;
  final String tomorrowSubtitle;
}

final studentHomeProvider = FutureProvider.autoDispose<StudentHomeData>((ref) async {
  final account = ref.watch(accountRepositoryProvider);
  final students = ref.watch(studentRepositoryProvider);
  final assignments = ref.watch(assignmentRepositoryProvider);
  final attendanceRepo = ref.watch(attendanceRepositoryProvider);
  final calendarRepo = ref.watch(calendarRepositoryProvider);

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
  if (assignment == null) {
    throw StateError('No active assignment for ${student.id}.');
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final month = DateTime(now.year, now.month);

  final todayRecord = await attendanceRepo.recordForDay(
    studentId: student.id,
    day: today,
  );
  final attendance = await attendanceRepo.recordsForMonth(
    studentId: student.id,
    month: month,
  );
  final events = await calendarRepo.eventsForMonth(month);

  final isOffDay = events.any((e) =>
      e.date.year == today.year &&
      e.date.month == today.month &&
      e.date.day == today.day &&
      e.type == CalendarEventType.offDay);

  final verifiedHours =
      attendance.fold<double>(0, (sum, r) => sum + r.verifiedHours);

  final locationName = assignment.locationName.isNotEmpty
      ? assignment.locationName
      : 'Assigned Location';

  return StudentHomeData(
    studentId: student.id,
    rollNumber: student.rollNumber,
    name: student.name,
    location: locationName,
    supervisorName: assignment.supervisorName,
    windows: assignment.shiftWindows,
    workDescription: assignment.workDescription,
    todayRecord: todayRecord,
    approval: todayRecord?.review ?? ApprovalStatus.pending,
    isOffDay: isOffDay,
    verifiedHours: verifiedHours,
    maxMonthlyHours: assignment.maxMonthlyHours,
    month: month,
    attendance: attendance,
    calendar: events,
    tomorrowLocation: locationName,
    tomorrowSubtitle:
        '${assignment.shiftLabel} • In-Charge: ${assignment.supervisorName}',
  );
});

class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(studentHomeProvider);

    return snapshot.when(
      loading: () => const _CenteredNote(
        icon: Icons.hourglass_empty,
        text: 'Loading your duty schedule…',
      ),
      error: (error, stackTrace) => _CenteredNote(
        icon: Icons.error_outline,
        text: error.toString(),
      ),
      data: (data) => _StudentHomeView(data: data),
    );
  }
}

class _StudentHomeView extends ConsumerStatefulWidget {
  const _StudentHomeView({required this.data});

  final StudentHomeData data;

  @override
  ConsumerState<_StudentHomeView> createState() => _StudentHomeViewState();
}

class _StudentHomeViewState extends ConsumerState<_StudentHomeView> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final now = DateTime.now();
    final state = deriveShiftState(
      now: now,
      windows: data.windows,
      today: data.todayRecord,
      approval: data.approval,
      isOffDay: data.isOffDay,
    );

    final verified = data.verifiedHours;
    final verifiedStr = _hours(verified);
    final daysWorked =
        data.attendance.where((r) => r.verifiedHours > 0).length;
    final remaining = data.maxMonthlyHours - verified;
    final ceilingCaption = data.maxMonthlyHours > 0
        ? '${_hours(remaining <= 0 ? 0 : remaining)} h to your ${data.maxMonthlyHours}-hour monthly ceiling'
        : 'Monthly ceiling: Not specified';

    final statusLabel = switch (state) {
      ShiftState.working => 'On duty',
      ShiftState.upcoming || ShiftState.ready => 'Scheduled',
      ShiftState.completed => 'Verified',
      ShiftState.pendingVerification => 'In review',
      ShiftState.flagged => 'Flagged',
      ShiftState.missed => 'Missed',
      ShiftState.offDay || ShiftState.leave => 'Off day',
    };

    final (IconData qaIcon, String qaLabel, String qaSub) = switch (state) {
      ShiftState.working => (Icons.power_settings_new, 'Check-Out', 'End duty'),
      ShiftState.completed => (Icons.verified_outlined, 'Verified', 'Today done'),
      ShiftState.pendingVerification =>
        (Icons.hourglass_empty, 'In review', 'Pending'),
      ShiftState.flagged => (Icons.flag_outlined, 'Resolve', 'Flagged'),
      _ => (Icons.power_settings_new, 'Check-In', 'Start duty'),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsBubble(
                initials: _initials(data.name),
                gradient: AppColors.heroForest,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.slate,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      data.name,
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
              _RoundIcon(
                icon: Icons.settings_outlined,
                onTap: () => context.go(RoutePaths.studentProfile),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          EspressoHero(
            value: verifiedStr,
            unit: 'verified\nhours',
            caption: ceilingCaption,
            leftPill: const HeroPill(label: 'Duty Tally', icon: Icons.schedule),
            stats: [
              HeroStat(label: 'This month', value: '$daysWorked days'),
              HeroStat(label: 'Verified', value: '$verifiedStr h'),
              HeroStat(
                label: 'Status',
                value: statusLabel,
                gold: state == ShiftState.working,
              ),
            ],
            trust: const [
              TrustItem(icon: Icons.place_outlined, label: 'Zone\nverified'),
              TrustItem(
                  icon: Icons.photo_camera_outlined, label: 'Selfie\nverified'),
              TrustItem(
                  icon: Icons.verified_user_outlined,
                  label: 'Supervisor\nsigned'),
            ],
          ),
          const SizedBox(height: 14),
          _identityRow(data),
          const SectionEyebrow(eyebrow: 'Today\'s schedule'),
          _scheduleCard(data),
          const SectionEyebrow(eyebrow: 'Quick actions'),
          Row(
            children: [
              Expanded(
                child: QuickAction(
                  icon: qaIcon,
                  label: qaLabel,
                  sub: qaSub,
                  iconGradient: AppColors.terraGrad,
                  onTap: () => studentPrimaryAction(context, ref, data),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuickAction(
                  icon: Icons.assignment_outlined,
                  label: 'Assignment',
                  sub: 'Duty details',
                  iconColor: WarmKit.espressoBase,
                  onTap: () => context.go(RoutePaths.studentAssignment),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: QuickAction(
                  icon: Icons.calendar_month_outlined,
                  label: 'Register',
                  sub: '$daysWorked days',
                  iconGradient: AppColors.goldSoftGrad,
                  iconFg: const Color(0xFF4A3915),
                  onTap: () => context.go(RoutePaths.studentAttendance),
                ),
              ),
            ],
          ),
          const SectionEyebrow(eyebrow: 'This week'),
          _nextShiftCard(data),
        ],
      ),
    );
  }

  static String _hours(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '—';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  Widget _identityRow(StudentHomeData data) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: WarmKit.shadowSm,
      ),
      child: Row(
        children: [
          const WarmIconWell(
            icon: Icons.badge_outlined,
            gradient: AppColors.heroForest,
            foreground: AppColors.onHeroWarm,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Eyebrow('Earn & Learn ID'),
                const SizedBox(height: 2),
                Text(
                  data.rollNumber,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontFamily: AppTextStyles.monoFamily,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const _ActiveDot(),
        ],
      ),
    );
  }
  /// Explicit "schedule of time" card — spells out today's duty window(s),
  /// planned daily hours, duty, location and in-charge from the real
  /// assignment fixture. Shows an honest "Not assigned" state when a shift
  /// window has not been set on the allotment.
  Widget _scheduleCard(StudentHomeData data) {
    final hasWindows = data.windows.isNotEmpty;
    final shiftText = hasWindows
        ? data.windows.map((w) => w.label).join('  ·  ')
        : 'Not assigned';
    final plannedMinutes =
        data.windows.fold<int>(0, (sum, w) => sum + w.duration.inMinutes);
    final plannedHours = plannedMinutes / 60.0;
    final plannedStr =
        hasWindows ? '${_hours(plannedHours)} h / day' : 'Not specified';

    return WarmCard(
      ivory: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const WarmIconWell(
                icon: Icons.schedule_outlined,
                gradient: AppColors.terraGrad,
                foreground: AppColors.surface,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('Duty window'),
                    const SizedBox(height: 3),
                    Text(
                      shiftText,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              if (data.windows.length > 1)
                const PremiumBadge(label: 'SPLIT', tone: BadgeTone.terra),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const HairDivider(),
          InfoLine(label: 'Planned', value: plannedStr),
          const HairDivider(),
          InfoLine(
            label: 'Duty',
            value: data.workDescription.isNotEmpty
                ? data.workDescription
                : 'Not specified',
          ),
          const HairDivider(),
          InfoLine(label: 'Location', value: data.location),
          const HairDivider(),
          InfoLine(label: 'In-charge', value: data.supervisorName),
        ],
      ),
    );
  }

  Widget _nextShiftCard(StudentHomeData data) {
    return AccentRow(
      accent: AppColors.terraSpark,
      lead: const WarmIconWell(
        icon: Icons.event_available_outlined,
        gradient: AppColors.terraGrad,
        foreground: AppColors.surface,
      ),
      title: data.tomorrowLocation,
      subtitle: data.tomorrowSubtitle,
      trailing: const RowChevron(),
      onTap: () => context.go(RoutePaths.studentAttendance),
    );
  }
}

/// Shared entry point for the student's primary duty action (Check-In /
/// Check-Out / resolve-flag), used by both the Home quick-action tile and the
/// shell's center action button so the FAB performs the real flow rather than
/// only switching tabs. Pure function of (context, ref, data): it reads the
/// live shift state and opens the correct flow.
void studentPrimaryAction(
  BuildContext context,
  WidgetRef ref,
  StudentHomeData data,
) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final state = deriveShiftState(
    now: now,
    windows: data.windows,
    today: data.todayRecord,
    approval: data.approval,
    isOffDay: data.isOffDay,
  );

  switch (state) {
    case ShiftState.upcoming:
    case ShiftState.ready:
      _startStudentAttendanceSheet(
          context, ref, data, today, AttendanceOpKind.checkIn);
    case ShiftState.working:
      final scheduledEnd = data.windows.isNotEmpty
          ? data.windows
              .map((w) => w.endOn(now))
              .reduce((a, b) => a.isAfter(b) ? a : b)
          : null;
      if (scheduledEnd != null && now.isBefore(scheduledEnd)) {
        final remaining = scheduledEnd.difference(now);
        final minutes = remaining.inMinutes;
        final hours = remaining.inHours;
        final remainingStr =
            hours > 0 ? '${hours}h ${minutes % 60}m' : '${minutes}m';

        showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppColors.clay, size: 22),
                SizedBox(width: AppSpacing.sm),
                Text('Early Check-Out'),
              ],
            ),
            content: Text(
              'Your shift ends in $remainingStr. If you check out now, only time worked so far will be submitted for verification.',
              style: AppTextStyles.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Continue Working'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: AppColors.surface,
                ),
                child: const Text('Proceed with Check-Out'),
              ),
            ],
          ),
        ).then((confirmed) {
          if (confirmed == true && context.mounted) {
            _startStudentAttendanceSheet(
                context, ref, data, today, AttendanceOpKind.checkOut);
          }
        });
      } else {
        _startStudentAttendanceSheet(
            context, ref, data, today, AttendanceOpKind.checkOut);
      }
    case ShiftState.completed:
      _studentSnack(context, 'Attendance verified for today.');
    case ShiftState.pendingVerification:
      _studentSnack(context, 'Attendance is being finalized by the supervisor.');
    case ShiftState.flagged:
      _showStudentFlaggedDialog(context, ref, data, today);
    case ShiftState.missed:
      _studentSnack(
          context, 'Shift was missed — contact supervisor for make-up.');
    case ShiftState.offDay:
    case ShiftState.leave:
      _studentSnack(context, 'No shift scheduled today.');
  }
}

void _startStudentAttendanceSheet(
  BuildContext context,
  WidgetRef ref,
  StudentHomeData data,
  DateTime today,
  AttendanceOpKind op,
) {
  final sessionId = data.todayRecord?.id ??
      '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  AttendanceFlowSheet.show(
    context: context,
    locationName: data.location,
    supervisorName: data.supervisorName,
    windows: data.windows,
    op: op,
    studentId: data.studentId,
    sessionId: sessionId,
    date: today,
  ).then((status) {
    if (status != null && context.mounted) {
      ref.invalidate(studentHomeProvider);
      final verb = op == AttendanceOpKind.checkIn ? 'Checked in' : 'Checked out';
      _studentSnack(context, '$verb: ${status.label}.');
    }
  });
}

void _showStudentFlaggedDialog(
  BuildContext context,
  WidgetRef ref,
  StudentHomeData data,
  DateTime today,
) {
  final reason = data.todayRecord?.exception ??
      'Supervisor flagged today\'s attendance entry. Please check details or submit a corrected attendance.';
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.flag_outlined, color: AppColors.clay, size: 22),
          SizedBox(width: AppSpacing.sm),
          Text('Supervisor Notice'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reason for flag / review:',
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.slate),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.clayLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.clay.withValues(alpha: 0.3)),
            ),
            child: Text(
              reason,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Dismiss'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            _startStudentAttendanceSheet(
                context, ref, data, today, AttendanceOpKind.checkIn);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.ink,
            foregroundColor: AppColors.surface,
          ),
          child: const Text('Resubmit Attendance'),
        ),
      ],
    ),
  );
}

void _studentSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
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

class _ActiveDot extends StatelessWidget {
  const _ActiveDot();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: AppColors.primaryBright,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'ACTIVE',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.divider),
          ),
          child: Icon(icon, size: 20, color: AppColors.ink),
        ),
      ),
    );
  }
}