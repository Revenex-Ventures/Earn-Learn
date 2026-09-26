import 'dart:math';
import 'dart:typed_data' show Uint8List;

import 'package:firebase_storage/firebase_storage.dart';

import '../../data/app_flavor.dart';
import 'evidence_types.dart';

/// Uploads evidence to Storage. Objects are immutable by rules; the only
/// path a student may write is `evidence/{uid}/...`.
abstract class EvidenceUploader {
  Future<void> upload({
    required String storagePath,
    required SelfieCapture selfie,
  });
}

class StorageEvidenceUploader implements EvidenceUploader {
  StorageEvidenceUploader({FirebaseStorage? storage, String? host, int? port})
      : _storage = storage ?? FirebaseStorage.instance {
    if (host != null) {
      _storage.useStorageEmulator(host, port ?? AppFlavor.storagePort);
    }
  }

  final FirebaseStorage _storage;

  @override
  Future<void> upload({
    required String storagePath,
    required SelfieCapture selfie,
  }) async {
    final ref = _storage.ref(storagePath);
    final bytes = Uint8List.fromList(selfie.bytes);
    await ref.putData(bytes,
        SettableMetadata(contentType: selfie.mimeType, cacheControl: 'private'));
  }
}

/// In-memory uploader for local dev & testing without cloud dependencies.
class LocalEvidenceUploader implements EvidenceUploader {
  const LocalEvidenceUploader();

  @override
  Future<void> upload({
    required String storagePath,
    required SelfieCapture selfie,
  }) async {
    // In local mode, upload is simulated in memory.
  }
}

/// Thrown when either mandatory evidence piece is unavailable; the session
/// stays in `scheduled`/`working` and the flow is resumable.
class MissingEvidenceException implements Exception {
  const MissingEvidenceException(this.missing);

  final List<String> missing;

  String get message => 'Missing mandatory evidence: ${missing.join(', ')}.';

  @override
  String toString() => message;
}

/// Idempotency key generator (short, orderable, collision-safe enough for a
/// single device).
String newOperationId(DateTime now) {
  final random = Random();
  final suffix =
      List.generate(4, (_) => random.nextInt(16).toRadixString(16)).join();
  return '${now.microsecondsSinceEpoch}_$suffix';
}