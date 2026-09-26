import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/evidence/evidence_geo.dart';
import 'package:earn_and_learn/core/evidence/evidence_service.dart';
import 'package:earn_and_learn/core/evidence/evidence_types.dart';
import 'package:earn_and_learn/core/evidence/evidence_uploader.dart';
import 'package:earn_and_learn/core/evidence/geolocation.dart';
import 'package:earn_and_learn/core/evidence/selfie_capture.dart';
import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/data/firebase/attendance_gateway.dart';
import 'package:earn_and_learn/domain/attendance/session_status.dart';
import 'package:earn_and_learn/features/student/check_in_controller.dart';

EvidenceGeo _geo() => EvidenceGeo(
      latitude: 19.5,
      longitude: 74.25,
      accuracyMeters: 12,
      capturedAt: DateTime.utc(2026, 9, 19, 10, 0, 0),
    );

void main() {
  group('EvidenceService', () {
    test('combines selfie + GPS into one bundle', () async {
      final service = EvidenceService(
        selfieCapturer: _Selfie(_bytes()),
        geoSampler: _Geo(_geo()),
        uploader: _Uploader(),
      );
      final bundle = await service.capture();
      expect(bundle.selfie.mimeType, 'image/jpeg');
      expect(bundle.geo.latitude, 19.5);
    });

    test('throws MissingEvidenceException when any piece is missing', () async {
      final service = EvidenceService(
        selfieCapturer: _Selfie(null),
        geoSampler: _Geo(_geo()),
        uploader: _Uploader(),
      );
      await expectLater(
        service.capture(),
        throwsA(isA<MissingEvidenceException>()),
      );
    });

    test('upload delegates to the uploader path + selfie', () async {
      final uploader = _Uploader();
      final service = EvidenceService(
        selfieCapturer: _Selfie(_bytes()),
        geoSampler: _Geo(_geo()),
        uploader: uploader,
      );
      await service.upload(storagePath: 'evidence/me/x/d.jpg', selfie: _bytes());
      expect(uploader.path, 'evidence/me/x/d.jpg');
    });
  });

  group('AttendanceFlowController', () {
    test('successful check-in returns the server status', () async {
      final gateway = _FlowGateway()..allow = true;
      final controller = AttendanceFlowController(
        gateway: gateway,
        evidenceService: EvidenceService(
          selfieCapturer: _Selfie(_bytes()),
          geoSampler: _Geo(_geo()),
          uploader: _Uploader(),
        ),
      );
      final status = await controller.runCheckIn(
        studentId: 'STU-9001',
        date: DateTime(2026, 9, 19),
      );
      expect(status, SessionStatus.working);
      expect(controller.state.busy, isFalse);
      expect(controller.state.error, isEmpty);
      expect(controller.state.done, contains('Working'));
      expect(gateway.confirmedPath, contains('evidence/'));

      final init = gateway.lastCheckIn!;
      expect(gateway.confirmedPath, init.uploadTarget);
      expect(gateway.sentGeo?.latitude, 19.5);
    });

    test('missing evidence never reaches the gateway and is resumable',
        () async {
      final gateway = _FlowGateway()..allow = true;
      final controller = AttendanceFlowController(
        gateway: gateway,
        evidenceService: EvidenceService(
          selfieCapturer: _Selfie(null),
          geoSampler: _Geo(_geo()),
          uploader: _Uploader(),
        ),
      );
      final status = await controller.runCheckIn(
        studentId: 'STU-9001',
        date: DateTime(2026, 9, 19),
      );
      expect(status, isNull);
      expect(gateway.calls, 0);
      expect(controller.state.error, contains('selfie'));
    });

    test('a gateway failure is surfaced without throwing', () async {
      final gateway = _FlowGateway()
        ..allow = false
        ..failureKind = AttendanceFlowErrorKind.unlinked;
      final controller = AttendanceFlowController(
        gateway: gateway,
        evidenceService: EvidenceService(
          selfieCapturer: _Selfie(_bytes()),
          geoSampler: _Geo(_geo()),
          uploader: _Uploader(),
        ),
      );
      final status = await controller.runCheckOut(sessionId: '2026-09-19');
      expect(status, isNull);
      expect(controller.state.error, contains('unlinked'));
    });

    test('check-out flow pushes work order check-in → out', () async {
      final gateway = _FlowGateway()..allow = true;
      final controller = AttendanceFlowController(
        gateway: gateway,
        evidenceService: EvidenceService(
          selfieCapturer: _Selfie(_bytes()),
          geoSampler: _Geo(_geo()),
          uploader: _Uploader(),
        ),
      );
      final status = await controller.runCheckOut(sessionId: '2026-09-19');
      expect(status, SessionStatus.submitted);
      expect(gateway.lastOut?.sessionId, '2026-09-19');
    });
  });
}

SelfieCapture _bytes() =>
    SelfieCapture(bytes: const [1, 2, 3], mimeType: 'image/jpeg');

class _Selfie implements SelfieCapturer {
  _Selfie(this.result);

  final SelfieCapture? result;

  @override
  Future<SelfieCapture?> capture() async => result;

  @override
  Future<SelfieCapture?> retrieveLostData() async => null;
}

class _Geo implements GeoSampler {
  _Geo(this.result);

  final EvidenceGeo? result;

  @override
  Future<EvidenceGeo?> sample() async => result;
}

class _Uploader implements EvidenceUploader {
  String? path;

  @override
  Future<void> upload({
    required String storagePath,
    required SelfieCapture selfie,
  }) async {
    path = storagePath;
  }
}

class _FlowGateway implements AttendanceGateway {
  bool allow = true;
  AttendanceFlowErrorKind failureKind = AttendanceFlowErrorKind.unknown;
  int calls = 0;
  String? uploadedPath;
  String? confirmedPath;
  CheckInInit? lastCheckIn;
  CheckOutInit? lastOut;
  EvidenceGeo? sentGeo;

  @override
  Future<CheckInInit> checkIn({
    required String requestId,
    required DateTime date,
    required EvidenceGeo geo,
  }) async {
    calls++;
    sentGeo = geo;
    final init = CheckInInit(
      sessionId: '${date.year}-${date.month}-${date.day}',
      requestId: requestId,
      uploadTarget: 'evidence/me/${date.month}${date.day}/${requestId}_checkin.jpg',
    );
    lastCheckIn = init;
    return init;
  }

  @override
  Future<CheckInConfirmResult> confirmCheckIn({
    required String requestId,
    required String sessionId,
    required String uploadPath,
    required EvidenceGeo geo,
  }) async {
    calls++;
    if (!allow) throw AttendanceFlowException(failureKind);
    confirmedPath = uploadPath;
    return const CheckInConfirmResult(status: SessionStatus.working, geoVerified: true);
  }

  @override
  Future<CheckOutInit> checkOut({
    required String requestId,
    required String sessionId,
    required EvidenceGeo geo,
  }) async {
    calls++;
    lastOut = CheckOutInit(
      sessionId: sessionId,
      requestId: requestId,
      uploadTarget: 'evidence/me/co/${requestId}_checkout.jpg',
    );
    return lastOut!;
  }

  @override
  Future<CheckOutConfirmResult> confirmCheckOut({
    required String requestId,
    required String sessionId,
    required String uploadPath,
    required EvidenceGeo geo,
  }) async {
    calls++;
    if (!allow) throw AttendanceFlowException(failureKind);
    uploadedPath = uploadPath;
    return const CheckOutConfirmResult(
      status: SessionStatus.submitted,
      verifiedHours: 2.0,
      capacityWarning: false,
    );
  }

  @override
  Future<ReviewResult> review({
    required String sessionId,
    required String studentId,
    required ApprovalStatus decision,
    String? note,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<VerificationItem>> myQueue() => throw UnimplementedError();

  @override
  Future<String> evidenceUrl({
    required String sessionId,
    required String studentId,
    required String kind,
  }) {
    throw UnimplementedError();
  }
}