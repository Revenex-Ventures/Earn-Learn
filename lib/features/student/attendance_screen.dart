import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
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
    final presentCount =
        data.records.where((r) => r.status == AttendanceStatus.present).length;

    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_selectedMonth.year, _selectedMonth.month, 1).weekday;

    final now = DateTime.now();
    final isViewingToday =
        _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;

    final selectedRecord = _recordOn(data.records, _selectedDate);
    final selectedEvent = _eventOn(data.events, _selectedDate);
    final dayState = _dayState(data, selectedRecord, selectedEvent);
    final todayShiftState = isViewingToday ? dayState : null;
    final isWorkingNow = isViewingToday && dayState == ShiftState.working;

    final ceilingCaption = maxMonthlyHours > 0
        ? '${_h(remaining)} h to your $maxMonthlyHours-hour monthly ceiling'
        : 'Monthly ceiling: Not specified';

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
                  initials: _initials(data.studentName),
                  gradient: AppColors.heroForest,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance Register',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.slate,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        monthName,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
                _RoundNavIcon(icon: Icons.chevron_left, onTap: _previousMonth),
                const SizedBox(width: 8),
                _RoundNavIcon(icon: Icons.chevron_right, onTap: _nextMonth),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            EspressoHero(
              value: _h(verified),
              unit: 'verified\nhours',
              caption: ceilingCaption,
              leftPill: const HeroPill(
                  label: 'Monthly register', icon: Icons.calendar_month),
              rightPill: isWorkingNow
                  ? const PremiumBadge(
                      label: 'LIVE', tone: BadgeTone.terra, dot: true)
                  : null,
              stats: [
                HeroStat(label: 'Days', value: '${data.records.length}'),
                HeroStat(label: 'Present', value: '$presentCount'),
                HeroStat(
                    label: 'Remaining', value: '${_h(remaining)} h', gold: true),
              ],
              child: isWorkingNow ? _liveDutyRing(selectedRecord) : null,
            ),
            const SectionEyebrow(eyebrow: 'This month'),
            MetricTileGrid(
              items: [
                MetricTileData(
                  label: 'Days worked',
                  value: '${data.records.length}',
                  desc: 'Sessions logged',
                ),
                MetricTileData(
                  label: 'Present',
                  value: '$presentCount',
                  desc: 'Verified present',
                  tone: BadgeTone.forest,
                ),
                MetricTileData(
                  label: 'Verified hours',
                  value: '${_h(verified)}h',
                  desc: 'Counted to ceiling',
                  tone: BadgeTone.gold,
                ),
                MetricTileData(
                  label: 'Remaining',
                  value: '${_h(remaining)}h',
                  desc: 'To monthly ceiling',
                  tone: BadgeTone.terra,
                ),
              ],
            ),
            const SectionEyebrow(eyebrow: 'Register'),
            WarmCard(
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
                  const HairDivider(),
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
                        dotColor = AppColors.slateWarm.withValues(alpha: 0.5);
                      } else if (record != null) {
                        dotColor = switch (record.status) {
                          AttendanceStatus.present => AppColors.forestSoft,
                          AttendanceStatus.flagged => AppColors.claySoftReject,
                          AttendanceStatus.pending => AppColors.goldSoftDeep,
                          AttendanceStatus.late => AppColors.goldSoftDeep,
                          _ => AppColors.slateWarm,
                        };
                      }

                      final isOffDay = event?.type == CalendarEventType.offDay;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedDate = date),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? WarmKit.espressoBase
                                : isOffDay
                                    ? AppColors.warmIvory
                                    : AppColors.warmSurface,
                            borderRadius: BorderRadius.circular(9),
                            border: isSelected
                                ? null
                                : isTodayDate
                                    ? Border.all(color: AppColors.terraSpark, width: 1.5)
                                    : Border.all(color: AppColors.warmLine),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$day',
                                style: AppTextStyles.labelMedium.copyWith(
                                  color: isSelected
                                      ? AppColors.onHeroWarm
                                      : isOffDay
                                          ? AppColors.slateWarm
                                          : AppColors.inkWarm,
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
                                    color: isSelected ? AppColors.onHeroWarm : dotColor,
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
                  const HairDivider(),
                  const SizedBox(height: AppSpacing.md),
                  const Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _LegendItem(color: AppColors.terraSpark, label: 'Today'),
                      _LegendItem(color: AppColors.forestSoft, label: 'Present'),
                      _LegendItem(
                          color: AppColors.claySoftReject, label: 'Flagged / Exception'),
                      _LegendItem(color: AppColors.slateWarm, label: 'Off day'),
                    ],
                  ),
                ],
              ),
            ),
            if (data.records.isEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              const NoteBox(
                text: 'No verified attendance recorded for this month yet. '
                    'Confirmed sessions will appear on the register above.',
                icon: Icons.event_note_outlined,
              ),
            ],
            SectionEyebrow(
              eyebrow: 'Daily flow',
              title: DateFormat('EEEE, d MMMM').format(_selectedDate),
              trailing: _buildStatusBadge(selectedRecord, selectedEvent),
            ),
            if (isWorkingNow) ...[
              _buildActiveWorkingCard(context, data, selectedRecord, assignment),
              const SizedBox(height: 10),
            ],
            WarmCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('Duty progression'),
                  const SizedBox(height: 12),
                  AttendanceWorkflowStepper(
                    steps: dutyWorkflowSteps(
                      state: dayState,
                      today: selectedRecord,
                      approval: selectedRecord?.review ?? ApprovalStatus.pending,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const HairDivider(),
                  InfoLine(
                    label: 'Assigned location',
                    value: assignment.locationName.isNotEmpty
                        ? assignment.locationName
                        : 'Not assigned',
                  ),
                  const HairDivider(),
                  InfoLine(label: 'Shift window', value: assignment.shiftLabel),
                  const HairDivider(),
                  InfoLine(
                    label: 'Supervisor in-charge',
                    value: assignment.supervisorName.isNotEmpty
                        ? assignment.supervisorName
                        : 'Unassigned',
                  ),
                  const HairDivider(),
                  InfoLine(
                    label: 'Recorded hours',
                    value: selectedRecord != null
                        ? '${selectedRecord.hours.toStringAsFixed(1)}h'
                        : '0.0h',
                  ),
                  const HairDivider(),
                  InfoLine(
                    label: 'Verified hours',
                    value: selectedRecord != null
                        ? '${selectedRecord.verifiedHours.toStringAsFixed(1)}h'
                        : '0.0h',
                  ),
                  if (selectedRecord?.checkIn != null) ...[
                    const HairDivider(),
                    InfoLine(
                      label: 'Check-in time',
                      value: DateFormat('h:mm a').format(selectedRecord!.checkIn!),
                    ),
                  ],
                  if (selectedRecord?.checkOut != null) ...[
                    const HairDivider(),
                    InfoLine(
                      label: 'Check-out time',
                      value: DateFormat('h:mm a').format(selectedRecord!.checkOut!),
                    ),
                  ],
                  if (selectedRecord?.exception != null &&
                      selectedRecord!.exception!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SoftBox(
                      label: selectedRecord.exception!,
                      tone: BadgeTone.clay,
                      icon: Icons.flag_outlined,
                    ),
                  ],
                  if (isViewingToday &&
                      todayShiftState != null &&
                      todayShiftState != ShiftState.working) ...[
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

  Widget _liveDutyRing(AttendanceRecord? record) {
    final now = DateTime.now();
    final checkInTime = record?.checkIn ?? now;
    final elapsed = now.difference(checkInTime);
    final h = elapsed.inHours;
    final m = elapsed.inMinutes % 60;
    final timer = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    final progress = (elapsed.inMinutes / 60.0 / 2.0).clamp(0.0, 1.0);
    return Center(
      child: DutyRing(progress: progress, value: timer, label: 'On duty'),
    );
  }

  Widget _buildActiveWorkingCard(
    BuildContext context,
    StudentAttendanceData data,
    AttendanceRecord? record,
    Assignment assignment,
  ) {
    return WarmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Eyebrow(
                  assignment.locationName.isNotEmpty
                      ? 'Working in ${assignment.locationName}'
                      : 'On duty',
                  color: AppColors.terraSpark,
                ),
              ),
              const SizedBox(width: 8),
              const PremiumBadge(label: 'LIVE', tone: BadgeTone.terra, dot: true),
            ],
          ),
          const SizedBox(height: 12),
          const SoftBox(
            label: 'Selfie captured & matched at check-in',
            tone: BadgeTone.forest,
            icon: Icons.check_circle_outline,
          ),
          const SizedBox(height: 8),
          const SoftBox(
            label: 'Supervisor sign-off pending at check-out',
            tone: BadgeTone.gold,
            icon: Icons.schedule,
          ),
          const SizedBox(height: 14),
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
              icon: const Icon(Icons.power_settings_new, size: 18),
              label: const Text('Check Out & Submit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.terraSpark,
                foregroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
            ),
          ),
          const SizedBox(height: 11),
          const NoteBox(
            text: 'Check-out captures a fresh selfie and location, then submits '
                'the session for supervisor review.',
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
                context, data, AttendanceOpKind.checkIn, record?.id),
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text('Start Attendance Check-In'),
            style: ElevatedButton.styleFrom(
              backgroundColor: WarmKit.espressoBase,
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
            icon: const Icon(Icons.power_settings_new, size: 18),
            label: const Text('Check Out with Evidence'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terraSpark,
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
                context, data, AttendanceOpKind.checkIn, record?.id),
            icon: const Icon(Icons.replay, size: 18),
            label: const Text('Resubmit Attendance Evidence'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.inkWarm,
              side: const BorderSide(color: AppColors.warmLine),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
        );
      case ShiftState.completed:
        return const SoftBox(
          label: 'Attendance verified for today.',
          tone: BadgeTone.forest,
          icon: Icons.verified_outlined,
        );
      case ShiftState.pendingVerification:
        return const SoftBox(
          label: 'Attendance submitted — awaiting supervisor confirmation.',
          tone: BadgeTone.gold,
          icon: Icons.hourglass_top,
        );
      case ShiftState.missed:
        return const SoftBox(
          label: 'Shift window ended without attendance.',
          tone: BadgeTone.clay,
          icon: Icons.event_busy_outlined,
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
      return const PremiumBadge(label: 'Weekly Off', tone: BadgeTone.slate);
    }
    if (event != null && event.type != CalendarEventType.offDay) {
      return PremiumBadge(label: event.label, tone: BadgeTone.terra);
    }
    if (record == null) {
      return const PremiumBadge(label: 'Scheduled', tone: BadgeTone.slate);
    }
    final tone = switch (record.status) {
      AttendanceStatus.present => BadgeTone.forest,
      AttendanceStatus.flagged => BadgeTone.clay,
      AttendanceStatus.pending => BadgeTone.gold,
      AttendanceStatus.late => BadgeTone.gold,
      _ => BadgeTone.slate,
    };
    return PremiumBadge(label: record.status.label, tone: tone);
  }

  static String _h(num v) {
    final d = v.toDouble();
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toStringAsFixed(1);
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '—';
    if (parts.length == 1) {
      return parts.first.length >= 2
          ? parts.first.substring(0, 2).toUpperCase()
          : parts.first.toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
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
            color: isWeekend ? AppColors.claySoftReject : AppColors.slateWarm,
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

class _RoundNavIcon extends StatelessWidget {
  const _RoundNavIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.warmSurface,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.warmLine),
          ),
          child: Icon(icon, size: 20, color: AppColors.inkWarm),
        ),
      ),
    );
  }
}

