// ignore_for_file: prefer_initializing_formals

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/evidence/evidence_geo.dart';
import '../../core/evidence/evidence_service.dart';
import '../../core/evidence/evidence_types.dart';
import '../../core/evidence/evidence_uploader.dart';
import '../../core/evidence/geolocation.dart';
import '../../core/evidence/selfie_capture.dart';
import '../../data/app_flavor.dart';
import '../../data/firebase/attendance_gateway.dart';
import '../../data/local/local_repositories.dart';
import '../../domain/attendance/session_status.dart';

enum AttendanceFlowStep {
  idle,
  explaining,
  capturing,
  reviewing,
  submitting,
  completed,
  failed,
}

enum AttendanceOpKind {
  checkIn,
  checkOut,
}

enum AttendanceErrorCategory {
  none,
  cameraPermissionDenied,
  cameraPermanentlyDenied,
  cameraUnavailable,
  locationPermissionDenied,
  locationPermanentlyDenied,
  locationServiceDisabled,
  poorAccuracy,
  evidenceIncomplete,
  duplicateSubmission,
  stateConflict,
  gatewayFailure,
  unknown,
}

class AttendanceFlowUi {
  const AttendanceFlowUi({
    this.busy = false,
    this.error = '',
    this.errorCategory = AttendanceErrorCategory.none,
    this.done = '',
    this.step = AttendanceFlowStep.idle,
    this.op = AttendanceOpKind.checkIn,
    this.selfie,
    this.geo,
    this.sessionId,
    this.studentId,
    this.date,
    this.confirmedStatus,
  });

  final bool busy;

  /// User-facing failure message (evidence missing, unlinked, conflict…).
  final String error;

  final AttendanceErrorCategory errorCategory;

  /// Set when the current step completed successfully.
  final String done;

  final AttendanceFlowStep step;
  final AttendanceOpKind op;
  final SelfieCapture? selfie;
  final EvidenceGeo? geo;
  final String? sessionId;
  final String? studentId;
  final DateTime? date;
  final SessionStatus? confirmedStatus;

  bool get hasSelfie => selfie != null;
  bool get hasGeo => geo != null;
  bool get isEvidenceComplete => hasSelfie && hasGeo;

  AttendanceFlowUi copyWith({
    bool? busy,
    String? error,
    AttendanceErrorCategory? errorCategory,
    String? done,
    AttendanceFlowStep? step,
    AttendanceOpKind? op,
    SelfieCapture? selfie,
    EvidenceGeo? geo,
    String? sessionId,
    String? studentId,
    DateTime? date,
    SessionStatus? confirmedStatus,
    bool clearSelfie = false,
    bool clearGeo = false,
  }) {
    return AttendanceFlowUi(
      busy: busy ?? this.busy,
      error: error ?? this.error,
      errorCategory: errorCategory ?? this.errorCategory,
      done: done ?? this.done,
      step: step ?? this.step,
      op: op ?? this.op,
      selfie: clearSelfie ? null : (selfie ?? this.selfie),
      geo: clearGeo ? null : (geo ?? this.geo),
      sessionId: sessionId ?? this.sessionId,
      studentId: studentId ?? this.studentId,
      date: date ?? this.date,
      confirmedStatus: confirmedStatus ?? this.confirmedStatus,
    );
  }
}

/// Drives the student check-in / check-out evidence flow end to end:
///
///   explain → capture → review → gateway initiation → upload → server confirmation.
class AttendanceFlowController extends StateNotifier<AttendanceFlowUi> {
  AttendanceFlowController({
    required AttendanceGateway gateway,
    required EvidenceService evidenceService,
    SelfieCapturer? selfieCapturer,
    GeoSampler? geoSampler,
  })  : _gateway = gateway,
        _evidence = evidenceService,
        _selfieCapturer = selfieCapturer ?? const ImagePickerSelfieCapturer(),
        _geoSampler = geoSampler ?? const GeolocatorSampler(),
        super(const AttendanceFlowUi());

  final AttendanceGateway _gateway;
  final EvidenceService _evidence;
  final SelfieCapturer _selfieCapturer;
  final GeoSampler _geoSampler;

  /// Last user-facing failure message ('' on success).
  String get lastError => state.error;

  /// Initialize check-in interactive flow without blowing away existing in-progress state.
  void prepareCheckIn({
    required String studentId,
    required DateTime date,
  }) {
    if (state.op == AttendanceOpKind.checkIn &&
        state.studentId == studentId &&
        state.date?.year == date.year &&
        state.date?.month == date.month &&
        state.date?.day == date.day) {
      // Retain acquired evidence, checkout mode, and flow step across widget rebuilds / lifecycle pauses.
      return;
    }
    state = AttendanceFlowUi(
      step: AttendanceFlowStep.explaining,
      op: AttendanceOpKind.checkIn,
      studentId: studentId,
      date: date,
    );
  }

  /// Initialize check-out interactive flow without blowing away existing in-progress state.
  void prepareCheckOut({
    required String sessionId,
  }) {
    if (state.op == AttendanceOpKind.checkOut &&
        state.sessionId == sessionId) {
      // Retain acquired evidence, checkout mode, and flow step across widget rebuilds / lifecycle pauses.
      return;
    }
    state = AttendanceFlowUi(
      step: AttendanceFlowStep.explaining,
      op: AttendanceOpKind.checkOut,
      sessionId: sessionId,
    );
  }

  /// Checks for any lost camera capture if the Android host activity was temporarily killed.
  Future<void> recoverLostSelfie() async {
    if (state.selfie != null) return;
    try {
      final lost = await _selfieCapturer.retrieveLostData();
      if (lost != null) {
        final nextStep = state.geo != null ? AttendanceFlowStep.reviewing : AttendanceFlowStep.capturing;
        state = state.copyWith(
          selfie: lost,
          step: nextStep,
        );
      }
    } catch (_) {}
  }

  /// Interactive selfie capture step.
  Future<SelfieCapture?> captureSelfie() async {
    state = state.copyWith(busy: true, error: '', errorCategory: AttendanceErrorCategory.none);
    try {
      final selfie = await _selfieCapturer.capture();
      if (selfie == null) {
        state = state.copyWith(
          busy: false,
          error: 'Selfie capture was cancelled.',
          errorCategory: AttendanceErrorCategory.none,
        );
        return null;
      }
      final nextStep = state.geo != null ? AttendanceFlowStep.reviewing : AttendanceFlowStep.capturing;
      state = state.copyWith(
        busy: false,
        selfie: selfie,
        step: nextStep,
      );
      return selfie;
    } on CameraPermissionDeniedException catch (e) {
      state = state.copyWith(
        busy: false,
        error: e.message,
        errorCategory: AttendanceErrorCategory.cameraPermissionDenied,
        step: AttendanceFlowStep.failed,
      );
      return null;
    } on CameraPermanentlyDeniedException catch (e) {
      state = state.copyWith(
        busy: false,
        error: e.message,
        errorCategory: AttendanceErrorCategory.cameraPermanentlyDenied,
        step: AttendanceFlowStep.failed,
      );
      return null;
    } on CameraUnavailableException catch (e) {
      state = state.copyWith(
        busy: false,
        error: e.message,
        errorCategory: AttendanceErrorCategory.cameraUnavailable,
        step: AttendanceFlowStep.failed,
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        busy: false,
        error: e.toString(),
        errorCategory: AttendanceErrorCategory.unknown,
        step: AttendanceFlowStep.failed,
      );
      return null;
    }
  }

  /// Interactive GPS capture step.
  Future<EvidenceGeo?> captureGeo() async {
    state = state.copyWith(busy: true, error: '', errorCategory: AttendanceErrorCategory.none);
    try {
      final geo = await _geoSampler.sample();
      if (geo == null) {
        state = state.copyWith(
          busy: false,
          error: 'Could not obtain location fix.',
          errorCategory: AttendanceErrorCategory.locationServiceDisabled,
          step: AttendanceFlowStep.failed,
        );
        return null;
      }
      final nextStep = state.selfie != null ? AttendanceFlowStep.reviewing : AttendanceFlowStep.capturing;
      state = state.copyWith(
        busy: false,
        geo: geo,
        step: nextStep,
      );
      return geo;
    } on LocationServiceDisabledException catch (e) {
      state = state.copyWith(
        busy: false,
        error: e.message,
        errorCategory: AttendanceErrorCategory.locationServiceDisabled,
        step: AttendanceFlowStep.failed,
      );
      return null;
    } on LocationPermissionDeniedException catch (e) {
      state = state.copyWith(
        busy: false,
        error: e.message,
        errorCategory: AttendanceErrorCategory.locationPermissionDenied,
        step: AttendanceFlowStep.failed,
      );
      return null;
    } on LocationPermanentlyDeniedException catch (e) {
      state = state.copyWith(
        busy: false,
        error: e.message,
        errorCategory: AttendanceErrorCategory.locationPermanentlyDenied,
        step: AttendanceFlowStep.failed,
      );
      return null;
    } on PoorLocationAccuracyException catch (e) {
      state = state.copyWith(
        busy: false,
        error: e.toString(),
        errorCategory: AttendanceErrorCategory.poorAccuracy,
        step: AttendanceFlowStep.failed,
      );
      return null;
    } catch (e) {
      state = state.copyWith(
        busy: false,
        error: e.toString(),
        errorCategory: AttendanceErrorCategory.unknown,
        step: AttendanceFlowStep.failed,
      );
      return null;
    }
  }

  /// Dual capture: captures selfie and geo sequentially.
  Future<bool> captureDualEvidence() async {
    final selfie = await captureSelfie();
    if (selfie == null) return false;
    final geo = await captureGeo();
    return geo != null;
  }

  /// Submit from the interactive review state.
  Future<SessionStatus?> submitReviewedEvidence() async {
    if (state.busy) {
      // Duplicate action protection
      return null;
    }
    if (!state.isEvidenceComplete) {
      state = state.copyWith(
        error: 'Both selfie and location fix are mandatory.',
        errorCategory: AttendanceErrorCategory.evidenceIncomplete,
        step: AttendanceFlowStep.failed,
      );
      return null;
    }

    if (state.op == AttendanceOpKind.checkIn) {
      final studentId = state.studentId;
      final date = state.date ?? DateTime.now();
      if (studentId == null) {
        state = state.copyWith(
          error: 'No active student identified.',
          errorCategory: AttendanceErrorCategory.unknown,
          step: AttendanceFlowStep.failed,
        );
        return null;
      }
      return _boot(() async {
        final requestId = newOperationId(DateTime.now().toUtc());
        final init = await _gateway.checkIn(
          requestId: requestId,
          date: date,
          geo: state.geo!,
        );
        await _evidence.upload(
          storagePath: init.uploadTarget,
          selfie: state.selfie!,
        );
        final result = await _gateway.confirmCheckIn(
          requestId: init.requestId,
          sessionId: init.sessionId,
          uploadPath: init.uploadTarget,
          geo: state.geo!,
        );
        return result.status;
      });
    } else {
      final sessionId = state.sessionId;
      if (sessionId == null || sessionId.isEmpty) {
        state = state.copyWith(
          error: 'No active session found to check out.',
          errorCategory: AttendanceErrorCategory.unknown,
          step: AttendanceFlowStep.failed,
        );
        return null;
      }
      return _boot(() async {
        final requestId = newOperationId(DateTime.now().toUtc());
        final init = await _gateway.checkOut(
          requestId: requestId,
          sessionId: sessionId,
          geo: state.geo!,
        );
        await _evidence.upload(
          storagePath: init.uploadTarget,
          selfie: state.selfie!,
        );
        final result = await _gateway.confirmCheckOut(
          requestId: init.requestId,
          sessionId: init.sessionId,
          uploadPath: init.uploadTarget,
          geo: state.geo!,
        );
        return result.status;
      });
    }
  }

  /// Runs the one-shot check-in sequence (used by tests & fast path).
  Future<SessionStatus?> runCheckIn({
    required String studentId,
    required DateTime date,
  }) {
    if (state.busy) return Future.value(null);
    return _boot(() async {
      final bundle = await _evidence.capture();
      final requestId = newOperationId(DateTime.now().toUtc());
      final init = await _gateway.checkIn(
        requestId: requestId,
        date: date,
        geo: bundle.geo,
      );
      await _evidence.upload(
        storagePath: init.uploadTarget,
        selfie: bundle.selfie,
      );
      final result = await _gateway.confirmCheckIn(
        requestId: init.requestId,
        sessionId: init.sessionId,
        uploadPath: init.uploadTarget,
        geo: bundle.geo,
      );
      return result.status;
    });
  }

  /// Runs the one-shot check-out sequence (used by tests & fast path).
  Future<SessionStatus?> runCheckOut({required String sessionId}) {
    if (state.busy) return Future.value(null);
    return _boot(() async {
      final bundle = await _evidence.capture();
      final requestId = newOperationId(DateTime.now().toUtc());
      final init = await _gateway.checkOut(
        requestId: requestId,
        sessionId: sessionId,
        geo: bundle.geo,
      );
      await _evidence.upload(
        storagePath: init.uploadTarget,
        selfie: bundle.selfie,
      );
      final result = await _gateway.confirmCheckOut(
        requestId: init.requestId,
        sessionId: init.sessionId,
        uploadPath: init.uploadTarget,
        geo: bundle.geo,
      );
      return result.status;
    });
  }

  void reset() {
    state = const AttendanceFlowUi();
  }

  Future<SessionStatus?> _boot(Future<SessionStatus?> Function() action) async {
    state = state.copyWith(busy: true, step: AttendanceFlowStep.submitting);
    SessionStatus? outcome;
    String? error;
    var errorCat = AttendanceErrorCategory.none;

    try {
      outcome = await action();
    } on MissingEvidenceException catch (e) {
      error = e.message;
      errorCat = AttendanceErrorCategory.evidenceIncomplete;
    } on CameraPermissionDeniedException catch (e) {
      error = e.message;
      errorCat = AttendanceErrorCategory.cameraPermissionDenied;
    } on LocationPermissionDeniedException catch (e) {
      error = e.message;
      errorCat = AttendanceErrorCategory.locationPermissionDenied;
    } on PoorLocationAccuracyException catch (e) {
      error = e.toString();
      errorCat = AttendanceErrorCategory.poorAccuracy;
    } on AttendanceFlowException catch (e) {
      error = e.toString();
      errorCat = e.kind == AttendanceFlowErrorKind.stateConflict
          ? AttendanceErrorCategory.stateConflict
          : AttendanceErrorCategory.gatewayFailure;
    } catch (e) {
      error = e.toString();
      errorCat = AttendanceErrorCategory.unknown;
    }

    state = state.copyWith(
      busy: false,
      error: error ?? '',
      errorCategory: errorCat,
      step: outcome != null ? AttendanceFlowStep.completed : AttendanceFlowStep.failed,
      done: outcome == null ? '' : 'Server confirmed: ${outcome.label}',
      confirmedStatus: outcome,
    );
    return outcome;
  }
}

/// Bound to the student's attendance gateway + evidence capture.
/// Backed by local in-memory abstractions when in local dev mode,
/// and cloud gateway when AppFlavor.useFirebase is true.
final attendanceFlowControllerProvider =
    StateNotifierProvider<AttendanceFlowController, AttendanceFlowUi>((ref) {
  final gateway = ref.watch(attendanceGatewayProvider);
  final uploader = AppFlavor.useFirebase
      ? StorageEvidenceUploader(host: AppFlavor.emulatorHost)
      : const LocalEvidenceUploader();

  const selfieCapturer = ImagePickerSelfieCapturer();
  const geoSampler = GeolocatorSampler();

  final evidenceService = EvidenceService(
    selfieCapturer: selfieCapturer,
    geoSampler: geoSampler,
    uploader: uploader,
  );

  return AttendanceFlowController(
    gateway: gateway,
    evidenceService: evidenceService,
    selfieCapturer: selfieCapturer,
    geoSampler: geoSampler,
  );
});