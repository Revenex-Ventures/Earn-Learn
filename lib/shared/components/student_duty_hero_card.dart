import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';
import '../../domain/domain.dart';
import 'primary_button.dart';
import 'section_header.dart';
import 'status_badge.dart';
import 'today_panel.dart';

/// Primary "Today's Duty" focus card for the student home screen.
/// One cohesive surface card: identity + context, live shift narration and the
/// single attendance action. Reuses the existing deriveShiftState machine and
/// todayPanelCopy narration so behavior stays identical.
class StudentDutyHeroCard extends StatelessWidget {
  const StudentDutyHeroCard({
    super.key,
    required this.location,
    this.windows = const [],
    this.supervisorName,
    this.workDescription,
    this.today,
    this.approval = ApprovalStatus.pending,
    this.isLeave = false,
    this.isOffDay = false,
    this.now,
    this.onPrimaryAction,
  });

  final String location;
  final List<ShiftWindow> windows;
  final String? supervisorName;
  final String? workDescription;
  final AttendanceRecord? today;
  final ApprovalStatus approval;
  final bool isLeave;
  final bool isOffDay;
  final DateTime? now;
  final VoidCallback? onPrimaryAction;

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

    final isWorking = state == ShiftState.working;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isWorking
              ? AppColors.marigold.withValues(alpha: 0.6)
              : AppColors.divider,
        ),
        boxShadow: [
          BoxShadow(
            color: isWorking
                ? AppColors.marigold.withValues(alpha: 0.08)
                : AppColors.ink.withValues(alpha: 0.04),
            offset: const Offset(0, 4),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: EyebrowLabel(text: "Today's Duty"),
              ),
              if (isWorking)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
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
                        Flexible(
                          child: Text(
                            'ACTIVE SHIFT',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.marigold,
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(location, style: AppTextStyles.titleLarge),
                    const SizedBox(height: 2),
                    Text(shiftLabel, style: AppTextStyles.labelMedium),
                  ],
                ),
              ),
              if (approval == ApprovalStatus.approved &&
                  state == ShiftState.completed)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.verified,
                    color: AppColors.sage,
                    size: 22,
                  ),
                )
              else if (windows.isNotEmpty)
                StatusBadge.status(style: stateStyle),
            ],
          ),
          if (supervisorName != null || (workDescription != null && workDescription!.isNotEmpty)) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: AppSpacing.md),
            if (supervisorName != null && supervisorName!.isNotEmpty) ...[
              _MetaRow(
                icon: Icons.badge_outlined,
                label: 'In-Charge',
                value: supervisorName!,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (workDescription != null && workDescription!.isNotEmpty)
              _MetaRow(
                icon: Icons.menu_book_outlined,
                label: 'Duty',
                value: workDescription!,
              ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (isWorking) ...[
            // Active session live state block
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'ELAPSED SHIFT TIME',
                          style: AppTextStyles.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          'Inside Assigned Zone',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.sage,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    copy.headline,
                    style: AppTextStyles.statLarge.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    copy.subline,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 4,
                    children: const [
                      _SignalChip(
                        icon: Icons.verified_user_outlined,
                        label: 'Selfie Verified',
                        color: AppColors.sage,
                      ),
                      _SignalChip(
                        icon: Icons.location_on_outlined,
                        label: 'Campus Geo-Lock Active',
                        color: AppColors.sage,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 230),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: Column(
                key: ValueKey(state),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(copy.headline, style: AppTextStyles.statMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(copy.subline, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ],
          if (copy.actionLabel != null) ...[
            const SizedBox(height: AppSpacing.lg),
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

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.slate),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.labelSmall),
              const SizedBox(height: 1),
              Text(
                value,
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}