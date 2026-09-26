// ignore_for_file: prefer_initializing_formals

import 'evidence_geo.dart';
import 'evidence_types.dart';
import 'evidence_uploader.dart';
import 'geolocation.dart';
import 'selfie_capture.dart';

/// Everything the server needs to verify a single check-in/check-out.
class EvidenceBundle {
  const EvidenceBundle({required this.selfie, required this.geo});

  final SelfieCapture selfie;
  final EvidenceGeo geo;
}

/// Orchestrates mandatory evidence capture (selfie + GPS) in one call.
///
/// Both pieces are ALWAYS required. When either is unavailable the caller
/// receives [MissingEvidenceException] and the session stays resumable —
/// nothing reaches the server.
class EvidenceService {
  const EvidenceService({
    required SelfieCapturer selfieCapturer,
    required GeoSampler geoSampler,
    required EvidenceUploader uploader,
  })  : _selfieCapturer = selfieCapturer,
        _geoSampler = geoSampler,
        _uploader = uploader;

  final SelfieCapturer _selfieCapturer;
  final GeoSampler _geoSampler;
  final EvidenceUploader _uploader;

  Future<EvidenceBundle> capture() async {
    final selfie = await _selfieCapturer.capture();
    final geo = await _geoSampler.sample();
    final missing = <String>[
      if (selfie == null) 'selfie',
      if (geo == null) 'GPS fix',
    ];
    if (missing.isNotEmpty) throw MissingEvidenceException(missing);
    return EvidenceBundle(selfie: selfie!, geo: geo!);
  }

  Future<void> upload({
    required String storagePath,
    required SelfieCapture selfie,
  }) =>
      _uploader.upload(storagePath: storagePath, selfie: selfie);
}