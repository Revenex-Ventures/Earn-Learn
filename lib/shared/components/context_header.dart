import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/app_spacing.dart';

/// Comfortable screen opener: greeting, current date context and optional
/// trailing widget (avatar, action).
class ContextHeader extends StatelessWidget {
  const ContextHeader({
    super.key,
    required this.greeting,
    this.subGreeting,
    this.dateLine,
    this.trailing,
  });

  final String greeting;
  final String? subGreeting;
  final String? dateLine;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final effectiveDateLine = dateLine ?? _formattedToday();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                effectiveDateLine.toUpperCase(),
                style: AppTextStyles.labelSmall.copyWith(
                  letterSpacing: 1.2,
                  color: AppColors.slate,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                greeting,
                style: AppTextStyles.headlineMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
              if (subGreeting != null) ...[
                const SizedBox(height: 2),
                Text(
                  subGreeting!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.slate,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.md),
          trailing!,
        ],
      ],
    );
  }

  static String _formattedToday() =>
      DateFormat('EEEE, d MMM yyyy').format(DateTime.now());
}

/// Round initials avatar used as the standard trailing element.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.radius,
    this.color = AppColors.ink,
  });

  final String name;
  final double size;
  final double? radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final effectiveSize = radius != null ? radius! * 2 : size;
    final parts = name.trim().split(' ');
    final initial = parts.isEmpty
        ? '?'
        : parts.length == 1
            ? parts.first.substring(0, 1).toUpperCase()
            : (parts.first.substring(0, 1) + parts.last.substring(0, 1))
                .toUpperCase();

    return Container(
      width: effectiveSize,
      height: effectiveSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: AppTextStyles.titleMedium.copyWith(color: color),
      ),
    );
  }
}