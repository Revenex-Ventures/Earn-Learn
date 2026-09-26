// ignore_for_file: prefer_initializing_formals

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'evidence_types.dart';

/// Captures the mandatory identity selfie for a check-in/check-out.
abstract class SelfieCapturer {
  Future<SelfieCapture?> capture();
  Future<SelfieCapture?> retrieveLostData();
}

class ImagePickerSelfieCapturer implements SelfieCapturer {
  const ImagePickerSelfieCapturer({ImagePicker? picker}) : _picker = picker;

  final ImagePicker? _picker;

  @override
  Future<SelfieCapture?> capture() async {
    final picker = _picker ?? ImagePicker();
    try {
      final file = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        requestFullMetadata: false,
        imageQuality: 70,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      return SelfieCapture(
        bytes: bytes,
        mimeType: 'image/jpeg',
        sizeBytes: bytes.length,
        capturedAt: DateTime.now().toUtc(),
        localPath: file.path,
      );
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied' || e.code == 'permission_denied') {
        throw CameraPermissionDeniedException(e.message ?? 'Camera permission was denied.');
      } else if (e.code == 'camera_access_restricted') {
        throw CameraPermanentlyDeniedException(e.message ?? 'Camera permission is permanently denied.');
      } else if (e.code == 'no_available_camera') {
        throw CameraUnavailableException(e.message ?? 'No camera hardware found on this device.');
      }
      rethrow;
    }
  }

  @override
  Future<SelfieCapture?> retrieveLostData() async {
    final picker = _picker ?? ImagePicker();
    try {
      final response = await picker.retrieveLostData();
      if (response.isEmpty || response.file == null) return null;
      final file = response.file!;
      final bytes = await file.readAsBytes();
      return SelfieCapture(
        bytes: bytes,
        mimeType: 'image/jpeg',
        sizeBytes: bytes.length,
        capturedAt: DateTime.now().toUtc(),
        localPath: file.path,
      );
    } catch (_) {
      return null;
    }
  }
}