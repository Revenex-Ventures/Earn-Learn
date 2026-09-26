import 'dart:math' as math;

/// Cosine-similarity cut-off for accepting a live capture as the same person.
///
/// 0.65 is the operating point agreed for MobileFaceNet 128-d L2-normalized
/// embeddings and is deliberately a *match threshold*, not a similarity to
/// optimise. It is a value, not a fact: it needs recalibration against real
/// enrolment/attempt pairs from the actual student population and camera
/// hardware before it can be trusted as a gate. Until then a failure is routed
/// to human review rather than treated as proof either way.
const double kFaceMatchThreshold = 0.65;

/// Number of floats a MobileFaceNet embedding carries.
const int kFaceEmbeddingLength = 128;

/// Side length, in pixels, of the face crop handed to the model.
const int kFaceInputSize = 112;

/// Why a face check could not produce a comparison.
///
/// Each of these is a distinct operator-facing situation: a blurry photo and a
/// photo of two people call for completely different advice to the student.
enum FaceVerifyFailure {
  /// No face was detected in the capture.
  noFace,

  /// More than one face was detected - an attendance photo of a group is
  /// unusable, and guessing which face to enrol would be worse than refusing.
  multipleFace,

  /// A face was found but the image quality is below what the model can
  /// compare reliably (blur, small face, heavy shadow).
  lowQuality,
}

/// An L2-normalized face embedding.
///
/// Final, and constructible only through [FaceEmbedding.fromVector], so a
/// caller can never build one that was never normalised - which would silently
/// corrupt every comparison made with it.
final class FaceEmbedding {
  const FaceEmbedding._(this._unit);

  /// Wraps raw model output, normalising it so cosine similarity is a plain
  /// dot product.
  factory FaceEmbedding.fromVector(List<double> vector) {
    if (vector.length != kFaceEmbeddingLength) {
      throw ArgumentError.value(
        vector.length,
        'vector.length',
        'Expected $kFaceEmbeddingLength dimensions',
      );
    }
    final norm = _magnitude(vector);
    if (norm == 0) {
      throw ArgumentError.value(
        'zero vector',
        'vector',
        'A face embedding cannot be the zero vector',
      );
    }
    return FaceEmbedding._([for (final v in vector) v / norm]);
  }

  final List<double> _unit;

  /// The unit-length embedding. Callers must not mutate the returned list.
  List<double> get unit => List.unmodifiable(_unit);

  /// Cosine similarity against another embedding, in `[-1, 1]`.
  ///
  /// Both sides are already unit-length, so this is a dot product.
  double similarityTo(FaceEmbedding other) {
    var sum = 0.0;
    for (var i = 0; i < _unit.length; i++) {
      sum += _unit[i] * other._unit[i];
    }
    return sum.clamp(-1.0, 1.0);
  }
}

/// The outcome of comparing a live capture against a stored enrolment.
///
/// Mirrors the agreed six outcomes, and adds the case that the student has no
/// enrolment on record. `notEnrolled` is deliberately *not* a failure: there is
/// nothing to compare against, which is a different problem from a comparison
/// that came back low.
sealed class FaceVerifyResult {
  const FaceVerifyResult();

  /// The capture is the enrolled person.
  const factory FaceVerifyResult.matched({required double similarity}) =
      _Matched;

  /// The capture is not the enrolled person, at a similarity below threshold.
  const factory FaceVerifyResult.mismatch({
    required double similarity,
  }) = _Mismatch;

  /// The student has no enrolment on record, so no comparison was possible.
  const factory FaceVerifyResult.notEnrolled() = _NotEnrolled;

  /// No usable face was obtained; see [FaceVerifyFailure].
  const factory FaceVerifyResult.unusable(FaceVerifyFailure reason) = _Unusable;

  bool get isMatched => this is _Matched;

  /// Cosine similarity, when a comparison was actually made.
  ///
  /// Null for [FaceVerifyResult.notEnrolled] and for unusable captures, because
  /// there is no number to report in those cases. Exposed so callers can render
  /// an outcome without matching on private subtypes.
  double? get similarity => switch (this) {
        _Matched(:final similarity) => similarity,
        _Mismatch(:final similarity) => similarity,
        _NotEnrolled() || _Unusable() => null,
      };

  /// Why the capture was unusable, when it was.
  FaceVerifyFailure? get failure => switch (this) {
        _Unusable(:final reason) => reason,
        _Matched() || _Mismatch() || _NotEnrolled() => null,
      };

  /// Whether the attempt should be escalated to a supervisor.
  ///
  /// Only a positive mismatch does. "Could not check" and "not enrolled" are
  /// the student's problem to fix on the spot, not a supervisor's, and must not
  /// consume review capacity.
  bool get needsSupervisorReview => this is _Mismatch;
}

class _Matched extends FaceVerifyResult {
  const _Matched({required this.similarity});
  @override
  final double similarity;
  @override
  String toString() => 'FaceVerifyResult.matched(${similarity.toStringAsFixed(3)})';
}

class _Mismatch extends FaceVerifyResult {
  const _Mismatch({required this.similarity});
  @override
  final double similarity;
  @override
  String toString() =>
      'FaceVerifyResult.mismatch(${similarity.toStringAsFixed(3)})';
}

class _NotEnrolled extends FaceVerifyResult {
  const _NotEnrolled();
  @override
  String toString() => 'FaceVerifyResult.notEnrolled()';
}

class _Unusable extends FaceVerifyResult {
  const _Unusable(this.reason);
  final FaceVerifyFailure reason;
  @override
  String toString() => 'FaceVerifyResult.unusable($reason)';
}

/// Compares a freshly captured embedding against the stored enrolment.
///
/// Pure and dependency-free so the decision can be tested exhaustively without
/// a camera, a model file, or a device - which matters, because this is the
/// one piece of WI-6 that must be right.
FaceVerifyResult evaluateFaceMatch({
  required FaceEmbedding? enrolment,
  required FaceEmbedding capture,
  double threshold = kFaceMatchThreshold,
}) {
  if (enrolment == null) return const FaceVerifyResult.notEnrolled();

  final similarity = capture.similarityTo(enrolment);
  if (similarity >= threshold) {
    return FaceVerifyResult.matched(similarity: similarity);
  }
  return FaceVerifyResult.mismatch(similarity: similarity);
}

double _magnitude(List<double> vector) {
  var sum = 0.0;
  for (final value in vector) {
    sum += value * value;
  }
  return math.sqrt(sum);
}
