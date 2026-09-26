import 'package:flutter_test/flutter_test.dart';

import 'package:earn_and_learn/core/models/models.dart';
import 'package:earn_and_learn/domain/domain.dart';

void main() {
  const machine = SessionStateMachine();
  final now = DateTime(2026, 6, 1, 17, 30);

  Session session({
    SessionStatus status = SessionStatus.scheduled,
    ApprovalStatus review = ApprovalStatus.pending,
    DateTime? checkInVerifiedAt,
    DateTime? checkOutVerifiedAt,
  }) {
    return Session(
      id: 'SE-1',
      studentId: 'STU-S1',
      date: DateTime(2026, 6, 1),
      windows: const [
        ShiftWindow(start: Duration(hours: 17), end: Duration(hours: 20)),
      ],
      status: status,
      review: review,
      checkInVerifiedAt: checkInVerifiedAt,
      checkOutVerifiedAt: checkOutVerifiedAt,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('happy path', () {
    test('scheduled → check-in → working → check-out → review → approved', () {
      var s = session();
      s = machine.requestCheckIn(s, requestedAt: now);
      expect(s.status, SessionStatus.checkInPending);
      expect(s.checkInRequestedAt, now);

      s = machine.completeCheckIn(s, verifiedAt: now.add(const Duration(minutes: 2)), evidenceOk: true);
      expect(s.status, SessionStatus.working);
      expect(s.checkInVerifiedAt, isNotNull);

      s = machine.requestCheckOut(s, requestedAt: now.add(const Duration(hours: 2)));
      expect(s.status, SessionStatus.checkOutPending);

      s = machine.completeCheckOut(
        s,
        verifiedAt: now.add(const Duration(hours: 2, minutes: 1)),
        evidenceOk: true,
      );
      expect(s.status, SessionStatus.submitted);
      expect(s.checkOutVerifiedAt, isNotNull);

      s = machine.startReview(s);
      expect(s.status, SessionStatus.underReview);

      s = machine.approve(s);
      expect(s.status, SessionStatus.approved);
      expect(s.review, ApprovalStatus.approved);
    });
  });

  group('guards', () {
    test('rejects a transition from an illegal source state', () {
      expect(
        () => machine.approve(session()),
        throwsA(isA<InvalidTransitionException>()),
      );
      expect(
        () => machine.reject(session(status: SessionStatus.scheduled), reason: 'x'),
        throwsA(isA<InvalidTransitionException>()),
      );
    });

    test('keeps the session pending when check-in evidence fails', () {
      var s = machine.requestCheckIn(session(), requestedAt: now);
      expect(
        () => machine.completeCheckIn(
          s,
          verifiedAt: now,
          evidenceOk: false,
        ),
        throwsA(isA<InvalidTransitionException>()),
      );
      expect(s.status, SessionStatus.checkInPending);
    });

    test('sets critical-column review on flag / reject / correction', () {
      var s = machine.submitCorrection(
        machine.requestCorrection(session(status: SessionStatus.underReview), reason: 'Wrong clock'),
      );
      expect(s.status, SessionStatus.submitted);
      expect(s.review, ApprovalStatus.pending);

      s = machine.startReview(s);
      final flagged = machine.flag(s, reason: 'Timestamp discrepancy');
      expect(flagged.status, SessionStatus.flagged);
      expect(flagged.review, ApprovalStatus.flagged);
      expect(flagged.reason, contains('discrepancy'));

      final rejected = machine.reject(flagged, reason: 'Evidence missing');
      expect(rejected.status, SessionStatus.rejected);
      expect(rejected.review, ApprovalStatus.rejected);
    });
  });

  group('terminal states', () {
    test('missed and cancelled are one-way', () {
      final missed = machine.markMissed(session());
      expect(missed.status, SessionStatus.missed);
      expect(missed.status.isTerminal, isTrue);

      final cancelled = machine.cancel(session(status: SessionStatus.checkInPending));
      expect(cancelled.status, SessionStatus.cancelled);
      expect(() => machine.approve(cancelled), throwsA(isA<InvalidTransitionException>()));
    });

    test('auto-finalises a missed check-out at the window end', () {
      final submitted = machine.autoFinalizeMissedCheckOut(
        session(status: SessionStatus.working, checkInVerifiedAt: now),
        windowEnd: DateTime(2026, 6, 1, 20, 0),
      );
      expect(submitted.status, SessionStatus.submitted);
      expect(submitted.checkOutVerifiedAt, DateTime(2026, 6, 1, 20, 0));
      expect(submitted.reason, contains('auto-finalized'));
    });
  });

  test('exposes the transition guard table', () {
    expect(
      SessionStateMachine.allowedEdges[SessionStatus.working],
      containsAll(<SessionStatus>{
        SessionStatus.checkOutPending,
        SessionStatus.missed,
      }),
    );
  });
}