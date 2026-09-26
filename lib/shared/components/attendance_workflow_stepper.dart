import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/models/models.dart';

/// State of one step in the attendance lifecycle visualization.
enum WorkflowStepState { done, current, pending, flagged }

/// One step of the attendance lifecycle.
class WorkflowStep {
  const WorkflowStep({required this.label, required this.state});

  final String label;
  final WorkflowStepState state;
}

/// Accent color for a [WorkflowStepState].
/// done = sage (confirmed), current = marigold (needs action),
/// pending = slate (outline), flagged = clay (blocked).
Color workflowStepColor(WorkflowStepState state) => switch (state) {
      WorkflowStepState.done => AppColors.sage,
      WorkflowStepState.current => AppColors.marigold,
      WorkflowStepState.pending => AppColors.slate,
      WorkflowStepState.flagged => AppColors.clay,
    };

/// Pure mapping of the attendance lifecycle for the [ShiftState] / record
/// so the visualization never invents completion — every step is derived
/// from persisted fields (check-in, check-out, review) + the state machine.
List<WorkflowStep> dutyWorkflowSteps({
  required ShiftState state,
  required AttendanceRecord? today,
  required ApprovalStatus approval,
}) {
  final hasCheckIn = today?.checkIn != null;
  final hasCheckOut = today?.checkOut != null;
  final approved = approval == ApprovalStatus.approved &&
      state == ShiftState.completed;

  return [
    const WorkflowStep(label: 'Assigned', state: WorkflowStepState.done),
    WorkflowStep(
      label: 'Location',
      state: hasCheckIn ? WorkflowStepState.done : WorkflowStepState.pending,
    ),
    WorkflowStep(
      label: 'Selfie',
      state: hasCheckIn ? WorkflowStepState.done : WorkflowStepState.pending,
    ),
    WorkflowStep(
      label: 'Check-in',
      state: hasCheckIn
          ? WorkflowStepState.done
          : _primaryActionable(state)
              ? WorkflowStepState.current
              : WorkflowStepState.pending,
    ),
    WorkflowStep(
      label: 'Working',
      state: hasCheckOut
          ? WorkflowStepState.done
          : hasCheckIn
              ? state == ShiftState.working
                  ? WorkflowStepState.current
                  : WorkflowStepState.done
              : WorkflowStepState.pending,
    ),
    WorkflowStep(
      label: 'Check-out',
      state: hasCheckOut
          ? WorkflowStepState.done
          : WorkflowStepState.pending,
    ),
    WorkflowStep(
      label: 'Review',
      state: state == ShiftState.flagged
          ? WorkflowStepState.flagged
          : approval == ApprovalStatus.flagged
              ? WorkflowStepState.flagged
              : hasCheckOut
                  ? state == ShiftState.pendingVerification
                      ? WorkflowStepState.current
                      : WorkflowStepState.done
                  : WorkflowStepState.pending,
    ),
    WorkflowStep(
      label: 'Verified',
      state: approved
          ? WorkflowStepState.done
          : hasCheckOut
              ? state == ShiftState.pendingVerification
                  ? WorkflowStepState.pending
                  : WorkflowStepState.done
              : WorkflowStepState.pending,
    ),
  ];
}

bool _primaryActionable(ShiftState state) =>
    state == ShiftState.upcoming || state == ShiftState.ready;

/// Compact horizontal segmented attendance lifecycle visualization.
/// Uses green (completed), amber (current/pending), slate (future), red (flagged).
class AttendanceWorkflowStepper extends StatelessWidget {
  const AttendanceWorkflowStepper({super.key, required this.steps});

  final List<WorkflowStep> steps;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              _CompactStepBadge(
                step: steps[i],
                stepNumber: i + 1,
              ),
              if (i < steps.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: steps[i].state == WorkflowStepState.done
                        ? AppColors.sage
                        : AppColors.divider,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactStepBadge extends StatelessWidget {
  const _CompactStepBadge({
    required this.step,
    required this.stepNumber,
  });

  final WorkflowStep step;
  final int stepNumber;

  @override
  Widget build(BuildContext context) {
    final state = step.state;
    final isDone = state == WorkflowStepState.done;
    final isCurrent = state == WorkflowStepState.current;
    final isFlagged = state == WorkflowStepState.flagged;

    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final Widget iconWidget;

    if (isDone) {
      bgColor = AppColors.sageLight;
      borderColor = AppColors.sage.withValues(alpha: 0.3);
      textColor = AppColors.ink;
      iconWidget = const Icon(Icons.check, size: 11, color: AppColors.sage);
    } else if (isCurrent) {
      bgColor = AppColors.marigoldLight;
      borderColor = AppColors.marigold.withValues(alpha: 0.5);
      textColor = AppColors.ink;
      iconWidget = Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: AppColors.marigold,
          shape: BoxShape.circle,
        ),
      );
    } else if (isFlagged) {
      bgColor = AppColors.clayLight;
      borderColor = AppColors.clay.withValues(alpha: 0.4);
      textColor = AppColors.clay;
      iconWidget = const Icon(Icons.flag, size: 10, color: AppColors.clay);
    } else {
      bgColor = AppColors.paper;
      borderColor = AppColors.divider;
      textColor = AppColors.slate;
      iconWidget = Text(
        '$stepNumber',
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.slate,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(width: 5),
          Text(
            step.label,
            style: AppTextStyles.labelSmall.copyWith(
              color: textColor,
              fontWeight: isCurrent || isFlagged ? FontWeight.w700 : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}