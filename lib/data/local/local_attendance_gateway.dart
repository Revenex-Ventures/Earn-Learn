import '../../core/evidence/evidence_geo.dart';
import '../../core/models/models.dart';
import '../../domain/attendance/session.dart';
import '../../domain/attendance/session_state_machine.dart';
import '../../domain/attendance/session_status.dart';
import '../../shared/mock_data/mock_data.dart';
import '../dev_only.dart';
import '../firebase/attendance_gateway.dart';
import 'local_attendance_repository.dart';
import 'local_review_store.dart';

/// Local in-memory [AttendanceGateway] that enforces the [SessionStateMachine]
/// and updates the [LocalAttendanceRepository] for live student interaction.
@DevOnly('Local/mock gateway for development and UI simulation without Firebase.')
class LocalAttendanceGateway implements AttendanceGateway {
  LocalAttendanceGateway({
    required LocalAttendanceRepository attendanceRepository,
    SessionStateMachine? stateMachine,
  })  : _repo = attendanceRepository,
        _machine = stateMachine ?? const SessionStateMachine(),
        _sessions = <String, Session>{};

  final LocalAttendanceRepository _repo;
  final SessionStateMachine _machine;
  final Map<String, Session> _sessions;

  @override
  Future<CheckInInit> checkIn({
    required String requestId,
    required DateTime date,
    required EvidenceGeo geo,
  }) async {
    final now = DateTime.now();
    final dateOnly = DateTime(date.year, date.month, date.day);
    final sessionId = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final existing = _sessions[sessionId] ??
        Session(
          id: sessionId,
          studentId: mockCurrentStudent.id,
          date: dateOnly,
          windows: mockCurrentAssignment.shiftWindows,
          status: SessionStatus.scheduled,
        );

    final updated = _machine.requestCheckIn(existing, requestedAt: now);
    _sessions[sessionId] = updated;

    return CheckInInit(
      sessionId: sessionId,
      requestId: requestId,
      uploadTarget: 'evidence/${mockCurrentStudent.id}/$sessionId/${requestId}_checkin.jpg',
    );
  }

  @override
  Future<CheckInConfirmResult> confirmCheckIn({
    required String requestId,
    required String sessionId,
    required String uploadPath,
    required EvidenceGeo geo,
  }) async {
    final session = _sessions[sessionId];
    if (session == null) {
      throw const AttendanceFlowException(
        AttendanceFlowErrorKind.notFound,
        'Session not found.',
      );
    }

    final now = DateTime.now();
    final verified = _machine.completeCheckIn(
      session,
      verifiedAt: now,
      evidenceOk: true,
    );

    _sessions[sessionId] = verified;
    _repo.submitSession(verified);

    return CheckInConfirmResult(
      status: verified.status,
      checkInVerifiedAt: verified.checkInVerifiedAt,
      geoVerified: true,
    );
  }

  @override
  Future<CheckOutInit> checkOut({
    required String requestId,
    required String sessionId,
    required EvidenceGeo geo,
  }) async {
    final existing = _sessions[sessionId] ??
        Session(
          id: sessionId,
          studentId: mockCurrentStudent.id,
          date: DateTime.now(),
          windows: mockCurrentAssignment.shiftWindows,
          status: SessionStatus.working,
          checkInVerifiedAt: DateTime.now().subtract(const Duration(hours: 2)),
        );

    final now = DateTime.now();
    final updated = _machine.requestCheckOut(existing, requestedAt: now);
    _sessions[sessionId] = updated;

    return CheckOutInit(
      sessionId: sessionId,
      requestId: requestId,
      uploadTarget: 'evidence/${mockCurrentStudent.id}/$sessionId/${requestId}_checkout.jpg',
    );
  }

  @override
  Future<CheckOutConfirmResult> confirmCheckOut({
    required String requestId,
    required String sessionId,
    required String uploadPath,
    required EvidenceGeo geo,
  }) async {
    final session = _sessions[sessionId];
    if (session == null) {
      throw const AttendanceFlowException(
        AttendanceFlowErrorKind.notFound,
        'Session not found.',
      );
    }

    final now = DateTime.now();
    final checkIn = session.checkInVerifiedAt ?? now.subtract(const Duration(hours: 2));
    final verifiedHours = (now.difference(checkIn).inMinutes / 60.0).clamp(0.0, 8.0);

    final completed = _machine.completeCheckOut(
      session,
      verifiedAt: now,
      evidenceOk: true,
    ).copyWith(
      verifiedHours: double.parse(verifiedHours.toStringAsFixed(1)),
      review: ApprovalStatus.pending,
    );

    _sessions[sessionId] = completed;
    _repo.submitSession(completed);

    return CheckOutConfirmResult(
      status: completed.status,
      verifiedHours: completed.verifiedHours,
      capacityWarning: false,
    );
  }

  @override
  Future<ReviewResult> review({
    required String sessionId,
    required String studentId,
    required ApprovalStatus decision,
    String? note,
  }) async {
    // Tolerate queue items that were never checked in during this run — the
    // local queue is served from fixtures, so synthesise a submitted session
    // and let the state machine guard every transition from there.
    final base = _sessions[sessionId] ??
        Session(
          id: sessionId,
          studentId: studentId,
          date: DateTime.now(),
          windows: const <ShiftWindow>[],
          status: SessionStatus.submitted,
        );

    // Approve/reject are only legal from underReview or flagged; move a freshly
    // submitted item into review first so the machine accepts the decision.
    final ready = base.status == SessionStatus.submitted &&
            decision != ApprovalStatus.flagged
        ? _machine.startReview(base)
        : base;

    final updated = switch (decision) {
      ApprovalStatus.approved =>
        base.status == SessionStatus.approved ? base : _machine.approve(ready),
      ApprovalStatus.rejected => base.status == SessionStatus.rejected
          ? base
          : _machine.reject(ready, reason: note ?? 'Rejected by supervisor.'),
      ApprovalStatus.flagged => base.status == SessionStatus.flagged
          ? base
          : _machine.flag(base, reason: note ?? 'Flagged by supervisor.'),
      _ => base,
    };

    _sessions[sessionId] = updated;
    _repo.submitSession(updated);
    LocalReviewStore.instance.record(sessionId, updated.review, note: note);

    return ReviewResult(
      status: updated.status,
      review: updated.review,
      note: note,
    );
  }

  @override
  Future<List<VerificationItem>> myQueue() async => const [];

  @override
  Future<String> evidenceUrl({
    required String sessionId,
    required String studentId,
    required String kind,
  }) async =>
      'local://evidence/$studentId/$sessionId/$kind.jpg';
}
