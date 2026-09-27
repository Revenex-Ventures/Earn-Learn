import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';

/// A prominent, assigned-ID row.
///
/// Shows the identifier the institution assigns to a person for their role —
/// a student's Earn & Learn ID (EL2627-###), a supervisor ID (SV-##) or an
/// administrator's officer email — as a labelled, mono-typed value with an
/// accent-tinted icon and an optional trailing status widget.
class IdentityRow extends StatelessWidget {
  const IdentityRow({
    super.key,
    required this.label,
    required this.value,
    this.accent = AppColors.primary,
    this.icon = Icons.badge_outlined,
    this.trailing,
  });

  final String label;
  final String value;
  final Color accent;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient(accent),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.slate,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.statSmall.copyWith(
                    color: accent == AppColors.primary ? AppColors.ink : accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
