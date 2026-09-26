import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/models/models.dart';
import '../../../domain/identity/face_embedding_match.dart';

/// Extracts a face embedding from a captured photograph.
///
/// This is the seam that keeps WI-6 buildable today. The production
/// implementation needs a real face-detection model (MobileFaceNet, 112x112,
/// 128-d), which is **not** in this repository and cannot be synthesised. So the
/// interface is defined, the decision logic is implemented and tested for real,
/// and the detector behind it reports its own absence instead of the app
/// quietly pretending a check happened.
abstract class FaceEmbeddingExtractor {
  /// Whether a detector is actually available on this build.
  bool get isAvailable;

  /// Loads any model this extractor needs. Safe to call more than once.
  Future<void> initialize();

  /// Produces a face embedding, or the reason one could not be produced.
  ///
  /// Throws [FaceModelUnavailableException] if [isAvailable] is false - a
  /// caller must never be handed a fabricated embedding to compare against.
  Future<FaceEmbeddingOutcome> extract(Uint8List imageBytes);
}

/// A face embedding, or the reason none could be produced.
sealed class FaceEmbeddingOutcome {
  const FaceEmbeddingOutcome();

  /// A usable embedding.
  const factory FaceEmbeddingOutcome.found(FaceEmbedding embedding) =
      _Found;

  /// No usable face. [reason] distinguishes the operator-facing situations.
  const factory FaceEmbeddingOutcome.unusable(FaceVerifyFailure reason) =
      _Unusable;
}

class _Found extends FaceEmbeddingOutcome {
  const _Found(this.embedding);
  final FaceEmbedding embedding;
}

class _Unusable extends FaceEmbeddingOutcome {
  const _Unusable(this.reason);
  final FaceVerifyFailure reason;
}

/// Thrown when no face model is present, so verification cannot be performed.
///
/// The UI contract for this is "Configuration required" - never a pass and
/// never a fail. Silently skipping the check would let attendance be marked
/// with an unverified identity while looking exactly like a verified one.
class FaceModelUnavailableException implements Exception {
  const FaceModelUnavailableException([
    this.message =
        'Face model is not bundled in this build. Same-person verification is unavailable.',
  ]);
  final String message;
  @override
  String toString() => message;
}

/// The default extractor, which has no model to load.
///
/// Registered as the implementation for now precisely because it is honest
/// about doing nothing. Swapping in a real detector is a one-line provider
/// override; no call site changes, and no caller can mistake absence for a
/// match.
class UnavailableFaceEmbeddingExtractor implements FaceEmbeddingExtractor {
  const UnavailableFaceEmbeddingExtractor();

  @override
  bool get isAvailable => false;

  @override
  Future<void> initialize() async {}

  @override
  Future<FaceEmbeddingOutcome> extract(Uint8List imageBytes) async {
    throw const FaceModelUnavailableException();
  }
}

/// Stores a student's enrolled face embedding on the device only.
///
/// The embedding is biometric data, so it goes to the platform keystore-backed
/// store rather than to shared preferences, and it is keyed by student id.
/// Nothing here writes to Firestore, and no embedding leaves the device - the
/// server is not part of this decision path.
class FaceEnrollmentStore {
  FaceEnrollmentStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  static const String _keyPrefix = 'face_enrollment_v1_';

  final FlutterSecureStorage _storage;

  String _keyFor(String studentId) => '$_keyPrefix$studentId';

  /// Reads the enrolment for [studentId], or null when none is stored.
  Future<FaceEmbedding?> read(String studentId) async {
    final raw = await _storage.read(key: _keyFor(studentId));
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    final vector = decoded.map((e) => (e as num).toDouble()).toList();
    if (vector.length != kFaceEmbeddingLength) {
      // A stored vector of the wrong shape cannot be compared meaningfully.
      // Treat it as absent rather than throwing at comparison time.
      debugPrint(
        'Stored face enrolment for $studentId has ${vector.length} dims, '
        'expected $kFaceEmbeddingLength. Ignoring it.',
      );
      return null;
    }
    return FaceEmbedding.fromVector(vector);
  }

  /// Saves [embedding] as the enrolment for [studentId], replacing any prior one.
  Future<void> write(String studentId, FaceEmbedding embedding) {
    return _storage.write(
      key: _keyFor(studentId),
      value: jsonEncode(embedding.unit),
    );
  }

  /// Removes the enrolment for [studentId]. The consent-withdrawal path.
  Future<void> delete(String studentId) => _storage.delete(key: _keyFor(studentId));
}

/// Runs a live capture against the stored enrolment for a student.
///
/// Assembles extractor + enrolment store + the pure decision function. All the
/// actual judgement lives in [evaluateFaceMatch]; this only orchestrates I/O.
class FaceVerificationService {
  const FaceVerificationService({
    required this.extractor,
    required this.enrollmentStore,
  });

  /// The detector backing this service.
  final FaceEmbeddingExtractor extractor;

  /// Where the enrolled face profile for a student is kept.
  final FaceEnrollmentStore enrollmentStore;

  /// Whether verification can run at all on this build.
  bool get isAvailable => extractor.isAvailable;

  /// Compares a capture against [student]'s enrolment.
  ///
  /// Throws [FaceModelUnavailableException] when no detector is bundled, so the
  /// caller must handle "cannot check" as its own state.
  Future<FaceVerifyResult> verify({
    required Student student,
    required Uint8List imageBytes,
  }) async {
    await extractor.initialize();

    final outcome = await extractor.extract(imageBytes);
    return switch (outcome) {
      _Unusable(:final reason) => FaceVerifyResult.unusable(reason),
      _Found(:final embedding) => evaluateFaceMatch(
          enrolment: await enrollmentStore.read(student.id),
          capture: embedding,
        ),
    };
  }

  /// Enrols [student] from a known-good capture.
  Future<void> enroll({
    required Student student,
    required Uint8List imageBytes,
  }) async {
    await extractor.initialize();
    final outcome = await extractor.extract(imageBytes);
    if (outcome case _Unusable(:final reason)) {
      throw StateError('Cannot enrol from this photo ($reason).');
    }
    if (outcome case _Found(:final embedding)) {
      await enrollmentStore.write(student.id, embedding);
    }
  }

  /// Whether [student] has an enrolment on this device.
  Future<bool> isEnrolled(String studentId) async =>
      await enrollmentStore.read(studentId) != null;

  /// Deletes the enrolment for [studentId].
  Future<void> withdrawConsent(String studentId) =>
      enrollmentStore.delete(studentId);
}

/// Human-readable text for a verification outcome, for operator-facing UI.
///
/// Kept next to the orchestration so a new outcome cannot be added to the
/// domain without someone deciding what the student is told.
extension FaceVerifyResultMessage on FaceVerifyResult {
  String get message {
    if (isMatched) {
      return 'Face matches enrolled profile '
          '(${(similarity!).toStringAsFixed(2)}).';
    }
    if (needsSupervisorReview) {
      return 'Face does not match enrolled profile '
          '(${(similarity!).toStringAsFixed(2)}). This check-in was sent to '
          'your supervisor for review.';
    }
    if (similarity == null && failure == null) {
      return 'No face profile is enrolled yet, so this check-in was not '
          'face-verified.';
    }
    return switch (failure!) {
      FaceVerifyFailure.noFace =>
        'No face was detected. Retake the photo facing the camera.',
      FaceVerifyFailure.multipleFace =>
        'More than one face was detected. Retake the photo with only yourself '
            'in frame.',
      FaceVerifyFailure.lowQuality =>
        'The photo was too blurry. Retake it in better light, facing the camera.',
    };
  }
}
