import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_radius.dart';

/// Primary call-to-action button.
/// Ink-filled with Marigold accent or white secondary variant.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.isSecondary = false,
    this.width,
    this.height = 56,
  });

  final String label;
  final VoidCallback onTap;
  final Widget? icon;
  final bool isSecondary;
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isSecondary ? AppColors.surface : AppColors.ink;
    final foregroundColor = isSecondary ? AppColors.ink : AppColors.marigold;
    final borderColor = isSecondary ? AppColors.divider : Colors.transparent;

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: backgroundColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  icon!,
                  SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.labelLarge.copyWith(color: foregroundColor),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}