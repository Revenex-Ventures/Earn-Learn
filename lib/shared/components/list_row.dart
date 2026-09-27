import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_radius.dart';
import 'status_badge.dart';

/// Flat list row with leading icon, title, subtitle, status, trailing.
///
/// The tap target is a direct [InkWell] and the border is drawn by the outer
/// [Container] decoration (not a `Material.shape`). This avoids the Impeller
/// gesture hit-testing bug on Android 14 where a `Material` with a custom
/// [RoundedRectangleBorder] shape clips the child and swallows `ListTile.onTap`.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.status,
    this.showChevron = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final StatusBadge? status;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleMedium
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (status != null) ...[
            const SizedBox(width: AppSpacing.sm),
            status!,
          ],
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.xs),
            trailing!,
          ],
          if (showChevron) ...[
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.chevron_right,
              color: AppColors.slate,
              size: 18,
            ),
          ],
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.divider),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: content,
        ),
      ),
    );
  }
}
