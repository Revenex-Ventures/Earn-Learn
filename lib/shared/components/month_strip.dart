import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';

/// Signature month attendance strip: a full month grid whose cells are
/// colored directly by attendance status, with rest days pulled from the
/// calendar. Information first — no boxes, only signal.
class MonthStrip extends StatelessWidget {
  const MonthStrip({
    super.key,
    required this.month,
    required this.attendance,
    this.calendar = const [],
    this.today,
    this.showLegend = true,
    this.selectedDate,
    this.onDateSelected,
  });

  final DateTime month;
  final List<AttendanceRecord> attendance;
  final List<CalendarEvent> calendar;
  final DateTime? today;
  final bool showLegend;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDateSelected;

  @override
  Widget build(BuildContext context) {
    final effectiveToday = today ?? DateTime.now();
    final byDay = {for (final r in attendance) DateTime(r.date.year, r.date.month, r.date.day): r};
    final events = {for (final e in calendar) DateTime(e.date.year, e.date.month, e.date.day): e};

    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1;

    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox(),
      for (var day = 1; day <= daysInMonth; day++)
        Builder(
          builder: (context) => _DayCell(
            date: DateTime(month.year, month.month, day),
            record: byDay[DateTime(month.year, month.month, day)],
            event: events[DateTime(month.year, month.month, day)],
            isToday: effectiveToday.day == day &&
                effectiveToday.month == month.month &&
                effectiveToday.year == month.year,
            isSelected: selectedDate != null &&
                selectedDate!.day == day &&
                selectedDate!.month == month.month &&
                selectedDate!.year == month.year,
            now: effectiveToday,
            onTap: onDateSelected == null
                ? null
                : () => onDateSelected!(DateTime(month.year, month.month, day)),
          ),
        ),
    ];
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }

    final rows = <Widget>[
      for (var i = 0; i < cells.length; i += 7)
        Row(
          children: [
            for (var c = 0; c < 7; c++) Expanded(child: cells[i + c]),
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat.yMMMM().format(first),
                style: AppTextStyles.titleLarge,
              ),
            ),
            if (selectedDate != null)
              Text(
                DateFormat.EEEE().format(selectedDate!),
                style: AppTextStyles.labelSmall,
              )
            else
              Text(
                DateFormat.EEEE().format(effectiveToday),
                style: AppTextStyles.labelSmall,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        for (var i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i != rows.length - 1) const SizedBox(height: AppSpacing.xs),
        ],
        if (showLegend) ...[
          const SizedBox(height: AppSpacing.lg),
          const _Legend(),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    this.record,
    this.event,
    required this.isToday,
    required this.isSelected,
    required this.now,
    this.onTap,
  });

  final DateTime date;
  final AttendanceRecord? record;
  final CalendarEvent? event;
  final bool isToday;
  final bool isSelected;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final weekday = DateFormat('E').format(date).substring(0, 1);
    final isFuture = date.isAfter(DateTime(now.year, now.month, now.day));

    Color fill = Colors.transparent;
    Color numberColor = isFuture ? AppColors.divider : AppColors.slate;

    if (event != null) {
      fill = event!.type.style.color.withValues(alpha: 0.14);
      numberColor = event!.type.style.color;
    } else if (record != null) {
      fill = record!.status.style.color.withValues(alpha: 0.9);
      numberColor = AppColors.surface;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        height: 52,
        child: Column(
          children: [
            Text(weekday, style: AppTextStyles.labelSmall),
            const SizedBox(height: AppSpacing.xs),
            Container(
              width: 30,
              height: 30,
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
            if (isSelected) ...[
              const SizedBox(height: 2),
              Container(width: 16, height: 2, color: AppColors.marigold),
            ],
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
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