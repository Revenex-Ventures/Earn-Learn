import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/status_style.dart';

/// One operational metric cell inside a [MetricGroup].
class MetricItem {
  const MetricItem({
    required this.label,
    required this.value,
    required this.icon,
    this.tone = StatusTone.neutral,
    this.detail,
  });

  final String label;
  final String value;
  final IconData icon;
  final StatusTone tone;
  final String? detail;
}

/// Compact operational metric group: a single surface broken into 2x2 cells
/// on phones and a 4-across row on wide layouts, separated by hairlines.
/// Strong numbers (Space Grotesk), semantic accent only where meaning exists.
class MetricGroup extends StatelessWidget {
  const MetricGroup({super.key, required this.items});

  final List<MetricItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 560;
          if (wide) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const _VerticalHairline(),
                    Expanded(child: _Cell(item: items[i])),
                  ],
                ],
              ),
            );
          }
          final rows = <Widget>[];
          for (var i = 0; i < items.length; i += 2) {
            rows.add(
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _Cell(item: items[i])),
                    const _VerticalHairline(),
                    Expanded(
                      child: i + 1 < items.length
                          ? _Cell(item: items[i + 1])
                          : const SizedBox(),
                    ),
                  ],
                ),
              ),
            );
            if (i + 2 < items.length) rows.add(const _HorizontalHairline());
          }
          return Column(children: rows);
        },
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.item});

  final MetricItem item;

  @override
  Widget build(BuildContext context) {
    final color = styleFor(item.tone, icon: item.icon, label: item.label).color;
    final bgTint = color.withValues(alpha: 0.10);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgTint,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(item.icon, size: 14, color: color),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.value,
            style: AppTextStyles.statMedium.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.slate),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (item.detail != null) ...[
            const SizedBox(height: 2),
            Text(
              item.detail!,
              style: AppTextStyles.labelSmall.copyWith(
                color: item.value.isEmpty ? AppColors.clay : AppColors.inkSoft,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _VerticalHairline extends StatelessWidget {
  const _VerticalHairline();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: double.infinity,
      child: VerticalDivider(width: 1, color: AppColors.divider),
    );
  }
}

class _HorizontalHairline extends StatelessWidget {
  const _HorizontalHairline();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, color: AppColors.divider);
  }
}