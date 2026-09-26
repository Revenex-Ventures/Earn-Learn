import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';

/// Compact attendance glance: the current week (Mon–Sun) colored directly by
/// attendance status and calendar events, with today ringed. Keeps the month
/// calendar as a detail destination on the dedicated Attendance screen.
class WeekAttendanceStrip extends StatelessWidget {
  const WeekAttendanceStrip({
    super.key,
    required this.attendance,
    this.calendar = const [],
    this.today,
    this.onViewAll,
  });

  final List<AttendanceRecord> attendance;
  final List<CalendarEvent> calendar;
  final DateTime? today;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final effectiveToday = today ?? DateTime.now();
    final todayDate = DateTime(
      effectiveToday.year,
      effectiveToday.month,
      effectiveToday.day,
    );
    final monday = todayDate.subtract(Duration(days: todayDate.weekday - 1));
    final week = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];

    final byDay = {
      for (final r in attendance)
        DateTime(r.date.year, r.date.month, r.date.day): r,
    };
    final events = {
      for (final e in calendar)
        DateTime(e.date.year, e.date.month, e.date.day): e,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THIS MONTH',
                    style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 2),
                  Text('Attendance', style: AppTextStyles.titleLarge),
                ],
              ),
            ),
            if (onViewAll != null)
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  minimumSize: const Size(0, 36),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('View all', style: AppTextStyles.labelMedium),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 16, color: AppColors.ink),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  for (final day in week)
                    Expanded(
                      child: _WeekCell(
                        date: day,
                        record: byDay[
                            DateTime(day.year, day.month, day.day)],
                        event: events[
                            DateTime(day.year, day.month, day.day)],
                        isToday: day == todayDate,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: AppSpacing.md),
              const _WeekLegend(),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekCell extends StatelessWidget {
  const _WeekCell({
    required this.date,
    this.record,
    this.event,
    required this.isToday,
  });

  final DateTime date;
  final AttendanceRecord? record;
  final CalendarEvent? event;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final weekday = DateFormat('E').format(date).substring(0, 1);

    var fill = Colors.transparent;
    var numberColor = AppColors.slate;
    if (event != null) {
      fill = event!.type.style.color.withValues(alpha: 0.16);
      numberColor = event!.type.style.color;
    } else if (record != null) {
      fill = record!.status.style.color.withValues(alpha: 0.9);
      numberColor = AppColors.surface;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          weekday,
          style: AppTextStyles.labelSmall.copyWith(
            color: isToday ? AppColors.ink : AppColors.slate,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: fill == Colors.transparent
              ? (isToday
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.marigold, width: 2),
                    )
                  : null)
              : BoxDecoration(shape: BoxShape.circle, color: fill),
          child: Text(
            '${date.day}',
            style: AppTextStyles.labelMedium.copyWith(
              color: numberColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekLegend extends StatelessWidget {
  const _WeekLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: const [
        _LegendDot(tone: StatusTone.positive, label: 'Present'),
        _LegendDot(tone: StatusTone.attention, label: 'Pending'),
        _LegendDot(tone: StatusTone.negative, label: 'Late / absent / flagged'),
        _LegendDot(tone: StatusTone.neutral, label: 'Off day / leave'),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.tone, required this.label});

  final StatusTone tone;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = styleFor(tone, icon: Icons.circle, label: label).color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    );
  }
}