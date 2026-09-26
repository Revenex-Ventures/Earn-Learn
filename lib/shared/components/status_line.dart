import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/status_style.dart';

/// Compact single-line status indicator: dot + label.
class StatusLine extends StatelessWidget {
  const StatusLine({
    super.key,
    required this.tone,
    required this.label,
    this.icon,
  });

  final StatusTone tone;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = styleFor(tone, icon: icon ?? Icons.circle, label: label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null)
          Icon(icon, size: 14, color: style.color)
        else
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
          ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(color: style.color),
        ),
      ],
    );
  }
}

/// Muted label + value line used across profile/detail screens.
class DetailLine extends StatelessWidget {
  const DetailLine({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = AppColors.ink,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(letterSpacing: 0.8),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTextStyles.bodyMedium.copyWith(color: valueColor),
          ),
        ),
      ],
    );
  }
}