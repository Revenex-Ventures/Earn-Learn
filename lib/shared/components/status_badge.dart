import 'package:flutter/material.dart';

import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/status_style.dart';

/// Colored pill badge for status indicators.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.color,
    this.style,
    this.icon,
  });

  /// Badge derived from a centralized [StatusStyle].
  factory StatusBadge.status({
    Key? key,
    required StatusStyle style,
    String? label,
  }) {
    final effectiveLabel = label ?? style.label;
    return StatusBadge(
      key: key,
      label: effectiveLabel,
      style: style,
      color: style.color,
      icon: Icon(style.icon, size: 14, color: style.color),
    );
  }

  final String label;
  final Color? color;
  final StatusStyle? style;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? style?.color ?? const Color(0xFF6B7280);
    final effectiveIcon = icon ??
        (style != null
            ? Icon(style!.icon, size: 14, color: effectiveColor)
            : null);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (effectiveIcon != null) ...[
            effectiveIcon,
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSmall.copyWith(color: effectiveColor),
            ),
          ),
        ],
      ),
    );
  }
}