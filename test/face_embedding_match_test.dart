import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/domain/identity/face_embedding_match.dart';

/// Builds a unit vector at [degrees] from the x-axis in 128 dimensions.
///
/// Real embeddings are not this tidy, but for a cosine test the only property
/// that matters is the angle, and this makes the expected similarity
/// computable by hand instead of asserted by faith.
List<double> unitVectorAt(double degrees) {
  final theta = degrees * math.pi / 180.0;
  // Put the energy in dims 0 and 1 so a small 2-d rotation is exact.
  final v = List<double>.filled(kFaceEmbeddingLength, 0.0);
  v[0] = math.cos(theta);
  v[1] = math.sin(theta);
  return v;
}

void main() {
  group('FaceEmbedding', () {
    test('normalises to unit length', () {
      final embedding = FaceEmbedding.fromVector(List.filled(128, 1.0));

      final norm = math.sqrt(
        embedding.unit.fold<double>(0.0, (s, v) => s + v * v),
      );
      expect(norm, closeTo(1.0, 1e-9));
    });

    test('rejects the wrong dimensionality', () {
      expect(
        () => FaceEmbedding.fromVector(List.filled(64, 0.5)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects the zero vector', () {
      expect(
        () => FaceEmbedding.fromVector(List.filled(128, 0.0)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('the exposed vector cannot be mutated by a caller', () {
      final embedding = FaceEmbedding.fromVector(unitVectorAt(0));
      expect(() => embedding.unit[0] = 42.0, throwsUnsupportedError);
    });

    test('a vector is identical to itself at similarity 1', () {
      final a = FaceEmbedding.fromVector(unitVectorAt(37));
      final b = FaceEmbedding.fromVector(unitVectorAt(37));

      expect(a.similarityTo(b), closeTo(1.0, 1e-9));
    });

    test('similarity tracks the angle between embeddings', () {
      final base = FaceEmbedding.fromVector(unitVectorAt(0));

      expect(base.similarityTo(FaceEmbedding.fromVector(unitVectorAt(0))),
          closeTo(1.0, 1e-9));
      expect(base.similarityTo(FaceEmbedding.fromVector(unitVectorAt(49))),
          closeTo(math.cos(49 * math.pi / 180), 1e-9));
      expect(base.similarityTo(FaceEmbedding.fromVector(unitVectorAt(90))),
          closeTo(0.0, 1e-9));
    });

    test('similarity is symmetric', () {
      final a = FaceEmbedding.fromVector(unitVectorAt(12));
      final b = FaceEmbedding.fromVector(unitVectorAt(55));

      expect(a.similarityTo(b), closeTo(b.similarityTo(a), 1e-12));
    });

    test('scale does not change the comparison', () {
      final unit = unitVectorAt(20);
      final scaled = [for (final v in unit) v * 17.3];

      expect(
        FaceEmbedding.fromVector(unit)
            .similarityTo(FaceEmbedding.fromVector(scaled)),
        closeTo(1.0, 1e-9),
      );
    });
  });

  group('evaluateFaceMatch', () {
    final enrolment = FaceEmbedding.fromVector(unitVectorAt(0));

    test('accepts an identical face', () {
      final result = evaluateFaceMatch(
        enrolment: enrolment,
        capture: FaceEmbedding.fromVector(unitVectorAt(0)),
      );

      expect(result, isA<FaceVerifyResult>());
      expect(result.isMatched, isTrue);
      expect(result.needsSupervisorReview, isFalse);
      expect((result as dynamic).similarity, closeTo(1.0, 1e-9));
    });

    test('rejects a clearly different face and asks for review', () {
      final result = evaluateFaceMatch(
        enrolment: enrolment,
        capture: FaceEmbedding.fromVector(unitVectorAt(120)),
      );

      expect(result.isMatched, isFalse);
      expect(result.needsSupervisorReview, isTrue);
      expect((result as dynamic).similarity, lessThan(kFaceMatchThreshold));
    });

    test('an absent enrolment is not enrolled, not a mismatch', () {
      final result = evaluateFaceMatch(
        enrolment: null,
        capture: FaceEmbedding.fromVector(unitVectorAt(80)),
      );

      // The distinction that matters: this must not consume supervisor review
      // capacity, because there is nothing to review against.
      expect(result.needsSupervisorReview, isFalse);
      expect(result.isMatched, isFalse);
      expect('$result', 'FaceVerifyResult.notEnrolled()');
    });

    test('the threshold is inclusive, not exclusive', () {
      // The exact 0.65 boundary cannot be reproduced bit-for-bit through
      // trig, so feed the measured similarity back in as the threshold. If the
      // comparison were `>` this fails; being `>=` is the intended contract,
      // since a student sitting exactly on the line should not be flagged.
      final capture = FaceEmbedding.fromVector(unitVectorAt(44));
      final exact = enrolment.similarityTo(capture);

      expect(
        evaluateFaceMatch(
          enrolment: enrolment,
          capture: capture,
          threshold: exact,
        ).isMatched,
        isTrue,
      );
      expect(
        evaluateFaceMatch(
          enrolment: enrolment,
          capture: capture,
          threshold: exact + 1e-12,
        ).isMatched,
        isFalse,
      );
    });

    test('a hair under the threshold is a mismatch', () {
      final theta = math.acos(kFaceMatchThreshold) * 180 / math.pi + 0.05;
      final justUnder =
          FaceEmbedding.fromVector(unitVectorAt(theta));

      expect(
        evaluateFaceMatch(enrolment: enrolment, capture: justUnder).isMatched,
        isFalse,
      );
    });

    test('a custom threshold is honoured', () {
      final capture = FaceEmbedding.fromVector(unitVectorAt(50));

      expect(
        evaluateFaceMatch(
          enrolment: enrolment,
          capture: capture,
          threshold: 0.2,
        ).isMatched,
        isTrue,
      );
      expect(
        evaluateFaceMatch(
          enrolment: enrolment,
          capture: capture,
          threshold: 0.99,
        ).isMatched,
        isFalse,
      );
    });
  });

  group('FaceVerifyFailure reasons', () {
    test('only a mismatch escalates to a supervisor', () {
      const unusable = [
        FaceVerifyResult.unusable(FaceVerifyFailure.noFace),
        FaceVerifyResult.unusable(FaceVerifyFailure.multipleFace),
        FaceVerifyResult.unusable(FaceVerifyFailure.lowQuality),
        FaceVerifyResult.notEnrolled(),
        FaceVerifyResult.matched(similarity: 0.99),
      ];

      for (final result in unusable) {
        expect(
          result.needsSupervisorReview,
          isFalse,
          reason: '$result should not escalate',
        );
      }

      expect(
        const FaceVerifyResult.mismatch(similarity: 0.1)
            .needsSupervisorReview,
        isTrue,
      );
    });

    test('each unusable outcome carries its own reason', () {
      for (final reason in FaceVerifyFailure.values) {
        expect('$reason', isNotEmpty);
        expect(
          FaceVerifyResult.unusable(reason).needsSupervisorReview,
          isFalse,
        );
      }
    });
  });

  group('Agreed contract', () {
    test('the operating point is 0.65 on 128-d unit vectors', () {
      // Pinned so a later well-meaning edit cannot quietly loosen the gate.
      expect(kFaceMatchThreshold, 0.65);
      expect(kFaceEmbeddingLength, 128);
      expect(kFaceInputSize, 112);
    });
  });
}
