import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/status_style.dart';

/// Flat labelled statistic: small muted label above a large animated value.
/// Information first — no container unless the caller wraps it.
class StatBlock extends StatelessWidget {
  const StatBlock({
    super.key,
    required this.label,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.icon,
    this.tone = StatusTone.neutral,
    this.detail,
    this.animate = true,
  });

  final String label;
  final double value;
  final String prefix;
  final String suffix;
  final IconData? icon;
  final StatusTone tone;
  final String? detail;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final accent = styleFor(tone, icon: icon ?? Icons.circle, label: label).color;
    final formatter = NumberFormat('#,##0.#');

    final valueWidget = animate
        ? AnimatedNumber(
            value: value,
            format: (v) => '$prefix${formatter.format(v)}$suffix',
          )
        : Text('$prefix${formatter.format(value)}$suffix');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                label.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSmall.copyWith(letterSpacing: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        DefaultTextStyle.merge(
          style: AppTextStyles.statMedium,
          child: valueWidget,
        ),
        if (detail != null) ...[
          const SizedBox(height: 2),
          Text(detail!, style: AppTextStyles.bodySmall),
        ],
      ],
    );
  }
}

/// Count-up value driven by [TweenAnimationBuilder].
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.format,
    this.duration = const Duration(milliseconds: 300),
  });

  final double value;
  final String Function(double value) format;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Text(format(v)), //
    );
  }
}