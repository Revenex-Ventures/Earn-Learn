import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_radius.dart';
import 'status_badge.dart';

/// Flat list row with leading icon, title, subtitle, status, trailing.
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
    return Material(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 2,
        ),
        leading: leading,
        title: Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: AppTextStyles.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status != null) ...[
              status!,
              const SizedBox(width: AppSpacing.xs),
            ],
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: AppSpacing.xs),
            ],
            if (showChevron) ...[
              const Icon(
                Icons.chevron_right,
                color: AppColors.slate,
                size: 18,
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}