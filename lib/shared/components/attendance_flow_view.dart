import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';

/// Stepper showing the 3-step Attendance journey:
/// 1. Selfie  ──  2. Location  ──  3. Confirm
class AttendanceStepper extends StatelessWidget {
  const AttendanceStepper({
    super.key,
    required this.currentStep,
    this.hasSelfie = false,
    this.hasLocation = false,
    this.isConfirmed = false,
  });

  /// 0 = Selfie, 1 = Location, 2 = Confirm
  final int currentStep;
  final bool hasSelfie;
  final bool hasLocation;
  final bool isConfirmed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StepIndicator(
            stepNumber: '1',
            label: 'Selfie',
            isActive: currentStep == 0,
            isCompleted: hasSelfie,
          ),
          _StepDivider(isCompleted: hasSelfie),
          _StepIndicator(
            stepNumber: '2',
            label: 'Location',
            isActive: currentStep == 1,
            isCompleted: hasLocation,
          ),
          _StepDivider(isCompleted: hasLocation),
          _StepIndicator(
            stepNumber: '3',
            label: 'Confirm',
            isActive: currentStep == 2,
            isCompleted: isConfirmed,
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.stepNumber,
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  final String stepNumber;
  final String label;
  final bool isActive;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final bgColor = isCompleted
        ? AppColors.avcoeGreen
        : (isActive ? AppColors.avcoeGreen : AppColors.divider);
    final fgColor = isCompleted || isActive ? AppColors.surface : AppColors.slate;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.avcoeGreen.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: isCompleted
              ? const Icon(Icons.check, size: 16, color: AppColors.surface)
              : Text(
                  stepNumber,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: fgColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: isActive || isCompleted ? AppColors.ink : AppColors.slate,
            fontWeight: isActive || isCompleted ? FontWeight.w600 : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _StepDivider extends StatelessWidget {
  const _StepDivider({required this.isCompleted});

  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
      color: isCompleted ? AppColors.avcoeGreen : AppColors.divider,
    );
  }
}

/// Circular silhouette & camera illustration for Step 1 (Selfie).
class SelfieSilhouetteView extends StatelessWidget {
  const SelfieSilhouetteView({
    super.key,
    this.imageBytes,
    this.onTap,
  });

  final List<int>? imageBytes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFE2E8F0),
          border: Border.all(
            color: AppColors.avcoeGreen.withValues(alpha: 0.4),
            width: 3,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: imageBytes != null && imageBytes!.isNotEmpty
            ? Image.memory(
                Uint8List.fromList(imageBytes!),
                fit: BoxFit.cover,
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  // Silhouette head & shoulders
                  Positioned(
                    top: 28,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF94A3B8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -15,
                    child: Container(
                      width: 90,
                      height: 65,
                      decoration: const BoxDecoration(
                        color: Color(0xFF94A3B8),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(45)),
                      ),
                    ),
                  ),
                  // Center camera icon overlay
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: AppColors.surface,
                      size: 22,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Concentric Radar Location Graphic for Step 2 (Location Verification).
class LocationRadarGraphic extends StatelessWidget {
  const LocationRadarGraphic({
    super.key,
    this.isAcquired = false,
  });

  final bool isAcquired;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 170,
        height: 170,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer concentric circle 3
            Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.avcoeGreen.withValues(alpha: 0.04),
                border: Border.all(
                  color: AppColors.avcoeGreen.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
            ),
            // Outer concentric circle 2
            Container(
              width: 125,
              height: 125,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.avcoeGreen.withValues(alpha: 0.08),
                border: Border.all(
                  color: AppColors.avcoeGreen.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
            ),
            // Inner concentric circle 1
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.avcoeGreen.withValues(alpha: 0.15),
              ),
            ),
            // Center pin badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.avcoeGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.avcoeGreen.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                isAcquired ? Icons.check : Icons.location_on,
                color: AppColors.surface,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Attendance Marked celebration view for Step 3 (Confirm).
class AttendanceSuccessView extends StatelessWidget {
  const AttendanceSuccessView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.workStation,
    required this.time,
    required this.onDone,
    this.buttonLabel = 'Go to Home',
  });

  final String title;
  final String subtitle;
  final String workStation;
  final String time;
  final VoidCallback onDone;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: AppSpacing.md),
        // Green Checkmark with decorative halo
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.avcoeGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.avcoeGreen.withValues(alpha: 0.35),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.check,
            size: 46,
            color: AppColors.surface,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          title,
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.slate,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),

        // Summary details card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              _SuccessDetailRow(
                icon: Icons.business_outlined,
                label: 'Work Station',
                value: workStation,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(color: AppColors.divider, height: 1),
              ),
              _SuccessDetailRow(
                icon: Icons.access_time_outlined,
                label: 'Time',
                value: time,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(color: AppColors.divider, height: 1),
              ),
              const _SuccessDetailRow(
                icon: Icons.verified_outlined,
                label: 'Location',
                value: 'Verified',
                valueColor: AppColors.avcoeGreen,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Primary Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.avcoeGreen,
              foregroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: Text(
              buttonLabel,
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.surface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SuccessDetailRow extends StatelessWidget {
  const _SuccessDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.slate),
        const SizedBox(width: AppSpacing.md),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.slate,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.ink,
          ),
        ),
      ],
    );
  }
}
