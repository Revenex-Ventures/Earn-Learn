import '../../core/models/models.dart';
import 'session.dart';
import 'session_status.dart';

/// Thrown when a transition is not allowed from the current state.
class InvalidTransitionException implements Exception {
  const InvalidTransitionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Guard table: from-state → permitted next states.
const Map<SessionStatus, Set<SessionStatus>> _allowedEdges = {
  SessionStatus.scheduled: {
    SessionStatus.checkInPending,
    SessionStatus.missed,
    SessionStatus.cancelled,
  },
  SessionStatus.checkInPending: {
    SessionStatus.working,
    SessionStatus.missed,
    SessionStatus.cancelled,
  },
  SessionStatus.working: {
    SessionStatus.checkOutPending,
    SessionStatus.submitted,
    SessionStatus.missed,
  },
  SessionStatus.checkOutPending: {
    SessionStatus.submitted,
  },
  SessionStatus.submitted: {
    SessionStatus.underReview,
    SessionStatus.flagged,
  },
  SessionStatus.underReview: {
    SessionStatus.approved,
    SessionStatus.flagged,
    SessionStatus.rejected,
    SessionStatus.correctionRequested,
  },
  SessionStatus.flagged: {
    SessionStatus.approved,
    SessionStatus.rejected,
    SessionStatus.correctionRequested,
  },
  SessionStatus.correctionRequested: {
    SessionStatus.submitted,
  },
  SessionStatus.approved: {},
  SessionStatus.rejected: {},
  SessionStatus.missed: {},
  SessionStatus.cancelled: {},
  SessionStatus.closed: {},
};

/// Transition rules for the session state machine.
///
/// Every method is a pure guard that returns the next [Session] or throws
/// [InvalidTransitionException]. Server timestamps are supplied by callers —
/// the machine never mints them.
class SessionStateMachine {
  const SessionStateMachine();

  /// Public view of the guard table (used by tests and the audit tooling).
  static const Map<SessionStatus, Set<SessionStatus>> allowedEdges =
      _allowedEdges;

  Session _go(
    Session s,
    SessionStatus next, {
    String? reason,
    DateTime? now,
  }) {
    final allowed = _allowedEdges[s.status] ?? const <SessionStatus>{};
    if (!allowed.contains(next)) {
      throw InvalidTransitionException(
        'Session ${s.id} cannot move ${s.status.label} → ${next.label}.',
      );
    }
    return s.copyWith(
      status: next,
      reason: reason ?? s.reason,
      updatedAt: now ?? DateTime.now(),
    );
  }

  /// Student requests check-in (client-supplied timestamp).
  Session requestCheckIn(Session s, {required DateTime requestedAt}) {
    return _go(s, SessionStatus.checkInPending).copyWith(
      checkInRequestedAt: requestedAt,
    );
  }

  /// Supervisor/server verifies check-in. Failed verification leaves the
  /// session pending.
  Session completeCheckIn(
    Session s, {
    required DateTime verifiedAt,
    required bool evidenceOk,
  }) {
    if (!evidenceOk) {
      throw const InvalidTransitionException(
        'Check-in verification failed; session stays pending.',
      );
    }
    return _go(s, SessionStatus.working).copyWith(
      checkInVerifiedAt: verifiedAt,
    );
  }

  Session requestCheckOut(Session s, {required DateTime requestedAt}) {
    return _go(s, SessionStatus.checkOutPending).copyWith(
      checkOutRequestedAt: requestedAt,
    );
  }

  Session completeCheckOut(
    Session s, {
    required DateTime verifiedAt,
    required bool evidenceOk,
  }) {
    if (!evidenceOk) {
      throw const InvalidTransitionException(
        'Check-out verification failed; session stays pending.',
      );
    }
    return _go(s, SessionStatus.submitted).copyWith(
      checkOutVerifiedAt: verifiedAt,
    );
  }

  /// Monthly sweep: a working session past its last window end is finalised
  /// with the window end as the authoritative check-out.
  Session autoFinalizeMissedCheckOut(
    Session s, {
    required DateTime windowEnd,
  }) {
    return _go(s, SessionStatus.submitted).copyWith(
      checkOutVerifiedAt: windowEnd,
      reason: 'Check-out auto-finalized at window end (no user action).',
    );
  }

  Session startReview(Session s) => _go(s, SessionStatus.underReview);

  Session approve(Session s) =>
      _go(s, SessionStatus.approved).copyWith(review: ApprovalStatus.approved);

  Session flag(Session s, {required String reason, DateTime? now}) =>
      _go(s, SessionStatus.flagged, reason: reason, now: now)
          .copyWith(review: ApprovalStatus.flagged);

  Session reject(Session s, {required String reason, DateTime? now}) =>
      _go(s, SessionStatus.rejected, reason: reason, now: now)
          .copyWith(review: ApprovalStatus.rejected);

  Session requestCorrection(
    Session s, {
    required String reason,
    DateTime? now,
  }) =>
      _go(s, SessionStatus.correctionRequested, reason: reason, now: now)
          .copyWith(review: ApprovalStatus.flagged);

  Session submitCorrection(Session s) =>
      _go(s, SessionStatus.submitted).copyWith(review: ApprovalStatus.pending);

  Session markMissed(
    Session s, {
    String reason = 'Shift went unattended.',
    DateTime? now,
  }) =>
      _go(s, SessionStatus.missed, reason: reason, now: now);

  Session cancel(
    Session s, {
    String reason = 'Session cancelled.',
    DateTime? now,
  }) =>
      _go(s, SessionStatus.cancelled, reason: reason, now: now);

  Session close(
    Session s, {
    DateTime? now,
  }) =>
      _go(s, SessionStatus.closed, now: now);
}