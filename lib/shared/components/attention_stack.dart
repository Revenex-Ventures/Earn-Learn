import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/status_style.dart';
import '../../core/models/models.dart';
import 'empty_state.dart';
import 'list_row.dart';
import 'section_header.dart';
import 'status_badge.dart';

/// Compact "stack" of items that need a decision: pending and flagged
/// verifications, newest first. Signals action density for the supervisor.
class AttentionStack extends StatelessWidget {
  const AttentionStack({
    super.key,
    required this.items,
    this.title = 'Needs your attention',
    this.eyebrow = 'Approval queue',
    this.maxVisible = 4,
    this.onItemTap,
    this.onViewAll,
  });

  final List<VerificationItem> items;
  final String title;
  final String eyebrow;
  final int maxVisible;
  final void Function(VerificationItem item)? onItemTap;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final needsAction =
        items.where((i) => i.status != ApprovalStatus.approved).toList()
          ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    final visible = needsAction.take(maxVisible).toList();
    final openCount = needsAction.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          eyebrow: eyebrow,
          title: title,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (openCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.clayLight,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '$openCount open',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.clay,
                    ),
                  ),
                ),
              if (onViewAll != null) ...[
                const SizedBox(width: AppSpacing.sm),
                InkWell(
                  onTap: onViewAll,
                  child: Text(
                    'View all',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (visible.isEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const EmptyState(
            icon: Icons.done_all,
            title: 'All clear',
            message: 'No items are waiting on a decision right now.',
          ),
        ] else ...[
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < visible.length; i++) ...[
            ListRow(
              leading: _TypeBadge(type: visible[i].type),
              title: '${visible[i].studentName} · ${visible[i].type.label}',
              subtitle: visible[i].location,
              status: StatusBadge.status(style: visible[i].status.style),
              showChevron: onItemTap != null,
              onTap: onItemTap == null ? null : () => onItemTap!(visible[i]),
            ),
            if (i != visible.length - 1) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final VerificationType type;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      VerificationType.checkIn => Icons.login,
      VerificationType.checkOut => Icons.logout,
      VerificationType.attendanceAudit => Icons.fact_check_outlined,
      VerificationType.correction => Icons.edit_note,
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(icon, size: 20, color: AppColors.inkSoft),
    );
  }
}