import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';
import '../../data/data.dart';
import '../../domain/domain.dart';
import '../../shared/components/components.dart';
import 'attendance_flow_sheet.dart';
import 'check_in_controller.dart';

class StudentAttendanceData {
  const StudentAttendanceData({
    required this.studentId,
    required this.studentName,
    this.assignment,
    this.records = const [],
    this.events = const [],
    required this.month,
  });

  final String studentId;
  final String studentName;
  final Assignment? assignment;
  final List<AttendanceRecord> records;
  final List<CalendarEvent> events;
  final DateTime month;
}

final _studentAttendanceProvider =
    FutureProvider.family.autoDispose<StudentAttendanceData, DateTime>((ref, month) async {
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

  final normalizedMonth = DateTime(month.year, month.month);
  final records = await attendanceRepo.recordsForMonth(
    studentId: student.id,
    month: normalizedMonth,
  );
  final events = await calendarRepo.eventsForMonth(normalizedMonth);

  return StudentAttendanceData(
    studentId: student.id,
    studentName: student.name,
    assignment: assignment,
    records: records,
    events: events,
    month: normalizedMonth,
  );
});

class StudentAttendanceScreen extends ConsumerStatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  ConsumerState<StudentAttendanceScreen> createState() => _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState extends ConsumerState<StudentAttendanceScreen> {
  late DateTime _selectedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _previousMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      _selectedDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      _selectedDate = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(_studentAttendanceProvider(_selectedMonth));

    return asyncData.when(
      loading: () => const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 32, color: AppColors.clay),
              const SizedBox(height: AppSpacing.md),
              Text(err.toString(), style: AppTextStyles.bodyMedium),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () => ref.invalidate(_studentAttendanceProvider(_selectedMonth)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        if (data.assignment == null) {
          return const SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: EmptyState(
              icon: Icons.assignment_outlined,
              title: 'No active assignment',
              message: 'Attendance is recorded once you are placed at a work location.',
            ),
          );
        }
        return _buildContent(context, data);
      },
    );
  }

  Widget _buildContent(BuildContext context, StudentAttendanceData data) {
    final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);
    final assignment = data.assignment!;
    final maxMonthlyHours = assignment.maxMonthlyHours;
    final verified = data.records.fold<double>(0, (s, r) => s + r.verifiedHours);
    final remaining = (maxMonthlyHours - verified).clamp(0.0, maxMonthlyHours.toDouble());

    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday;

    final now = DateTime.now();
    final isViewingToday =
        _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;

    final selectedRecord = _recordOn(data.records, _selectedDate);
    final selectedEvent = _eventOn(data.events, _selectedDate);
    final dayState = _dayState(data, selectedRecord, selectedEvent);
    final todayShiftState = isViewingToday ? dayState : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ResponsivePage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContextHeader(
              greeting: 'Attendance Register',
              dateLine: monthName,
              trailing: InitialsAvatar(name: data.studentName),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MONTHLY REGISTER', style: AppTextStyles.labelSmall),
                      const SizedBox(height: 2),
                      Text(
                        '${data.records.length} day(s) logged',
                        style: AppTextStyles.titleLarge,
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 22),
                      onPressed: _previousMonth,
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 22),
                      onPressed: _nextMonth,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            MetricGroup(
              items: [
                MetricItem(
                  label: 'Days worked',
                  value: '${data.records.length}',
                  icon: Icons.today_outlined,
                ),
                MetricItem(
                  label: 'Present',
                  value: '${data.records.where((r) => r.status == AttendanceStatus.present).length}',
                  icon: Icons.check_circle_outline,
                  tone: StatusTone.positive,
                ),
                MetricItem(
                  label: 'Verified hours',
                  value: '${verified.toStringAsFixed(1)}h',
                  icon: Icons.hourglass_bottom,
                  tone: StatusTone.positive,
                ),
                MetricItem(
                  label: 'Remaining',
                  value: '${remaining.toStringAsFixed(1)}h',
                  icon: Icons.rule,
                  tone: StatusTone.attention,
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
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      _WeekdayLabel('M'),
                      _WeekdayLabel('T'),
                      _WeekdayLabel('W'),
                      _WeekdayLabel('T'),
                      _WeekdayLabel('F'),
                      _WeekdayLabel('S'),
                      _WeekdayLabel('S', isWeekend: true),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Divider(color: AppColors.divider, height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: (firstWeekday - 1) + daysInMonth,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      childAspectRatio: 1.15,
                    ),
                    itemBuilder: (context, index) {
                      if (index < firstWeekday - 1) {
                        return const SizedBox.shrink();
                      }
                      final day = index - (firstWeekday - 1) + 1;
                      final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                      final isSelected = date.year == _selectedDate.year &&
                          date.month == _selectedDate.month &&
                          date.day == _selectedDate.day;
                      final isTodayDate = date.year == now.year &&
                          date.month == now.month &&
                          date.day == now.day;

                      final record = _recordOn(data.records, date);
                      final event = _eventOn(data.events, date);

                      Color? dotColor;
                      if (event?.type == CalendarEventType.offDay) {
                        dotColor = AppColors.slate.withValues(alpha: 0.5);
                      } else if (record != null) {
                        dotColor = switch (record.status) {
                          AttendanceStatus.present => AppColors.sage,
                          AttendanceStatus.flagged => AppColors.clay,
                          AttendanceStatus.pending => AppColors.marigold,
                          AttendanceStatus.late => AppColors.marigold,
                          _ => AppColors.slate,
                        };
                      }

                      final isOffDay = event?.type == CalendarEventType.offDay;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedDate = date),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.ink
                                : isOffDay
                                    ? AppColors.paper
                                    : AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: isSelected
                                ? null
                                : isTodayDate
                                    ? Border.all(color: AppColors.marigold, width: 1.5)
                                    : Border.all(
                                        color: AppColors.divider.withValues(alpha: 0.6),
                                      ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$day',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: isSelected
                                      ? AppColors.surface
                                      : isTodayDate
                                          ? AppColors.ink
                                          : isOffDay
                                              ? AppColors.slate
                                              : AppColors.ink,
                                  fontWeight: isSelected || isTodayDate
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (dotColor != null)
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.surface : dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              else
                                const SizedBox(height: 4),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(color: AppColors.divider, height: 1),
                  const SizedBox(height: AppSpacing.md),
                  const Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _LegendItem(color: AppColors.marigold, label: 'Today'),
                      _LegendItem(color: AppColors.sage, label: 'Present'),
                      _LegendItem(color: AppColors.clay, label: 'Flagged / Exception'),
                      _LegendItem(color: AppColors.slate, label: 'Off day'),
                    ],
                  ),
                ],
              ),
            ),
            if (data.records.isEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              const EmptyState(
                icon: Icons.event_note_outlined,
                title: 'No attendance recorded',
                message: 'Verified attendance for this month will appear here.',
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              eyebrow: 'DAILY FLOW',
              title: DateFormat('EEEE, d MMMM yyyy').format(_selectedDate),
              trailing: _buildStatusBadge(selectedRecord, selectedEvent),
            ),
            const SizedBox(height: AppSpacing.md),
            if (isViewingToday && dayState == ShiftState.working) ...[
              _buildActiveWorkingCard(context, data, selectedRecord, assignment),
              const SizedBox(height: AppSpacing.lg),
            ],
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
                  Text('DUTY PROGRESSION', style: AppTextStyles.labelSmall),
                  const SizedBox(height: AppSpacing.sm),
                  AttendanceWorkflowStepper(
                    steps: dutyWorkflowSteps(
                      state: dayState,
                      today: selectedRecord,
                      approval: selectedRecord?.review ?? ApprovalStatus.pending,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Divider(color: AppColors.divider, height: 1),
                  const SizedBox(height: AppSpacing.md),
                  _detailRow('Assigned Location', assignment.locationName),
                  _detailRow('Shift Window', assignment.shiftLabel),
                  _detailRow('Supervisor In-Charge', assignment.supervisorName),
                  _detailRow(
                    'Recorded Hours',
                    selectedRecord != null ? '${selectedRecord.hours.toStringAsFixed(1)}h' : '0.0h',
                  ),
                  _detailRow(
                    'Verified Hours',
                    selectedRecord != null ? '${selectedRecord.verifiedHours.toStringAsFixed(1)}h' : '0.0h',
                  ),
                  if (selectedRecord?.checkIn != null)
                    _detailRow(
                      'Check-In Time',
                      DateFormat('h:mm a').format(selectedRecord!.checkIn!),
                    ),
                  if (selectedRecord?.checkOut != null)
                    _detailRow(
                      'Check-Out Time',
                      DateFormat('h:mm a').format(selectedRecord!.checkOut!),
                    ),
                  if (selectedRecord?.exception != null && selectedRecord!.exception!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.clayLight,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.clay.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.flag_outlined, size: 16, color: AppColors.clay),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                'Supervisor Note / Exception',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.clay,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedRecord.exception!,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.ink),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (isViewingToday && todayShiftState != null && todayShiftState != ShiftState.working) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _buildTodayAction(context, data, selectedRecord, todayShiftState),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveWorkingCard(
    BuildContext context,
    StudentAttendanceData data,
    AttendanceRecord? record,
    Assignment assignment,
  ) {
    final now = DateTime.now();
    final checkInTime = record?.checkIn ?? now;
    final elapsed = now.difference(checkInTime);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes % 60;
    final seconds = elapsed.inSeconds % 60;
    final timerString =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final targetHours = assignment.shiftWindows.isNotEmpty ? 2.0 : 2.0;
    final elapsedHours = elapsed.inMinutes / 60.0;
    final progress = (elapsedHours / targetHours).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.marigold.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.marigold.withValues(alpha: 0.08),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'WORKING IN ${assignment.locationName.toUpperCase()}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.marigold,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.marigoldLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.marigold,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ACTIVE',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.marigold,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            timerString,
            style: AppTextStyles.statLarge.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 2),
          Text(
            'Active session',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.slate),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: const [
              _SignalChip(
                icon: Icons.location_on_outlined,
                label: 'Location verified',
                color: AppColors.sage,
              ),
              _SignalChip(
                icon: Icons.verified_user_outlined,
                label: 'Selfie verified',
                color: AppColors.sage,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${targetHours.toStringAsFixed(1)} h target',
                style: AppTextStyles.labelSmall,
              ),
              Text(
                '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}',
                style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: AppColors.divider,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.sage),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openAttendanceFlow(
                context,
                data,
                AttendanceOpKind.checkOut,
                record?.id ??
                    '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Check Out with Evidence'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ShiftState _dayState(
    StudentAttendanceData data,
    AttendanceRecord? record,
    CalendarEvent? event,
  ) {
    final now = DateTime.now();
    final viewingToday =
        _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
    final projectionNow = viewingToday
        ? now
        : DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 12);

    return deriveShiftState(
      now: projectionNow,
      windows: data.assignment!.windowsOn(_selectedDate),
      today: record,
      approval: record?.review ?? ApprovalStatus.pending,
      isOffDay: event?.type == CalendarEventType.offDay,
    );
  }

  AttendanceRecord? _recordOn(List<AttendanceRecord> records, DateTime date) {
    for (final r in records) {
      if (r.date.year == date.year && r.date.month == date.month && r.date.day == date.day) {
        return r;
      }
    }
    return null;
  }

  CalendarEvent? _eventOn(List<CalendarEvent> events, DateTime date) {
    for (final e in events) {
      if (e.date.year == date.year && e.date.month == date.month && e.date.day == date.day) {
        return e;
      }
    }
    return null;
  }

  Widget _buildTodayAction(
    BuildContext context,
    StudentAttendanceData data,
    AttendanceRecord? record,
    ShiftState state,
  ) {
    switch (state) {
      case ShiftState.ready:
      case ShiftState.upcoming:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openAttendanceFlow(
              context,
              data,
              AttendanceOpKind.checkIn,
              record?.id,
            ),
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text('Start Attendance Check-In'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: AppColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
        );
      case ShiftState.working:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openAttendanceFlow(
              context,
              data,
              AttendanceOpKind.checkOut,
              record?.id ??
                  '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
            ),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Check Out with Evidence'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ink,
              foregroundColor: AppColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
        );
      case ShiftState.flagged:
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openAttendanceFlow(
              context,
              data,
              AttendanceOpKind.checkIn,
              record?.id,
            ),
            icon: const Icon(Icons.replay, size: 18),
            label: const Text('Resubmit Attendance Evidence'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
        );
      case ShiftState.completed:
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.sageLight,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified, color: AppColors.sage, size: 20),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Attendance verified for today.')),
            ],
          ),
        );
      case ShiftState.pendingVerification:
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.marigoldLight,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Row(
            children: [
              Icon(Icons.hourglass_top, color: AppColors.marigold, size: 20),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Attendance submitted — awaiting supervisor confirmation.'),
              ),
            ],
          ),
        );
      case ShiftState.missed:
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.clayLight,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: const Row(
            children: [
              Icon(Icons.event_busy, color: AppColors.clay, size: 20),
              SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Shift window ended without attendance.')),
            ],
          ),
        );
      case ShiftState.leave:
      case ShiftState.offDay:
        return const SizedBox.shrink();
    }
  }

  void _openAttendanceFlow(
    BuildContext context,
    StudentAttendanceData data,
    AttendanceOpKind op,
    String? sessionId,
  ) {
    AttendanceFlowSheet.show(
      context: context,
      locationName: data.assignment!.locationName,
      supervisorName: data.assignment!.supervisorName,
      windows: data.assignment!.shiftWindows,
      op: op,
      studentId: data.studentId,
      sessionId: sessionId,
      date: _selectedDate,
    ).then((status) {
      if (status != null && context.mounted) {
        ref.invalidate(_studentAttendanceProvider(_selectedMonth));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attendance updated: ${status.label}')),
        );
      }
    });
  }

  Widget _buildStatusBadge(AttendanceRecord? record, CalendarEvent? event) {
    if (event?.type == CalendarEventType.offDay) {
      return const StatusBadge(
        label: 'Weekly Off',
        style: StatusStyle(color: AppColors.slate, icon: Icons.event_busy, label: 'Weekly Off'),
      );
    }
    if (event != null && event.type != CalendarEventType.offDay) {
      return StatusBadge(
        label: event.label,
        style: StatusStyle(color: AppColors.marigold, icon: Icons.celebration, label: event.label),
      );
    }
    if (record == null) {
      return const StatusBadge(
        label: 'Scheduled',
        style: StatusStyle(color: AppColors.slate, icon: Icons.schedule, label: 'Scheduled'),
      );
    }
    final style = StatusStyle.fromAttendance(record.status);
    return StatusBadge(label: record.status.label, style: style);
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: AppTextStyles.bodySmall),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.text, {this.isWeekend = false});
  final String text;
  final bool isWeekend;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Center(
        child: Text(
          text,
          style: AppTextStyles.labelSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: isWeekend ? AppColors.clay : AppColors.slate,
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.labelSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}