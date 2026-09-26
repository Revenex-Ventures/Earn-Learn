import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';
import '../../domain/domain.dart';
import 'primary_button.dart';
import 'status_badge.dart';

/// Narration resolved from the derived state — also unit-testable.
class TodayPanelCopy {
  const TodayPanelCopy({
    required this.headline,
    required this.subline,
    this.actionLabel,
  });

  final String headline;
  final String subline;
  final String? actionLabel;
}

String _durationLabel(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (hours <= 0) return '${minutes}m';
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

String _elapsedLabel(Duration d) => _durationLabel(d);

String _clock(DateTime? t) => t != null ? DateFormat('h:mm a').format(t).toLowerCase() : '';

String _earliestStart(List<ShiftWindow> windows, DateTime now) {
  final starts = windows.map((w) => w.startOn(now)).toList()..sort();
  return _clock(starts.first);
}

TodayPanelCopy todayPanelCopy({
  required ShiftState state,
  required DateTime now,
  List<ShiftWindow> windows = const [],
  AttendanceRecord? today,
  ApprovalStatus approval = ApprovalStatus.pending,
}) {
  final location = today?.location ?? '';

  switch (state) {
    case ShiftState.upcoming:
      if (windows.isEmpty) {
        return const TodayPanelCopy(
          headline: 'No shift scheduled',
          subline: 'No active shift allotted for today.',
        );
      }
      final nextStart = windows.map((w) => w.startOn(now)).toList()..sort();
      final first = nextStart.first;
      final wait = first.difference(now);
      return TodayPanelCopy(
        headline: 'Starts in ${_durationLabel(wait)}',
        subline: 'Shift opens at ${_clock(first)} · $location',
        actionLabel: "I'm ready for shift",
      );
    case ShiftState.ready:
      final startStr = windows.isNotEmpty ? _earliestStart(windows, now) : '';
      return TodayPanelCopy(
        headline: 'Shift is starting',
        subline: 'Your shift started at $startStr · $location',
        actionLabel: 'Check in with selfie',
      );
    case ShiftState.working:
      final checkInTime = today?.checkIn;
      final elapsed = checkInTime != null
          ? now.difference(checkInTime)
          : Duration.zero;
      final elapsedStr = _elapsedLabel(elapsed);
      String subline = 'Checked in at ${_clock(checkInTime)} · $location';
      if (windows.isNotEmpty) {
        final ends = windows.map((w) => w.endOn(now)).toList()..sort();
        final currentEnd = ends.last;
        final remaining = currentEnd.difference(now);
        if (remaining > Duration.zero) {
          subline = 'Checked in at ${_clock(checkInTime)} · ${_durationLabel(remaining)} remaining';
        }
      }
      return TodayPanelCopy(
        headline: 'Working · $elapsedStr',
        subline: subline,
        actionLabel: 'Check out',
      );
    case ShiftState.pendingVerification:
      final hours = today?.verifiedHours ?? today?.hours ?? 0;
      return TodayPanelCopy(
        headline: 'Pending supervisor review',
        subline:
            '${hours.toStringAsFixed(1)} hrs recorded · Checked out at ${_clock(today?.checkOut)}',
      );
    case ShiftState.completed:
      final hours = today?.hours ?? 0;
      return TodayPanelCopy(
        headline: 'Verified for today',
        subline:
            '${hours.toStringAsFixed(1)} hrs verified · Completed at ${_clock(today?.checkOut)}',
      );
    case ShiftState.flagged:
      return const TodayPanelCopy(
        headline: 'Flagged for review',
        subline: 'Supervisor flagged your entry. Tap to see notes.',
        actionLabel: 'View details',
      );
    case ShiftState.missed:
      return const TodayPanelCopy(
        headline: 'Missed shift',
        subline: 'You missed today\'s shift. Contact supervisor.',
        actionLabel: 'Request make-up',
      );
    case ShiftState.leave:
      return const TodayPanelCopy(
        headline: 'Approved leave',
        subline: 'Your leave request for today is approved.',
      );
    case ShiftState.offDay:
      return const TodayPanelCopy(
        headline: 'Off day',
        subline: 'No work scheduled for today.',
      );
  }
}

/// Primary actionable shift card on the student home screen.
class TodayPanel extends StatelessWidget {
  const TodayPanel({
    super.key,
    required this.location,
    this.windows = const [],
    this.workDescription,
    this.today,
    this.approval = ApprovalStatus.pending,
    this.isLeave = false,
    this.isOffDay = false,
    this.now,
    this.onPrimaryAction,
    this.supervisorName,
  });

  final String location;
  final List<ShiftWindow> windows;
  final String? workDescription;
  final AttendanceRecord? today;
  final ApprovalStatus approval;
  final bool isLeave;
  final bool isOffDay;
  final DateTime? now;
  final VoidCallback? onPrimaryAction;
  final String? supervisorName;

  @override
  Widget build(BuildContext context) {
    final effectiveNow = now ?? DateTime.now();

    final state = deriveShiftState(
      now: effectiveNow,
      windows: windows,
      today: today,
      approval: approval,
      isLeave: isLeave,
      isOffDay: isOffDay,
    );
    final copy = todayPanelCopy(
      state: state,
      now: effectiveNow,
      windows: windows,
      today: today,
      approval: approval,
    );
    final stateStyle = state.style;

    final shiftLabel = windows.isEmpty
        ? 'No shift scheduled'
        : windows.map((w) => w.label).join(' · ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  location,
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: AppColors.surface,
                  ),
                ),
              ),
              if (approval == ApprovalStatus.approved && state == ShiftState.completed)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.verified, color: AppColors.marigold, size: 22),
                )
              else if (windows.isNotEmpty)
                StatusBadge(label: state.label, style: stateStyle),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            shiftLabel,
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.marigold,
              letterSpacing: 0.3,
            ),
          ),
          if (supervisorName != null && supervisorName!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Supervisor: $supervisorName',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.surface.withValues(alpha: 0.75),
              ),
            ),
          ],
          if (workDescription != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              workDescription!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.surface.withValues(alpha: 0.75),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 230),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: Column(
              key: ValueKey(state),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.headline,
                  style: AppTextStyles.statLarge.copyWith(color: AppColors.marigold),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  copy.subline,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.surface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          if (copy.actionLabel != null) ...[
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: copy.actionLabel!,
              onTap: onPrimaryAction ?? () {},
              isSecondary: state == ShiftState.completed ||
                  state == ShiftState.missed ||
                  state == ShiftState.offDay ||
                  state == ShiftState.pendingVerification,
            ),
          ],
        ],
      ),
    );
  }
}