import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_elevation.dart';
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
    this.verifiedHours,
    this.maxMonthlyHours,
    this.daysWorked,
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

  /// Optional headline stats shown in the translucent strip (warm-premium look).
  final double? verifiedHours;
  final int? maxMonthlyHours;
  final int? daysWorked;

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
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppElevation.heroFor(AppColors.forestSoftDeep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: EyebrowLabel(text: "Today's Duty", color: Colors.white),
              ),
              if (isWorking)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'ACTIVE SHIFT',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: Colors.white,
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
                    Text(location, style: AppTextStyles.titleLarge.copyWith(color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(shiftLabel, style: AppTextStyles.labelMedium.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                  ],
                ),
              ),
              if (approval == ApprovalStatus.approved &&
                  state == ShiftState.completed)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.verified,
                    color: Colors.white,
                    size: 22,
                  ),
                )
              else if (windows.isNotEmpty)
                StatusBadge.status(style: stateStyle),
            ],
          ),
          if (verifiedHours != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(
                children: [
                  _HeroStat(
                    value: verifiedHours!.toStringAsFixed(verifiedHours! % 1 == 0 ? 0 : 1),
                    label: 'Verified hrs',
                  ),
                  _HeroDivider(),
                  _HeroStat(
                    value: (daysWorked ?? 0).toString(),
                    label: 'Days worked',
                  ),
                  _HeroDivider(),
                  _HeroStat(
                    value: maxMonthlyHours == null
                        ? '—'
                        : '${(maxMonthlyHours! - verifiedHours!).clamp(0, maxMonthlyHours!).toStringAsFixed(0)}h',
                    label: 'To ceiling',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: const [
                Expanded(child: _TrustCell(icon: Icons.place_outlined, label: 'Zone', value: 'Geo-lock')),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: _TrustCell(icon: Icons.photo_camera_outlined, label: 'Selfie', value: 'Verified')),
                SizedBox(width: AppSpacing.sm),
                Expanded(child: _TrustCell(icon: Icons.verified_user_outlined, label: 'Sign-off', value: 'Supervisor')),
              ],
            ),
          ],
          if (supervisorName != null || (workDescription != null && workDescription!.isNotEmpty)) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: Colors.white),
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
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
                          style: AppTextStyles.labelSmall.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          'Inside Assigned Zone',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.white,
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
                    style: AppTextStyles.statLarge.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    copy.subline,
                    style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 4,
                    children: const [
                      _SignalChip(
                        icon: Icons.verified_user_outlined,
                        label: 'Selfie Verified',
                        color: Colors.white,
                      ),
                      _SignalChip(
                        icon: Icons.location_on_outlined,
                        label: 'Campus Geo-Lock Active',
                        color: Colors.white,
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
                  Text(copy.headline, style: AppTextStyles.statMedium.copyWith(color: Colors.white)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(copy.subline, style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.85))),
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
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.labelSmall.copyWith(color: Colors.white.withValues(alpha: 0.7))),
              const SizedBox(height: 1),
              Text(
                value,
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTextStyles.statMedium.copyWith(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 9.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  const _HeroDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      color: Colors.white.withValues(alpha: 0.16),
    );
  }
}

class _TrustCell extends StatelessWidget {
  const _TrustCell({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(height: 6),
          Text(
            label.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 8.5,
              letterSpacing: 0.6,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: AppTextStyles.labelMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}