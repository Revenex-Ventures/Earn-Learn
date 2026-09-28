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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.warmLine,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Context Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WarmIconWell(
                    icon: isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                    gradient: AppColors.heroForest,
                    size: 42,
                    radius: AppRadius.sm,
                    iconSize: 20,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('Evidence Verification'),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.inkWarm,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${widget.locationName} • In-charge: ${widget.supervisorName} • $shiftLabel',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.slateWarm,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: uiState.busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20, color: AppColors.slateWarm),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const HairDivider(),
              const SizedBox(height: AppSpacing.md),

              // Visual 3-step indicator
              AttendanceStepper(
                currentStep: uiState.hasSelfie ? (uiState.hasGeo ? 2 : 1) : 0,
                hasSelfie: uiState.hasSelfie,
                hasLocation: uiState.hasGeo,
                isConfirmed: uiState.confirmedStatus != null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Institutional instructions
              const NoteBox(
                text: 'AVCOE policy requires a live front-facing selfie and on-campus GPS fix to record verified hours.',
                icon: Icons.verified_user_outlined,
              ),
              const SizedBox(height: AppSpacing.md),

              // Early Check-out notice if applicable
              if (isEarlyCheckout) ...[
                const SoftBox(
                  label: 'Early Check-Out: Scheduled shift is still in progress. Actual verified hours will be logged up to this timestamp.',
                  tone: BadgeTone.terra,
                  icon: Icons.info_outline,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Evidence Checklist / Acquisition
              const Eyebrow('Required Evidence'),
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
                const SoftBox(
                  label: 'Both evidence components acquired. Ready for server submission.',
                  tone: BadgeTone.forest,
                  icon: Icons.check_circle,
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
                          foregroundColor: AppColors.goldSoftDeep,
                          side: const BorderSide(color: AppColors.warmLine),
                          padding: const EdgeInsets.symmetric(vertical: 15),
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
                        backgroundColor: AppColors.terraSpark,
                        foregroundColor: AppColors.onHeroWarm,
                        disabledBackgroundColor: AppColors.warmIvory,
                        disabledForegroundColor: AppColors.slateWarm,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
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
                                color: AppColors.onHeroWarm,
                              ),
                            )
                          : Text(
                              isCheckIn ? 'Submit Check-In' : 'Submit Check-Out',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: uiState.isEvidenceComplete
                                    ? AppColors.onHeroWarm
                                    : AppColors.slateWarm,
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
    return SoftBox(
      icon: available ? Icons.face_retouching_natural : Icons.info_outline,
      tone: available ? BadgeTone.forest : BadgeTone.info,
      label: available
          ? 'Same-person check available.'
          : 'Same-person check: configuration required, so this '
              'check-in is not face-verified.',
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
        color: isComplete ? AppColors.warmSurface : AppColors.warmIvory,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isComplete ? AppColors.forestSoft : AppColors.warmLine,
          width: isComplete ? 1.5 : 1.0,
        ),
        boxShadow: WarmKit.shadowSm,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isComplete
                  ? const Color(0xFFE9F6EE)
                  : AppColors.goldTint,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: imageBytes != null
                ? Image.memory(imageBytes!, fit: BoxFit.cover)
                : Icon(
                    isComplete ? Icons.check_rounded : icon,
                    size: 20,
                    color: isComplete ? AppColors.forestSoft : AppColors.goldSoftDeep,
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.inkWarm,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isComplete ? AppColors.forestSoft : AppColors.slateWarm,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: onCapture,
            style: TextButton.styleFrom(
              foregroundColor: isComplete ? AppColors.slateWarm : AppColors.terraSpark,
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
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
        color: AppColors.clayTint,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.claySoftReject.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WarmIconWell(
                icon: Icons.error_outline,
                background: AppColors.claySoftReject,
                size: 34,
                radius: AppRadius.sm,
                iconSize: 18,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verification Notice',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.claySoftReject,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _tipText(),
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.inkWarm),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.claySoftReject,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
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
