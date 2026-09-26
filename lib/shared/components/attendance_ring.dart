import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_text_styles.dart';

/// Circular progress indicator with percentage inside.
class AttendanceRing extends StatelessWidget {
  const AttendanceRing({
    super.key,
    required this.percentage,
    this.size = 80,
    this.strokeWidth = 8,
    this.label,
    this.valueText,
  });

  final double percentage;
  final double size;
  final double strokeWidth;
  final String? label;
  final String? valueText;

  @override
  Widget build(BuildContext context) {
    final effectivePercentage = percentage.clamp(0, 100);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: effectivePercentage / 100,
                  strokeWidth: strokeWidth,
                  backgroundColor: AppColors.divider,
                  color: effectivePercentage >= 75
                      ? AppColors.sage
                      : effectivePercentage >= 50
                          ? AppColors.marigold
                          : AppColors.clay,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    valueText ?? '${effectivePercentage.toInt()}%',
                    style: AppTextStyles.statSmall,
                  ),
                  if (label != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      label!,
                      style: AppTextStyles.labelSmall,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}