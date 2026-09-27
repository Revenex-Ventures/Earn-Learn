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

final _studentHomeProvider = FutureProvider.autoDispose<StudentHomeData>((ref) async {
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
    final snapshot = ref.watch(_studentHomeProvider);

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

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
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
    final verifiedHours = data.verifiedHours;
    final maxMonthlyHours = data.maxMonthlyHours;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContextHeader(
            greeting: '${StudentHomeScreen._greeting()}, ${data.name}!',
            subGreeting: 'Keep going, you\'re doing great!',
            trailing: InitialsAvatar(name: data.name),
          ),
          const SizedBox(height: AppSpacing.lg),
          IdentityRow(
            label: 'Earn & Learn ID',
            value: data.rollNumber,
            icon: Icons.badge_outlined,
            trailing: const _ActiveDot(),
          ),
          const SizedBox(height: AppSpacing.lg),
          StudentDutyHeroCard(
            location: data.location,
            supervisorName: data.supervisorName,
            windows: data.windows,
            workDescription: data.workDescription,
            today: data.todayRecord,
            approval: data.approval,
            isOffDay: data.isOffDay,
            onPrimaryAction: () => _primary(context, ref, data),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Quick Actions Row matching design reference
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.calendar_month_outlined,
                  label: 'Check-In',
                  onTap: () => context.go(RoutePaths.studentAttendance),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.assignment_outlined,
                  label: 'Assignments',
                  onTap: () => context.go(RoutePaths.studentAssignment),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.person_outline,
                  label: 'Profile',
                  onTap: () => context.go(RoutePaths.studentProfile),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MonthlyHoursMeter(
                  verifiedHours: verifiedHours,
                  maxMonthlyHours: maxMonthlyHours,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Divider(height: 1, color: AppColors.divider),
                ),
                UpcomingShiftTile(
                  location: data.tomorrowLocation,
                  subtitle: data.tomorrowSubtitle,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          WeekAttendanceStrip(
            attendance: data.attendance,
            calendar: data.calendar,
            onViewAll: () => context.go(RoutePaths.studentAttendance),
          ),
        ],
      ),
    );
  }

  void _primary(BuildContext context, WidgetRef ref, StudentHomeData data) {
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
        _startAttendanceSheet(context, ref, data, today, AttendanceOpKind.checkIn);
      case ShiftState.working:
        final scheduledEnd = data.windows.isNotEmpty
            ? data.windows.map((w) => w.endOn(now)).reduce((a, b) => a.isAfter(b) ? a : b)
            : null;
        if (scheduledEnd != null && now.isBefore(scheduledEnd)) {
          final remaining = scheduledEnd.difference(now);
          final minutes = remaining.inMinutes;
          final hours = remaining.inHours;
          final remainingStr = hours > 0 ? '${hours}h ${minutes % 60}m' : '${minutes}m';

          showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.clay, size: 22),
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
              _startAttendanceSheet(context, ref, data, today, AttendanceOpKind.checkOut);
            }
          });
        } else {
          _startAttendanceSheet(context, ref, data, today, AttendanceOpKind.checkOut);
        }
      case ShiftState.completed:
        _snack(context, 'Attendance verified for today.');
      case ShiftState.pendingVerification:
        _snack(context, 'Attendance is being finalized by the supervisor.');
      case ShiftState.flagged:
        _showFlaggedDialog(context, ref, data, today);
      case ShiftState.missed:
        _snack(context, 'Shift was missed — contact supervisor for make-up.');
      case ShiftState.offDay:
      case ShiftState.leave:
        _snack(context, 'No shift scheduled today.');
    }
  }

  void _startAttendanceSheet(
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
        ref.invalidate(_studentHomeProvider);
        final verb = op == AttendanceOpKind.checkIn ? 'Checked in' : 'Checked out';
        _snack(context, '$verb: ${status.label}.');
      }
    });
  }

  void _showFlaggedDialog(
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
              _startAttendanceSheet(context, ref, data, today, AttendanceOpKind.checkIn);
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

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: AppColors.ink),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}