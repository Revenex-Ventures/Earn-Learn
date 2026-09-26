import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'face_verification_service.dart';

/// The face embedding detector for this build.
///
/// Defaults to [UnavailableFaceEmbeddingExtractor], which reports that no model
/// is bundled. Registering the real detector is a single `overrideWith` here -
/// no call site has to change, and until it happens every attempt to verify
/// fails loudly with "Configuration required" instead of quietly passing.
final faceEmbeddingExtractorProvider = Provider<FaceEmbeddingExtractor>(
  (ref) => const UnavailableFaceEmbeddingExtractor(),
);

/// Device-local store for enrolled face embeddings.
///
/// Biometric data in the platform keystore, keyed by student id. Nothing is
/// written to Firestore and no embedding leaves the device.
final faceEnrollmentStoreProvider = Provider<FaceEnrollmentStore>(
  (ref) => FaceEnrollmentStore(),
);

/// Same-person face verification.
final faceVerificationServiceProvider = Provider<FaceVerificationService>(
  (ref) => FaceVerificationService(
    extractor: ref.watch(faceEmbeddingExtractorProvider),
    enrollmentStore: ref.watch(faceEnrollmentStoreProvider),
  ),
);

/// Whether face verification can run at all in this build.
///
/// Surfaces in the attendance UI as an honest "Configuration required" note so
/// a student is never left believing an unverified check-in was verified.
final faceVerificationAvailableProvider = Provider<bool>(
  (ref) => ref.watch(faceVerificationServiceProvider).isAvailable,
);
