import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/design_system/app_spacing.dart';
import 'primary_button.dart';

/// Recoverable failure state with a retry action.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'We could not load this section. Please try again.',
    this.retryLabel = 'Retry',
    this.onRetry,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.clayLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, size: 28, color: AppColors.clay),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: retryLabel,
                onTap: onRetry!,
                isSecondary: true,
                height: 44,
                width: 180,
              ),
            ],
          ],
        ),
      ),
    );
  }
}