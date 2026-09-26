import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/models/models.dart';
import '../../domain/attendance/session_status.dart';
import '../../shared/components/components.dart';
import '../attendance/face/face_providers.dart';
import 'check_in_controller.dart';

/// Modal bottom sheet driving the institutional student attendance journey
/// for check-in and check-out with mandatory selfie + GPS evidence.
class AttendanceFlowSheet extends ConsumerStatefulWidget {
  const AttendanceFlowSheet({
    super.key,
    required this.locationName,
    required this.supervisorName,
    required this.windows,
    required this.op,
    required this.studentId,
    this.sessionId,
    this.date,
    this.onCompleted,
  });

  final String locationName;
  final String supervisorName;
  final List<ShiftWindow> windows;
  final AttendanceOpKind op;
  final String studentId;
  final String? sessionId;
  final DateTime? date;
  final ValueChanged<SessionStatus>? onCompleted;

  static Future<SessionStatus?> show({
    required BuildContext context,
    required String locationName,
    required String supervisorName,
    required List<ShiftWindow> windows,
    required AttendanceOpKind op,
    required String studentId,
    String? sessionId,
    DateTime? date,
  }) {
    return showModalBottomSheet<SessionStatus>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => AttendanceFlowSheet(
        locationName: locationName,
        supervisorName: supervisorName,
        windows: windows,
        op: op,
        studentId: studentId,
        sessionId: sessionId,
        date: date,
        onCompleted: (status) => Navigator.of(ctx).pop(status),
      ),
    );
  }

  @override
  ConsumerState<AttendanceFlowSheet> createState() => _AttendanceFlowSheetState();
}

class _AttendanceFlowSheetState extends ConsumerState<AttendanceFlowSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = ref.read(attendanceFlowControllerProvider.notifier);
      if (widget.op == AttendanceOpKind.checkIn) {
        controller.prepareCheckIn(
          studentId: widget.studentId,
          date: widget.date ?? DateTime.now(),
        );
      } else {
        controller.prepareCheckOut(
          sessionId: widget.sessionId ??
              '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
        );
      }
      await controller.recoverLostSelfie();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(attendanceFlowControllerProvider);
    final controller = ref.read(attendanceFlowControllerProvider.notifier);

    final isCheckIn = widget.op == AttendanceOpKind.checkIn;
    final title = isCheckIn ? 'Duty Check-In' : 'Duty Check-Out';
    final shiftLabel = widget.windows.isEmpty
        ? 'Active Shift'
        : widget.windows.map((w) => w.label).join(' · ');

    final now = DateTime.now();
    final isEarlyCheckout = !isCheckIn &&
        widget.windows.isNotEmpty &&
        now.isBefore(widget.windows.map((w) => w.endOn(now)).reduce((a, b) => a.isAfter(b) ? a : b));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.sm,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Context Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EVIDENCE VERIFICATION',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.slate,
                            letterSpacing: 0.6,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(title, style: AppTextStyles.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.locationName} • In-charge: ${widget.supervisorName} • $shiftLabel',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: uiState.busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: AppSpacing.xs),

              // Visual 3-step indicator
              AttendanceStepper(
                currentStep: uiState.hasSelfie ? (uiState.hasGeo ? 2 : 1) : 0,
                hasSelfie: uiState.hasSelfie,
                hasLocation: uiState.hasGeo,
                isConfirmed: uiState.confirmedStatus != null,
              ),
              const SizedBox(height: AppSpacing.xs),

              // Institutional instructions
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified_user_outlined, size: 18, color: AppColors.ink),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'AVCOE policy requires a live front-facing selfie and on-campus GPS fix to record verified hours.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.ink, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Early Check-out notice if applicable
              if (isEarlyCheckout) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.clayLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.clay.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 20, color: AppColors.clay),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Early Check-Out: Scheduled shift is still in progress. Actual verified hours will be logged up to this timestamp.',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.ink),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Evidence Checklist / Acquisition
              Text('REQUIRED EVIDENCE', style: AppTextStyles.labelSmall),
              const SizedBox(height: AppSpacing.sm),

              _EvidenceItemTile(
                title: '1. Front-Facing Selfie',
                subtitle: uiState.selfie != null
                    ? 'Captured (${(uiState.selfie!.size / 1024).toStringAsFixed(0)} KB · ${uiState.selfie!.mimeType})'
                    : 'Clear photo at designated workplace',
                icon: Icons.camera_alt_outlined,
                imageBytes: uiState.selfie != null && uiState.selfie!.bytes.isNotEmpty
                    ? Uint8List.fromList(uiState.selfie!.bytes)
                    : null,
                isComplete: uiState.hasSelfie,
                onCapture: uiState.busy ? null : () => controller.captureSelfie(),
                actionLabel: uiState.hasSelfie ? 'Retake' : 'Capture',
              ),
              const SizedBox(height: AppSpacing.sm),

              _EvidenceItemTile(
                title: '2. Campus Location Fix',
                subtitle: uiState.geo != null
                    ? 'GPS: ${uiState.geo!.latitude.toStringAsFixed(4)}, ${uiState.geo!.longitude.toStringAsFixed(4)} (±${uiState.geo!.accuracyMeters.round()}m)'
                    : 'On-campus accuracy check',
                icon: Icons.location_on_outlined,
                isComplete: uiState.hasGeo,
                onCapture: uiState.busy ? null : () => controller.captureGeo(),
                actionLabel: uiState.hasGeo ? 'Re-acquire' : 'Acquire',
              ),
              const SizedBox(height: AppSpacing.sm),

              // Same-person verification. Purely informational: it reads the
              // model's availability and never gates the check-in. Deliberately
              // outside AttendanceFlowController - the state machine's contract
              // is selfie + GPS, and that is unchanged.
              _FaceVerificationNote(
                available: ref.watch(faceVerificationAvailableProvider),
              ),
              const SizedBox(height: AppSpacing.md),

              // Error banner if any
              if (uiState.error.isNotEmpty) ...[
                _ErrorBanner(
                  message: uiState.error,
                  category: uiState.errorCategory,
                  onRetry: () {
                    if (uiState.errorCategory == AttendanceErrorCategory.cameraPermissionDenied ||
                        uiState.errorCategory == AttendanceErrorCategory.cameraUnavailable) {
                      controller.captureSelfie();
                    } else if (uiState.errorCategory == AttendanceErrorCategory.locationPermissionDenied ||
                        uiState.errorCategory == AttendanceErrorCategory.locationServiceDisabled ||
                        uiState.errorCategory == AttendanceErrorCategory.poorAccuracy) {
                      controller.captureGeo();
                    } else {
                      controller.submitReviewedEvidence();
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Evidence Summary preview when complete
              if (uiState.isEvidenceComplete) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.sageLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.sage.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.sage, size: 20),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Both evidence components acquired. Ready for server submission.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // Actions
              Row(
                children: [
                  if (!uiState.isEvidenceComplete)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: uiState.busy
                            ? null
                            : () => controller.captureDualEvidence(),
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text('Capture Both'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ),
                  if (!uiState.isEvidenceComplete)
                    const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (uiState.isEvidenceComplete && !uiState.busy)
                          ? () async {
                              final status = await controller.submitReviewedEvidence();
                              if (status != null && context.mounted) {
                                widget.onCompleted?.call(status);
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        foregroundColor: AppColors.surface,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      child: uiState.busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.surface,
                              ),
                            )
                          : Text(
                              isCheckIn ? 'Submit Check-In' : 'Submit Check-Out',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: uiState.isEvidenceComplete
                                    ? AppColors.surface
                                    : AppColors.slate,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// States plainly whether same-person verification can run in this build.
///
/// When the detector is absent it says "Configuration required" rather than
/// showing a tick or hiding the row, because a silent skip would let an
/// unverified check-in look identical to a verified one.
class _FaceVerificationNote extends StatelessWidget {
  const _FaceVerificationNote({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(
            available ? Icons.face_retouching_natural : Icons.info_outline,
            size: 16,
            color: available ? AppColors.sage : AppColors.slate,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              available
                  ? 'Same-person check available.'
                  : 'Same-person check: configuration required, so this '
                      'check-in is not face-verified.',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceItemTile extends StatelessWidget {
  const _EvidenceItemTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isComplete,
    required this.onCapture,
    required this.actionLabel,
    this.imageBytes,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isComplete;
  final VoidCallback? onCapture;
  final String actionLabel;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isComplete ? AppColors.surface : AppColors.paper,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isComplete ? AppColors.sage : AppColors.divider,
          width: isComplete ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isComplete ? AppColors.sageLight : AppColors.divider.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageBytes != null
                ? Image.memory(imageBytes!, fit: BoxFit.cover)
                : Icon(
                    isComplete ? Icons.check : icon,
                    size: 20,
                    color: isComplete ? AppColors.sage : AppColors.ink,
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isComplete ? AppColors.sage : AppColors.slate,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCapture,
            style: TextButton.styleFrom(
              foregroundColor: isComplete ? AppColors.slate : AppColors.ink,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.category,
    required this.onRetry,
  });

  final String message;
  final AttendanceErrorCategory category;
  final VoidCallback onRetry;

  String _tipText() {
    switch (category) {
      case AttendanceErrorCategory.cameraPermissionDenied:
        return 'Camera access is required for identity verification. Please tap retry and allow permissions.';
      case AttendanceErrorCategory.cameraPermanentlyDenied:
        return 'Camera permission is permanently denied. Please enable Camera permissions in device Settings.';
      case AttendanceErrorCategory.cameraUnavailable:
        return 'No camera hardware detected. Please run on a device with a front camera.';
      case AttendanceErrorCategory.locationPermissionDenied:
        return 'Location access is required for campus presence verification.';
      case AttendanceErrorCategory.locationPermanentlyDenied:
        return 'Location permission is permanently denied. Please enable Location in device Settings.';
      case AttendanceErrorCategory.locationServiceDisabled:
        return 'Device GPS / Location Services are turned off. Please enable GPS in device settings.';
      case AttendanceErrorCategory.poorAccuracy:
        return 'GPS signal is weak. Please move outdoors or near a window for an institutional fix.';
      case AttendanceErrorCategory.evidenceIncomplete:
        return 'Both a selfie photo and on-campus GPS fix must be captured before submission.';
      case AttendanceErrorCategory.stateConflict:
        return 'Attendance session is in a conflicting state on the server. Please refresh your schedule.';
      default:
        return message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.clayLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.clay.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: AppColors.clay, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification Notice',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.clay,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _tipText(),
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.ink),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.clay,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
