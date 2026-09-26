import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/app_spacing.dart';

/// A single row in a vertical timeline: leading status dot/icon, title,
/// subtitle and trailing time.
class TimelineRow extends StatelessWidget {
  const TimelineRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.timestamp,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final DateTime? timestamp;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: AppTextStyles.titleSmall),
                  ),
                  if (timestamp != null)
                    Text(
                      DateFormat('d MMM, h:mm a').format(timestamp!),
                      style: AppTextStyles.labelSmall,
                    ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: AppTextStyles.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}