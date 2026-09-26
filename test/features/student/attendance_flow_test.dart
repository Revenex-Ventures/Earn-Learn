import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/evidence/evidence_geo.dart';
import 'package:earn_and_learn/core/evidence/evidence_service.dart';
import 'package:earn_and_learn/core/evidence/evidence_types.dart';
import 'package:earn_and_learn/core/evidence/evidence_uploader.dart';
import 'package:earn_and_learn/core/evidence/geolocation.dart';
import 'package:earn_and_learn/core/evidence/selfie_capture.dart';
import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/data/firebase/attendance_gateway.dart';
import 'package:earn_and_learn/domain/attendance/session.dart';
import 'package:earn_and_learn/domain/attendance/session_state_machine.dart';
import 'package:earn_and_learn/domain/attendance/session_status.dart';
import 'package:earn_and_learn/features/student/attendance_flow_sheet.dart';
import 'package:earn_and_learn/features/student/attendance_screen.dart';
import 'package:earn_and_learn/features/student/check_in_controller.dart';
import 'package:earn_and_learn/shared/components/today_panel.dart';

EvidenceGeo _mockGeo({double accuracy = 12.0}) => EvidenceGeo(
      latitude: 19.6178,
      longitude: 74.6599,
      accuracyMeters: accuracy,
      capturedAt: DateTime.utc(2026, 9, 19, 17, 0, 0),
    );

const _mockPngBytes = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
];

SelfieCapture _mockSelfie() => SelfieCapture(
      bytes: _mockPngBytes,
      mimeType: 'image/png',
      sizeBytes: 1024,
      capturedAt: DateTime.utc(2026, 9, 19, 17, 0, 0),
      localPath: '/tmp/selfie.png',
    );

class _MockSelfieCapturer implements SelfieCapturer {
  _MockSelfieCapturer({this.result, this.lostResult, this.exception});
  final SelfieCapture? result;
  final SelfieCapture? lostResult;
  final Exception? exception;

  @override
  Future<SelfieCapture?> capture() async {
    if (exception != null) throw exception!;
    return result;
  }

  @override
  Future<SelfieCapture?> retrieveLostData() async {
    return lostResult;
  }
}

class _MockGeoSampler implements GeoSampler {
  _MockGeoSampler({this.result, this.exception});
  final EvidenceGeo? result;
  final Exception? exception;

  @override
  Future<EvidenceGeo?> sample() async {
    if (exception != null) throw exception!;
    return result;
  }
}

class _MockGateway implements AttendanceGateway {
  bool allow = true;
  int checkInCalls = 0;
  int checkOutCalls = 0;
  AttendanceFlowErrorKind failureKind = AttendanceFlowErrorKind.unknown;

  @override
  Future<CheckInInit> checkIn({
    required String requestId,
    required DateTime date,
    required EvidenceGeo geo,
  }) async {
    checkInCalls++;
    return CheckInInit(
      sessionId: '2026-09-19',
      requestId: requestId,
      uploadTarget: 'evidence/STU-001/2026-09-19/checkin.jpg',
    );
  }

  @override
  Future<CheckInConfirmResult> confirmCheckIn({
    required String requestId,
    required String sessionId,
    required String uploadPath,
    required EvidenceGeo geo,
  }) async {
    checkInCalls++;
    if (!allow) throw AttendanceFlowException(failureKind);
    return CheckInConfirmResult(
      status: SessionStatus.working,
      checkInVerifiedAt: DateTime.utc(2026, 9, 19, 17, 2, 0),
      geoVerified: true,
    );
  }

  @override
  Future<CheckOutInit> checkOut({
    required String requestId,
    required String sessionId,
    required EvidenceGeo geo,
  }) async {
    checkOutCalls++;
    return CheckOutInit(
      sessionId: sessionId,
      requestId: requestId,
      uploadTarget: 'evidence/STU-001/$sessionId/checkout.jpg',
    );
  }

  @override
  Future<CheckOutConfirmResult> confirmCheckOut({
    required String requestId,
    required String sessionId,
    required String uploadPath,
    required EvidenceGeo geo,
  }) async {
    checkOutCalls++;
    if (!allow) throw AttendanceFlowException(failureKind);
    return const CheckOutConfirmResult(
      status: SessionStatus.submitted,
      verifiedHours: 3.0,
      capacityWarning: false,
    );
  }

  @override
  Future<ReviewResult> review({
    required String sessionId,
    required String studentId,
    required ApprovalStatus decision,
    String? note,
  }) async =>
      ReviewResult(status: SessionStatus.approved, review: decision, note: note);

  @override
  Future<List<VerificationItem>> myQueue() async => const [];

  @override
  Future<String> evidenceUrl({
    required String sessionId,
    required String studentId,
    required String kind,
  }) async =>
      'local://evidence/$kind.jpg';
}

void main() {
  group('Student Attendance Journey: Unit & State', () {
    const window = ShiftWindow(start: Duration(hours: 17), end: Duration(hours: 20));

    test('Initial Before-Shift State narrates readiness and location', () {
      final now = DateTime(2026, 9, 19, 16, 50);
      final copy = todayPanelCopy(
        state: ShiftState.ready,
        now: now,
        windows: const [window],
        today: null,
      );

      expect(copy.headline, contains('Shift is starting'));
      expect(copy.actionLabel, 'Check in with selfie');
    });

    test('Valid check-in flow with complete evidence updates to working', () async {
      final gateway = _MockGateway()..allow = true;
      final selfieCapturer = _MockSelfieCapturer(result: _mockSelfie());
      final geoSampler = _MockGeoSampler(result: _mockGeo());
      final uploader = const LocalEvidenceUploader();

      final controller = AttendanceFlowController(
        gateway: gateway,
        evidenceService: EvidenceService(
          selfieCapturer: selfieCapturer,
          geoSampler: geoSampler,
          uploader: uploader,
        ),
        selfieCapturer: selfieCapturer,
        geoSampler: geoSampler,
      );

      controller.prepareCheckIn(studentId: 'STU-001', date: DateTime(2026, 9, 19));
      expect(controller.state.step, AttendanceFlowStep.explaining);

      await controller.captureSelfie();
      expect(controller.state.hasSelfie, isTrue);
      expect(controller.state.hasGeo, isFalse);

      await controller.captureGeo();
      expect(controller.state.hasGeo, isTrue);
      expect(controller.state.isEvidenceComplete, isTrue);
      expect(controller.state.step, AttendanceFlowStep.reviewing);

      final result = await controller.submitReviewedEvidence();
      expect(result, SessionStatus.working);
      expect(controller.state.confirmedStatus, SessionStatus.working);
      expect(controller.state.step, AttendanceFlowStep.completed);
      expect(gateway.checkInCalls, 2);
    });

    test('Missing selfie blocks submission and preserves error state', () async {
      final gateway = _MockGateway();
      final selfieCapturer = _MockSelfieCapturer(result: null);
      final geoSampler = _MockGeoSampler(result: _mockGeo());

      final controller = AttendanceFlowController(
        gateway: gateway,
        evidenceService: EvidenceService(
          selfieCapturer: selfieCapturer,
          geoSampler: geoSampler,
          uploader: const LocalEvidenceUploader(),
        ),
        selfieCapturer: selfieCapturer,
        geoSampler: geoSampler,
      );

      controller.prepareCheckIn(studentId: 'STU-001', date: DateTime(2026, 9, 19));
      await controller.captureGeo();
      expect(controller.state.isEvidenceComplete, isFalse);

      final result = await controller.submitReviewedEvidence();
      expect(result, isNull);
      expect(gateway.checkInCalls, 0);
      expect(controller.state.errorCategory, AttendanceErrorCategory.evidenceIncomplete);
    });

    test('Camera permission denied sets clear actionable error', () async {
      final gateway = _MockGateway();
      final selfieCapturer = _MockSelfieCapturer(
        exception: const CameraPermissionDeniedException('Camera permission was denied.'),
      );
      final geoSampler = _MockGeoSampler(result: _mockGeo());

      final controller = AttendanceFlowController(
        gateway: gateway,
        evidenceService: EvidenceService(
          selfieCapturer: selfieCapturer,
          geoSampler: geoSampler,
          uploader: const LocalEvidenceUploader(),
        ),
        selfieCapturer: selfieCapturer,
        geoSampler: geoSampler,
      );

      controller.prepareCheckIn(studentId: 'STU-001', date: DateTime(2026, 9, 19));
      await controller.captureSelfie();

      expect(controller.state.errorCategory, AttendanceErrorCategory.cameraPermissionDenied);
      expect(controller.state.error, contains('denied'));
      expect(controller.state.step, AttendanceFlowStep.failed);
    });

    test('Camera permanently denied sets correct category', () async {
      final gateway = _MockGateway();
      final selfieCapturer = _MockSelfieCapturer(
        exception: const CameraPermanentlyDeniedException('Camera permission is permanently denied.'),
      );

      final controller = AttendanceFlowController(
        gateway: gateway,
        evidenceService: EvidenceService(
          selfieCapturer: selfieCapturer,
          geoSampler: _MockGeoSampler(),
          uploader: const LocalEvidenceUploader(),
        ),
        selfieCapturer: selfieCapturer,
        geoSampler: _MockGeoSampler(),
      );

      controller.prepareCheckIn(studentId: 'STU-001', date: DateTime(2026, 9, 19));
      await controller.captureSelfie();

      expect(controller.state.errorCategory, AttendanceErrorCategory.cameraPermanentlyDenied);
    });

    test('Camera unavailable sets correct category', () async {
      final gateway = _MockGateway();
      final selfieCapturer = _MockSelfieCapturer(
        exception: const CameraUnavailableException('No camera hardware found on this device.'),
      );

      final controller = AttendanceFlowController(
        gateway: gateway,
        evidenceService: EvidenceService(
          selfieCapturer: selfieCapturer,
          geoSampler: _MockGeoSampler(),
          uploader: const LocalEvidenceUploader(),
        ),
        selfieCapturer: selfieCapturer,
        geoSampler: _MockGeoSampler(),
      );

      controller.prepareCheckIn(studentId: 'STU-001', date: DateTime(2026, 9, 19));
      await controller.captureSelfie();

      expect(controller.state.errorCategory, AttendanceErrorCategory.cameraUnavailable);
    });

    test('Location permission denied sets clear actionable error', () async {
      final gateway = _MockGateway();
      final selfieCapturer = _MockSelfieCapturer(result: _mockSelfie());
      final geoSampler = _MockGeoSampler(
        exception: const LocationPermissionDeniedException('Location permission was denied.'),
      );

      final controller = AttendanceFlowController(
        gateway: gateway,
        evidenceService: EvidenceService(
          selfieCapturer: selfieCapturer,
          geoSampler: geoSampler,
          uploader: const LocalEvidenceUploader(),
        ),
        selfieCapturer: selfieCapturer,
        geoSampler: geoSampler,
      );

      controller.prepareCheckIn(studentId: 'STU-001', date: DateTime(2026, 9, 19));
      await controller.captureGeo();

      expect(controller.state.errorCategory, AttendanceErrorCategory.locationPermissionDenied);
      expect(controller.state.error, contains('denied'));
      expect(controller.state.step, AttendanceFlowStep.failed);
    });

    test('Location service disabled sets correct category', () async {
      final gateway = _MockGateway();
      final geoSampler = _MockGeoSampler(
        exception: const LocationServiceDisabledException(),
      );

      final controller = AttendanceFlowController(
        gateway: gateway,
        evidenceService: EvidenceService(
          selfieCapturer: _MockSelfieCapturer(),
          geoSampler: geoSampler,
          uploader: const LocalEvidenceUploader(),
        ),
        selfieCapturer: _MockSelfieCapturer(),
        geoSampler: geoSampler,
      );

      controller.prepareCheckIn(studentId: 'STU-001', date: DateTime(2026, 9, 19));
      await controller.captureGeo();

      expect(controller.state.errorCategory, AttendanceErrorCategory.locationServiceDisabled);
    });

    test('Poor GPS accuracy raises PoorLocationAccuracyException', () async {
      final gateway = _MockGateway();
      final selfieCapturer = _MockSelfieCapturer(result: _mockSelfie());
      final geoSampler = _MockGeoSampler(
        exception: const PoorLocationAccuracyException(accuracyMeters: 250.0, maxAllowedMeters: 100.0),
      );

      final controller = AttendanceFlowController(
        gateway: gateway,
        evidenceService: EvidenceService(
          selfieCapturer: selfieCapturer,
          geoSampler: geoSampler,
          uploader: const LocalEvidenceUploader(),
        ),
        selfieCapturer: selfieCapturer,
        geoSampler: geoSampler,
      );

      controller.prepareCheckIn(studentId: 'STU-001', date: DateTime(2026, 9, 19));
      await controller.captureGeo();

      expect(controller.state.errorCategory, AttendanceErrorCategory.poorAccuracy);
      expect(controller.state.error, contains('accuracy too low'));
    });

    test('Gateway submission failure surfaces failure state', () async {
      final gateway = _MockGateway()
        ..allow = false
        ..failureKind = AttendanceFlowErrorKind.stateConflict;
      final selfieCapturer = _MockSelfieCapturer(result: _mockSelfie());
      final geoSampler = _MockGeoSampler(result: _mockGeo());

      final controller = AttendanceFlowController(
        gateway: gateway,
        evidenceService: EvidenceService(
          selfieCapturer: selfieCapturer,
          geoSampler: geoSampler,
          uploader: const LocalEvidenceUploader(),
        ),
        selfieCapturer: selfieCapturer,
        geoSampler: geoSampler,
      );

      controller.prepareCheckIn(studentId: 'STU-001', date: DateTime(2026, 9, 19));
      await controller.captureDualEvidence();
      final result = await controller.submitReviewedEvidence();

      expect(result, isNull);
      expect(controller.state.step, AttendanceFlowStep.failed);
      expect(controller.state.errorCategory, AttendanceErrorCategory.stateConflict);
    });

    test('Active shift shows elapsed time and remaining window duration', () {
      final now = DateTime(2026, 9, 19, 18, 30);
      final checkIn = DateTime(2026, 9, 19, 17, 0);

      final copy = todayPanelCopy(
        state: ShiftState.working,
        now: now,
        windows: const [window],
        today: AttendanceRecord(
          id: 'ATT-1',
          date: DateTime(2026, 9, 19),
          status: AttendanceStatus.present,
          hours: 3.0,
          checkIn: checkIn,
          location: 'Central Library',
        ),
      );

      expect(copy.headline, contains('Working'));
      expect(copy.subline, contains('Checked in at 5:00 pm'));
      expect(copy.subline, contains('1h 30m remaining'));
      expect(copy.actionLabel, 'Check out');
    });

    test('Valid checkout sequence moves to submitted', () async {
      final gateway = _MockGateway()..allow = true;
      final selfieCapturer = _MockSelfieCapturer(result: _mockSelfie());
      final geoSampler = _MockGeoSampler(result: _mockGeo());

      final controller = AttendanceFlowController(
        gateway: gateway,
        evidenceService: EvidenceService(
          selfieCapturer: selfieCapturer,
          geoSampler: geoSampler,
          uploader: const LocalEvidenceUploader(),
        ),
        selfieCapturer: selfieCapturer,
        geoSampler: geoSampler,
      );

      controller.prepareCheckOut(sessionId: '2026-09-19');
      await controller.captureDualEvidence();
      final status = await controller.submitReviewedEvidence();

      expect(status, SessionStatus.submitted);
      expect(controller.state.confirmedStatus, SessionStatus.submitted);
      expect(gateway.checkOutCalls, 2);
    });

    test('State machine rejects invalid transitions', () {
      const machine = SessionStateMachine();
      final session = Session(
        id: '2026-09-19',
        studentId: 'STU-001',
        date: DateTime(2026, 9, 19),
        windows: const [window],
        status: SessionStatus.approved,
      );

      expect(
        () => machine.requestCheckIn(session, requestedAt: DateTime.now()),
        throwsA(isA<InvalidTransitionException>()),
      );
    });

    test('prepareCheckIn preserves acquired evidence across lifecycle / widget rebuilds', () async {
      final gateway = _MockGateway();
      final selfieCapturer = _MockSelfieCapturer(result: _mockSelfie());
      final geoSampler = _MockGeoSampler(result: _mockGeo());

      final controller = AttendanceFlowController(
        gateway: gateway,
        evidenceService: EvidenceService(
          selfieCapturer: selfieCapturer,
          geoSampler: geoSampler,
          uploader: const LocalEvidenceUploader(),
        ),
        selfieCapturer: selfieCapturer,
        geoSampler: geoSampler,
      );

      final date = DateTime(2026, 9, 19);
      controller.prepareCheckIn(studentId: 'STU-001', date: date);
      await controller.captureSelfie();
      expect(controller.state.hasSelfie, isTrue);

      // Re-invoking prepareCheckIn with same student and date must NOT wipe selfie
      controller.prepareCheckIn(studentId: 'STU-001', date: date);
      expect(controller.state.hasSelfie, isTrue);

      await controller.captureGeo();
      expect(controller.state.isEvidenceComplete, isTrue);

      // Re-invoking prepareCheckIn must still preserve both
      controller.prepareCheckIn(studentId: 'STU-001', date: date);
      expect(controller.state.isEvidenceComplete, isTrue);
      expect(controller.state.step, AttendanceFlowStep.reviewing);
    });

    test('recoverLostSelfie restores photo after Android activity recreation', () async {
      final gateway = _MockGateway();
      final selfieCapturer = _MockSelfieCapturer(
        result: null,
        lostResult: _mockSelfie(),
      );
      final geoSampler = _MockGeoSampler(result: _mockGeo());

      final controller = AttendanceFlowController(
        gateway: gateway,
        evidenceService: EvidenceService(
          selfieCapturer: selfieCapturer,
          geoSampler: geoSampler,
          uploader: const LocalEvidenceUploader(),
        ),
        selfieCapturer: selfieCapturer,
        geoSampler: geoSampler,
      );

      final date = DateTime(2026, 9, 19);
      controller.prepareCheckIn(studentId: 'STU-001', date: date);
      expect(controller.state.hasSelfie, isFalse);

      await controller.recoverLostSelfie();
      expect(controller.state.hasSelfie, isTrue);
      expect(controller.state.step, AttendanceFlowStep.capturing);
    });

    test('Camera cancellation preserves acquired location and does not reset session', () async {
      final gateway = _MockGateway();
      final selfieCapturer = _MockSelfieCapturer(result: null);
      final geoSampler = _MockGeoSampler(result: _mockGeo());

      final controller = AttendanceFlowController(
        gateway: gateway,
        evidenceService: EvidenceService(
          selfieCapturer: selfieCapturer,
          geoSampler: geoSampler,
          uploader: const LocalEvidenceUploader(),
        ),
        selfieCapturer: selfieCapturer,
        geoSampler: geoSampler,
      );

      final date = DateTime(2026, 9, 19);
      controller.prepareCheckIn(studentId: 'STU-001', date: date);
      await controller.captureGeo();
      expect(controller.state.hasGeo, isTrue);

      await controller.captureSelfie();
      expect(controller.state.hasSelfie, isFalse);
      expect(controller.state.hasGeo, isTrue);
      expect(controller.state.error, contains('cancelled'));
    });
  });

  group('Student Attendance Journey: UI Widget Flow', () {
    testWidgets('AttendanceFlowSheet renders requirements, captures evidence, and submits',
        (tester) async {
      final gateway = _MockGateway()..allow = true;
      final selfieCapturer = _MockSelfieCapturer(result: _mockSelfie());
      final geoSampler = _MockGeoSampler(result: _mockGeo());

      final controller = AttendanceFlowController(
        gateway: gateway,
        evidenceService: EvidenceService(
          selfieCapturer: selfieCapturer,
          geoSampler: geoSampler,
          uploader: const LocalEvidenceUploader(),
        ),
        selfieCapturer: selfieCapturer,
        geoSampler: geoSampler,
      );

      SessionStatus? returnedStatus;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attendanceFlowControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    returnedStatus = await AttendanceFlowSheet.show(
                      context: context,
                      locationName: 'Central Library',
                      supervisorName: 'Dr. Prof',
                      windows: const [
                        ShiftWindow(start: Duration(hours: 17), end: Duration(hours: 20)),
                      ],
                      op: AttendanceOpKind.checkIn,
                      studentId: 'STU-001',
                      date: DateTime(2026, 9, 19),
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open bottom sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Duty Check-In'), findsOneWidget);
      expect(find.textContaining('AVCOE policy requires'), findsOneWidget);
      expect(find.text('1. Front-Facing Selfie'), findsOneWidget);
      expect(find.text('2. Campus Location Fix'), findsOneWidget);

      // Capture dual evidence
      await tester.tap(find.text('Capture Both'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Ready for server submission'), findsOneWidget);

      // Submit check-in
      await tester.tap(find.text('Submit Check-In'));
      await tester.pumpAndSettle();

      expect(returnedStatus, SessionStatus.working);
    });

    testWidgets('StudentAttendanceScreen renders register with monthly data', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: StudentAttendanceScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Attendance Register'), findsOneWidget);
      expect(find.text('MONTHLY REGISTER'), findsOneWidget);
      expect(find.text('DAILY FLOW'), findsOneWidget);
      expect(find.text('Assigned Location'), findsOneWidget);
      expect(find.text('Supervisor In-Charge'), findsOneWidget);
    });

    testWidgets('Duty Check-Out retains session and submits existing session', (tester) async {
      final gateway = _MockGateway()..allow = true;
      final selfieCapturer = _MockSelfieCapturer(result: _mockSelfie());
      final geoSampler = _MockGeoSampler(result: _mockGeo());

      final controller = AttendanceFlowController(
        gateway: gateway,
        evidenceService: EvidenceService(
          selfieCapturer: selfieCapturer,
          geoSampler: geoSampler,
          uploader: const LocalEvidenceUploader(),
        ),
        selfieCapturer: selfieCapturer,
        geoSampler: geoSampler,
      );

      SessionStatus? returnedStatus;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            attendanceFlowControllerProvider.overrideWith((ref) => controller),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    returnedStatus = await AttendanceFlowSheet.show(
                      context: context,
                      locationName: 'Central Library',
                      supervisorName: 'Dr. Prof',
                      windows: const [
                        ShiftWindow(start: Duration(hours: 17), end: Duration(hours: 20)),
                      ],
                      op: AttendanceOpKind.checkOut,
                      studentId: 'STU-001',
                      sessionId: '2026-09-19',
                    );
                  },
                  child: const Text('Open Checkout'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Checkout'));
      await tester.pumpAndSettle();

      expect(find.text('Duty Check-Out'), findsOneWidget);
      expect(controller.state.op, AttendanceOpKind.checkOut);
      expect(controller.state.sessionId, '2026-09-19');

      // Capture dual evidence. Scroll it into view first: on a short viewport
      // the sheet content is taller than the visible area, so tapping the
      // button's un-scrolled position would hit the sheet background instead.
      await tester.ensureVisible(find.text('Capture Both'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Capture Both'));
      await tester.pumpAndSettle();

      expect(controller.state.op, AttendanceOpKind.checkOut);
      expect(controller.state.sessionId, '2026-09-19');
      expect(controller.state.isEvidenceComplete, isTrue);

      // Re-invoking prepareCheckOut (simulating rebuild) must NOT wipe evidence or sessionId
      controller.prepareCheckOut(sessionId: '2026-09-19');
      expect(controller.state.op, AttendanceOpKind.checkOut);
      expect(controller.state.sessionId, '2026-09-19');
      expect(controller.state.isEvidenceComplete, isTrue);

      // Submit checkout
      await tester.ensureVisible(find.text('Submit Check-Out'));
      await tester.tap(find.text('Submit Check-Out'));
      await tester.pumpAndSettle();

      expect(returnedStatus, SessionStatus.submitted);
      expect(gateway.checkOutCalls, 2);
    });
  });
}
