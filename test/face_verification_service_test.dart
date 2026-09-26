import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/domain/identity/face_embedding_match.dart';
import 'package:earn_and_learn/features/attendance/face/face_verification_service.dart';

/// In-memory stand-in for the platform keystore, so enrollment behaviour can be
/// asserted without a device.
class _MemorySecureStore implements FaceEnrollmentStore {
  final Map<String, FaceEmbedding> _store = {};
  bool allowRead = true;

  @override
  Future<FaceEmbedding?> read(String studentId) async {
    if (!allowRead) throw StateError('keystore unavailable');
    return _store[studentId];
  }

  @override
  Future<void> write(String studentId, FaceEmbedding embedding) async {
    _store[studentId] = embedding;
  }

  @override
  Future<void> delete(String studentId) async {
    _store.remove(studentId);
  }

  Future<bool> isEnrolled(String studentId) async => _store.containsKey(studentId);

  Future<void> withdrawConsent(String studentId) => delete(studentId);
}

class _FakeExtractor implements FaceEmbeddingExtractor {
  _FakeExtractor(this.outcome);

  final FaceEmbeddingOutcome? outcome;
  bool available = true;
  int initCalls = 0;
  Uint8List? lastImage;

  @override
  bool get isAvailable => available;

  @override
  Future<void> initialize() async => initCalls++;

  @override
  Future<FaceEmbeddingOutcome> extract(Uint8List imageBytes) async {
    lastImage = imageBytes;
    final outcome = this.outcome;
    if (outcome == null) throw const FaceModelUnavailableException();
    return outcome;
  }
}

List<double> _unit(double degrees) {
  final rad = degrees * 3.141592653589793 / 180.0;
  final v = List<double>.filled(kFaceEmbeddingLength, 0.0);
  v[0] = rad == 0 ? 1.0 : _cos(rad);
  v[1] = rad == 0 ? 0.0 : _sin(rad);
  return v;
}

double _cos(double x) => _series(x, true);
double _sin(double x) => _series(x, false);

double _series(double x, bool isCos) {
  var term = 1.0;
  var sum = 1.0;
  for (var n = 1; n <= 12; n++) {
    term *= -x * x / ((2 * n - 1) * (2 * n));
    sum += term;
    if (isCos && term.abs() < 1e-16) break;
  }
  return sum;
}

const Student _student = Student(
  id: 'STU-001',
  name: 'Prasanna Auti',
  rollNumber: 'EL2627-052',
  status: AccountStatus.active,
);

void main() {
  final image = Uint8List.fromList([1, 2, 3, 4]);

  group('FaceVerificationService', () {
    test('an enrolled student matching the capture is accepted', () async {
      final store = _MemorySecureStore();
      await store.write('STU-001', FaceEmbedding.fromVector(_unit(0)));

      final service = FaceVerificationService(
        extractor: _FakeExtractor(
          FaceEmbeddingOutcome.found(
            FaceEmbedding.fromVector(_unit(0)),
          ),
        ),
        enrollmentStore: store,
      );

      final result = await service.verify(student: _student, imageBytes: image);

      expect(result.isMatched, isTrue);
      expect(result.needsSupervisorReview, isFalse);
    });

    test('a different person is a mismatch and asks for review', () async {
      final store = _MemorySecureStore();
      await store.write('STU-001', FaceEmbedding.fromVector(_unit(0)));

      final service = FaceVerificationService(
        extractor: _FakeExtractor(
          FaceEmbeddingOutcome.found(
            FaceEmbedding.fromVector(_unit(120)),
          ),
        ),
        enrollmentStore: store,
      );

      final result = await service.verify(student: _student, imageBytes: image);

      expect(result.needsSupervisorReview, isTrue);
      expect(result.message, contains('supervisor'));
    });

    test('a student with no enrolment is not escalated', () async {
      final service = FaceVerificationService(
        extractor: _FakeExtractor(
          FaceEmbeddingOutcome.found(
            FaceEmbedding.fromVector(_unit(120)),
          ),
        ),
        enrollmentStore: _MemorySecureStore(),
      );

      final result = await service.verify(student: _student, imageBytes: image);

      expect(result.needsSupervisorReview, isFalse);
      expect(result.message, contains('not face-verified'));
    });

    test('each unusable outcome keeps its own reason', () async {
      for (final reason in FaceVerifyFailure.values) {
        final service = FaceVerificationService(
          extractor: _FakeExtractor(FaceEmbeddingOutcome.unusable(reason)),
          enrollmentStore: _MemorySecureStore(),
        );

        final result =
            await service.verify(student: _student, imageBytes: image);

        expect(result.needsSupervisorReview, isFalse, reason: '$reason');
        expect(result.message, isNotEmpty);
      }
    });

    test('a model that refuses to load surfaces as unavailable, not a pass',
        () async {
      final service = FaceVerificationService(
        extractor: _FakeExtractor(null),
        enrollmentStore: _MemorySecureStore(),
      );

      expect(
        () => service.verify(student: _student, imageBytes: image),
        throwsA(isA<FaceModelUnavailableException>()),
      );
      expect(service.isAvailable, isTrue);
    });

    test('the bundled default reports itself unavailable', () {
      const extractor = UnavailableFaceEmbeddingExtractor();

      expect(extractor.isAvailable, isFalse);
      expect(
        () => extractor.extract(image),
        throwsA(isA<FaceModelUnavailableException>()),
      );
    });

    test('the unavailable message says configuration is required', () {
      const exception = FaceModelUnavailableException();

      expect(exception.toString(), contains('not bundled'));
      expect(exception.toString(), contains('unavailable'));
    });
  });

  group('enrolment lifecycle', () {
    test('enrol then verify matches', () async {
      final store = _MemorySecureStore();
      final extractor = _FakeExtractor(
        FaceEmbeddingOutcome.found(
          FaceEmbedding.fromVector(_unit(15)),
        ),
      );
      final service = FaceVerificationService(
        extractor: extractor,
        enrollmentStore: store,
      );

      expect(await service.isEnrolled(_student.id), isFalse);
      await service.enroll(student: _student, imageBytes: image);
      expect(await service.isEnrolled(_student.id), isTrue);

      final result = await service.verify(student: _student, imageBytes: image);
      expect(result.isMatched, isTrue);
    });

    test('withdrawing consent removes the enrolment', () async {
      final store = _MemorySecureStore();
      final service = FaceVerificationService(
        extractor: _FakeExtractor(
          FaceEmbeddingOutcome.found(
            FaceEmbedding.fromVector(_unit(0)),
          ),
        ),
        enrollmentStore: store,
      );

      await service.enroll(student: _student, imageBytes: image);
      await service.withdrawConsent(_student.id);

      expect(await service.isEnrolled(_student.id), isFalse);
    });

    test('enrolling from an unusable photo is refused', () async {
      final service = FaceVerificationService(
        extractor: _FakeExtractor(
          const FaceEmbeddingOutcome.unusable(FaceVerifyFailure.multipleFace),
        ),
        enrollmentStore: _MemorySecureStore(),
      );

      expect(
        () => service.enroll(student: _student, imageBytes: image),
        throwsA(isA<StateError>()),
      );
    });

    test('a different student has a separate enrolment', () async {
      final store = _MemorySecureStore();
      final service = FaceVerificationService(
        extractor: _FakeExtractor(
          FaceEmbeddingOutcome.found(
            FaceEmbedding.fromVector(_unit(0)),
          ),
        ),
        enrollmentStore: store,
      );

      await service.enroll(student: _student, imageBytes: image);

      expect(await service.isEnrolled('STU-002'), isFalse);
    });
  });

  group('FaceVerifyResultMessage', () {
    test('every outcome has distinct, actionable wording', () {
      const results = [
        FaceVerifyResult.matched(similarity: 0.91),
        FaceVerifyResult.mismatch(similarity: 0.22),
        FaceVerifyResult.notEnrolled(),
        FaceVerifyResult.unusable(FaceVerifyFailure.noFace),
        FaceVerifyResult.unusable(FaceVerifyFailure.multipleFace),
        FaceVerifyResult.unusable(FaceVerifyFailure.lowQuality),
      ];

      final messages = results.map((r) => r.message).toList();
      expect(messages.toSet().length, results.length);
      for (final message in messages) {
        expect(message.trim(), isNotEmpty);
      }
    });

    test('a matched result reports the similarity it measured', () {
      const result = FaceVerifyResult.matched(similarity: 0.8734);
      expect(result.message, contains('0.87'));
    });
  });
}
