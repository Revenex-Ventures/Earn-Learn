import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/domain/domain.dart';
import 'package:earn_and_learn/features/demo/demo_scenario_screen.dart';
import 'package:earn_and_learn/features/demo/demo_scenario_state.dart';

void main() {
  group('Demo Scenario Notifier State Machine', () {
    test('initializes in profileSetup stage with fresh demo fixtures', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(demoScenarioProvider);

      expect(state.stage, DemoStage.profileSetup);
      expect(state.student.id, 'DEMO-STU-001');
      expect(state.supervisor.id, 'DEMO-SV-001');
      expect(state.location.id, 'DEMO-LOC-001');
      expect(state.assignment.id, 'DEMO-ASN-001');
      expect(state.session, isNull);
      expect(state.auditLogs, isNotEmpty);
      expect(state.isDemo, isTrue);
    });

    test('completes full multi-role journey from onboarding to admin audit', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(demoScenarioProvider.notifier);

      // 1. Save Profile
      notifier.saveStudentProfile(
        name: 'Jane Doe',
        rollNumber: '22CS100',
        department: 'Computer Engineering',
        className: 'TE-B',
        contact: '+91 91234 56789',
        college: 'Amrutvahini College of Engineering',
      );

      var state = container.read(demoScenarioProvider);
      expect(state.stage, DemoStage.countdownToShift);
      expect(state.student.name, 'Jane Doe');
      expect(state.student.rollNumber, '22CS100');
      expect(state.auditLogs.last.action, 'PROFILE_SAVED');

      // 2. Fast forward countdown to ready
      notifier.skipToShiftReady();
      state = container.read(demoScenarioProvider);
      expect(state.stage, DemoStage.shiftReady);
      expect(state.isShiftReady, isTrue);

      // 3. Start Verification
      notifier.startVerification();
      state = container.read(demoScenarioProvider);
      expect(state.stage, DemoStage.verifyingRequirements);
      expect(state.locationVerified, isFalse);
      expect(state.identityVerified, isFalse);

      // Verify location & identity
      notifier.setLocationVerified(true);
      notifier.setIdentityVerified(true);
      state = container.read(demoScenarioProvider);
      expect(state.locationVerified, isTrue);
      expect(state.identityVerified, isTrue);

      // 4. Start Shift
      notifier.startShift();
      state = container.read(demoScenarioProvider);
      expect(state.stage, DemoStage.shiftActive);
      expect(state.session, isNotNull);
      expect(state.session!.status, SessionStatus.working);
      expect(state.locationSamplesCount, 1);

      // Record additional location sample
      notifier.recordSample();
      state = container.read(demoScenarioProvider);
      expect(state.locationSamplesCount, 2);

      // 5. Checkout & End Shift
      notifier.endShift();
      state = container.read(demoScenarioProvider);
      expect(state.stage, DemoStage.supervisorReview);
      expect(state.session!.status, SessionStatus.submitted);
      expect(state.session!.review, ApprovalStatus.pending);

      // 6. Supervisor Review -> Approve
      notifier.supervisorReview(
        reviewStatus: ApprovalStatus.approved,
        supervisorName: 'Demo Supervisor',
        reason: 'All requirements verified successfully',
      );

      state = container.read(demoScenarioProvider);
      expect(state.stage, DemoStage.adminAudit);
      expect(state.session!.status, SessionStatus.approved);
      expect(state.session!.review, ApprovalStatus.approved);
      expect(state.auditLogs.last.action, 'ATTENDANCE_APPROVED');

      // 7. Admin Manual Correction
      notifier.adminCorrection(
        newVerifiedHours: 4.0,
        adminName: 'Super Admin',
        reason: 'Adjustment for library extension duties',
      );

      state = container.read(demoScenarioProvider);
      expect(state.session!.verifiedHours, 4.0);
      expect(state.auditLogs.last.action, 'MANUAL_HOURS_CORRECTION');

      // 8. Reset Demo Scenario
      notifier.resetScenario();
      state = container.read(demoScenarioProvider);
      expect(state.stage, DemoStage.profileSetup);
      expect(state.student.name, 'Demo Student');
      expect(state.session, isNull);
    });
  });

  group('DemoScenarioScreen Widget rendering', () {
    testWidgets('renders all stages cleanly without overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DemoScenarioScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Live End-to-End Demo'), findsOneWidget);
      expect(find.text('Stage 1: Student Profile Onboarding'), findsOneWidget);
      expect(find.text('Save Profile & View Assignment'), findsOneWidget);

      // Tap Save Profile
      await tester.tap(find.text('Save Profile & View Assignment'));
      await tester.pumpAndSettle();

      expect(find.text('Stage 2: Shift Assignment & Countdown'), findsOneWidget);
      expect(find.text('Skip Countdown to Ready'), findsOneWidget);

      // Tap Skip Countdown
      await tester.tap(find.text('Skip Countdown to Ready'));
      await tester.pumpAndSettle();

      expect(find.text('Start Shift (Location & Identity Check)'), findsOneWidget);

      // Tap Start Shift
      await tester.tap(find.text('Start Shift (Location & Identity Check)'));
      await tester.pumpAndSettle();

      expect(find.text('Stage 3: Pre-Shift Verification'), findsOneWidget);
      expect(find.text('Verify Location'), findsOneWidget);
      expect(find.text('Capture Selfie'), findsOneWidget);

      // Verify Location and Selfie
      await tester.tap(find.text('Verify Location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Capture Selfie'));
      await tester.pumpAndSettle();

      expect(find.text('Complete Check-In & Enter Duty'), findsOneWidget);

      // Enter Duty
      await tester.tap(find.text('Complete Check-In & Enter Duty'));
      await tester.pumpAndSettle();

      expect(find.text('Stage 4: Active Shift in Progress'), findsOneWidget);
      expect(find.text('WORKING'), findsOneWidget);
      expect(find.text('End Shift & Submit for Review'), findsOneWidget);

      // Tap End Shift
      await tester.tap(find.text('End Shift & Submit for Review'));
      await tester.pumpAndSettle();

      // Confirm dialog
      expect(find.text('End your shift?'), findsOneWidget);
      await tester.tap(find.text('Confirm End Shift'));
      await tester.pumpAndSettle();

      // Supervisor Review Stage
      expect(find.text('Stage 5: Supervisor Review Portal'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Flag'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);

      // Tap Approve
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      // Admin Audit Stage
      expect(find.text('Stage 6: Super Admin Oversight'), findsOneWidget);
      expect(find.text('Chronological Audit Trail (Server Authoritative):'), findsOneWidget);
      expect(find.text('Manual Correction'), findsOneWidget);
    });
  });
}
