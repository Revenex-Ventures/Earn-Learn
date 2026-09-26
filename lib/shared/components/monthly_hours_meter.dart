import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';

/// Compact monthly hours meter: verified hours, the policy limit, remaining
/// hours and a progress bar. Presented without currency — only time worked.
class MonthlyHoursMeter extends StatelessWidget {
  const MonthlyHoursMeter({
    super.key,
    required this.verifiedHours,
    required this.maxMonthlyHours,
  });

  final double verifiedHours;
  final int maxMonthlyHours;

  @override
  Widget build(BuildContext context) {
    final max = maxMonthlyHours.toDouble();
    final remaining = (max - verifiedHours).clamp(0.0, max);
    final overLimit = verifiedHours >= max;
    final progress = (verifiedHours / max).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Monthly hours', style: AppTextStyles.titleMedium),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: overLimit ? AppColors.clayLight : AppColors.sageLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                '${remaining.toStringAsFixed(1)}h remaining',
                style: AppTextStyles.labelSmall.copyWith(
                  color: overLimit ? AppColors.clay : AppColors.sage,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${verifiedHours.toStringAsFixed(1)}h',
              style: AppTextStyles.statLarge,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'of ${maxMonthlyHours}h used',
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.paper,
            valueColor: AlwaysStoppedAnimation<Color>(
              overLimit ? AppColors.clay : AppColors.marigold,
            ),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}