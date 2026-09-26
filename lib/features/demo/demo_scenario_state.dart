import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../domain/domain.dart';

/// Models a single audit entry within the demo scenario.
class DemoAuditEntry {
  const DemoAuditEntry({
    required this.id,
    required this.timestamp,
    required this.actor,
    required this.actorRole,
    required this.action,
    required this.details,
    this.reason,
  });

  final String id;
  final DateTime timestamp;
  final String actor;
  final String actorRole;
  final String action;
  final String details;
  final String? reason;
}

/// Stage in the end-to-end demo journey.
enum DemoStage {
  profileSetup,
  assignmentPending,
  countdownToShift,
  shiftReady,
  verifyingRequirements,
  shiftActive,
  shiftSubmitted,
  supervisorReview,
  adminAudit,
}

/// State container for the isolated demo scenario.
class DemoScenarioState {
  const DemoScenarioState({
    required this.stage,
    required this.student,
    required this.supervisor,
    required this.location,
    required this.assignment,
    this.session,
    required this.auditLogs,
    required this.shiftStartTime,
    required this.shiftDurationMinutes,
    this.locationVerified = false,
    this.identityVerified = false,
    this.locationSamplesCount = 0,
    this.isDemo = true,
  });

  final DemoStage stage;
  final Student student;
  final Supervisor supervisor;
  final Location location;
  final Assignment assignment;
  final Session? session;
  final List<DemoAuditEntry> auditLogs;
  final DateTime shiftStartTime;
  final int shiftDurationMinutes;
  final bool locationVerified;
  final bool identityVerified;
  final int locationSamplesCount;
  final bool isDemo;

  DemoScenarioState copyWith({
    DemoStage? stage,
    Student? student,
    Supervisor? supervisor,
    Location? location,
    Assignment? assignment,
    Session? session,
    List<DemoAuditEntry>? auditLogs,
    DateTime? shiftStartTime,
    int? shiftDurationMinutes,
    bool? locationVerified,
    bool? identityVerified,
    int? locationSamplesCount,
  }) {
    return DemoScenarioState(
      stage: stage ?? this.stage,
      student: student ?? this.student,
      supervisor: supervisor ?? this.supervisor,
      location: location ?? this.location,
      assignment: assignment ?? this.assignment,
      session: session ?? this.session,
      auditLogs: auditLogs ?? this.auditLogs,
      shiftStartTime: shiftStartTime ?? this.shiftStartTime,
      shiftDurationMinutes: shiftDurationMinutes ?? this.shiftDurationMinutes,
      locationVerified: locationVerified ?? this.locationVerified,
      identityVerified: identityVerified ?? this.identityVerified,
      locationSamplesCount: locationSamplesCount ?? this.locationSamplesCount,
      isDemo: true,
    );
  }

  /// Calculates seconds remaining until the shift starts.
  int get secondsUntilShift {
    final diff = shiftStartTime.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// Whether the shift window has arrived.
  bool get isShiftReady => secondsUntilShift <= 0;
}

class DemoScenarioNotifier extends StateNotifier<DemoScenarioState> {
  DemoScenarioNotifier() : super(_initialState()) {
    _startTimer();
  }

  Timer? _ticker;

  void _startTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.stage == DemoStage.countdownToShift && state.isShiftReady) {
        state = state.copyWith(stage: DemoStage.shiftReady);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static DemoScenarioState _initialState() {
    final now = DateTime.now();
    final shiftStart = now.add(const Duration(minutes: 5));
    const durationMins = 10;

    const student = Student(
      id: 'DEMO-STU-001',
      name: 'Demo Student',
      rollNumber: 'EL2627-DEMO',
      department: 'Computer Engineering',
      className: 'TE-A',
      contact: '+91 98765 43210',
      email: 'demo.student@avcoe.edu.in',
      status: AccountStatus.active,
    );

    const supervisor = Supervisor(
      id: 'DEMO-SV-001',
      name: 'Demo Supervisor',
      email: 'demo.supervisor@avcoe.edu.in',
      contact: '+91 98220 12345',
      assignedLocationIds: ['DEMO-LOC-001'],
      status: SupervisorStatus.onDuty,
    );

    const location = Location(
      id: 'DEMO-LOC-001',
      name: 'Demo Library',
      description: 'Central Library Demo Zone',
      latitude: 19.6174,
      longitude: 74.2045,
      radiusMeters: 100,
      supervisorIds: ['DEMO-SV-001'],
      status: LocationStatus.active,
    );

    final assignment = Assignment(
      id: 'DEMO-ASN-001',
      studentId: 'DEMO-STU-001',
      supervisorId: 'DEMO-SV-001',
      locationId: 'DEMO-LOC-001',
      workDescription: 'Book issue desk & reference catalog maintenance',
      shiftWindows: [
        ShiftWindow(
          start: Duration(hours: shiftStart.hour, minutes: shiftStart.minute),
          end: Duration(
            hours: shiftStart.hour,
            minutes: shiftStart.minute + durationMins,
          ),
        ),
      ],
      effectiveFrom: DateTime(now.year, now.month, 1),
      status: AssignmentStatus.active,
      maxMonthlyHours: 40,
    );

    return DemoScenarioState(
      stage: DemoStage.profileSetup,
      student: student,
      supervisor: supervisor,
      location: location,
      assignment: assignment,
      session: null,
      auditLogs: [
        DemoAuditEntry(
          id: 'AUDIT-001',
          timestamp: now,
          actor: 'System',
          actorRole: 'system',
          action: 'DEMO_INITIALIZED',
          details: 'Demo scenario initialized with fresh candidate DEMO-STU-001.',
        ),
      ],
      shiftStartTime: shiftStart,
      shiftDurationMinutes: durationMins,
    );
  }

  /// Reset the entire demo scenario back to stage 1.
  void resetScenario() {
    state = _initialState();
    _startTimer();
  }

  /// Stage 1 -> 2: Save student onboarding profile.
  void saveStudentProfile({
    required String name,
    required String rollNumber,
    required String department,
    required String className,
    required String contact,
    required String college,
  }) {
    final updatedStudent = Student(
      id: state.student.id,
      name: name,
      rollNumber: rollNumber,
      department: department,
      className: className,
      contact: contact,
      email: state.student.email,
      status: AccountStatus.active,
    );

    final now = DateTime.now();
    final newLogs = List<DemoAuditEntry>.from(state.auditLogs)
      ..add(DemoAuditEntry(
        id: 'AUDIT-${now.millisecondsSinceEpoch}',
        timestamp: now,
        actor: name,
        actorRole: 'student',
        action: 'PROFILE_SAVED',
        details: 'Candidate completed onboarding profile at $college ($department, $className).',
      ));

    state = state.copyWith(
      student: updatedStudent,
      stage: DemoStage.countdownToShift,
      auditLogs: newLogs,
    );
  }

  /// Fast-forward or reschedule shift time.
  void scheduleShift({required int minutesFromNow}) {
    final now = DateTime.now();
    final newStart = now.add(Duration(minutes: minutesFromNow));

    final newAssignment = Assignment(
      id: state.assignment.id,
      studentId: state.student.id,
      supervisorId: state.supervisor.id,
      locationId: state.location.id,
      workDescription: state.assignment.workDescription,
      shiftWindows: [
        ShiftWindow(
          start: Duration(hours: newStart.hour, minutes: newStart.minute),
          end: Duration(
            hours: newStart.hour,
            minutes: newStart.minute + state.shiftDurationMinutes,
          ),
        ),
      ],
      effectiveFrom: state.assignment.effectiveFrom,
      status: AssignmentStatus.active,
      maxMonthlyHours: 40,
    );

    state = state.copyWith(
      shiftStartTime: newStart,
      assignment: newAssignment,
      stage: minutesFromNow <= 0 ? DemoStage.shiftReady : DemoStage.countdownToShift,
    );
  }

  /// Skip remaining countdown immediately to Shift Ready.
  void skipToShiftReady() {
    scheduleShift(minutesFromNow: 0);
  }

  /// Start verification and check-in.
  void startVerification() {
    state = state.copyWith(
      stage: DemoStage.verifyingRequirements,
      locationVerified: false,
      identityVerified: false,
    );
  }

  /// Verify location.
  void setLocationVerified(bool verified) {
    final now = DateTime.now();
    final newLogs = List<DemoAuditEntry>.from(state.auditLogs)
      ..add(DemoAuditEntry(
        id: 'AUDIT-${now.millisecondsSinceEpoch}',
        timestamp: now,
        actor: 'LocationService',
        actorRole: 'system',
        action: verified ? 'LOCATION_VERIFIED' : 'LOCATION_FAILED',
        details: verified
            ? 'GPS fix (19.6174, 74.2045) inside Demo Library (accuracy: 4.2m).'
            : 'GPS fix outside geofence boundary.',
      ));

    state = state.copyWith(
      locationVerified: verified,
      auditLogs: newLogs,
    );
  }

  /// Verify selfie / identity evidence.
  void setIdentityVerified(bool verified) {
    final now = DateTime.now();
    final newLogs = List<DemoAuditEntry>.from(state.auditLogs)
      ..add(DemoAuditEntry(
        id: 'AUDIT-${now.millisecondsSinceEpoch}',
        timestamp: now,
        actor: 'EvidenceService',
        actorRole: 'system',
        action: verified ? 'IDENTITY_VERIFIED' : 'IDENTITY_FAILED',
        details: verified
            ? 'Selfie evidence captured & uploaded to private storage bucket.'
            : 'Identity evidence rejected or unreadable.',
      ));

    state = state.copyWith(
      identityVerified: verified,
      auditLogs: newLogs,
    );
  }

  /// Check-in and transition to active working shift.
  void startShift() {
    final now = DateTime.now();
    final session = Session(
      id: 'DEMO-SES-${now.millisecondsSinceEpoch}',
      studentId: state.student.id,
      date: DateTime(now.year, now.month, now.day),
      windows: state.assignment.shiftWindows,
      status: SessionStatus.working,
      checkInVerifiedAt: now,
    );

    final newLogs = List<DemoAuditEntry>.from(state.auditLogs)
      ..add(DemoAuditEntry(
        id: 'AUDIT-${now.millisecondsSinceEpoch}',
        timestamp: now,
        actor: state.student.name,
        actorRole: 'student',
        action: 'SHIFT_STARTED',
        details: 'Checked in for duty at ${state.location.name}. State is now WORKING.',
      ));

    state = state.copyWith(
      session: session,
      stage: DemoStage.shiftActive,
      locationSamplesCount: 1,
      auditLogs: newLogs,
    );
  }

  /// Simulate recording a periodic location sample during shift.
  void recordSample() {
    final now = DateTime.now();
    final newCount = state.locationSamplesCount + 1;
    final newLogs = List<DemoAuditEntry>.from(state.auditLogs)
      ..add(DemoAuditEntry(
        id: 'AUDIT-${now.millisecondsSinceEpoch}',
        timestamp: now,
        actor: 'LocationMonitor',
        actorRole: 'system',
        action: 'LOCATION_SAMPLE_RECORDED',
        details: 'Sample #$newCount recorded (19.6174, 74.2045) - in zone.',
      ));

    state = state.copyWith(
      locationSamplesCount: newCount,
      auditLogs: newLogs,
    );
  }

  /// Complete checkout and submit session for supervisor review.
  void endShift() {
    final now = DateTime.now();
    final checkIn = state.session?.checkInVerifiedAt ?? now.subtract(const Duration(hours: 3));
    final durationHours = ((now.difference(checkIn).inMinutes) / 60.0).clamp(0.1, 8.0);

    final updatedSession = Session(
      id: state.session?.id ?? 'DEMO-SES-${now.millisecondsSinceEpoch}',
      studentId: state.student.id,
      date: DateTime(now.year, now.month, now.day),
      windows: state.assignment.shiftWindows,
      status: SessionStatus.submitted,
      review: ApprovalStatus.pending,
      checkInVerifiedAt: checkIn,
      checkOutVerifiedAt: now,
      verifiedHours: durationHours,
    );

    final newLogs = List<DemoAuditEntry>.from(state.auditLogs)
      ..add(DemoAuditEntry(
        id: 'AUDIT-${now.millisecondsSinceEpoch}',
        timestamp: now,
        actor: state.student.name,
        actorRole: 'student',
        action: 'SHIFT_SUBMITTED',
        details: 'Checked out from ${state.location.name}. Duration: ${durationHours.toStringAsFixed(1)}h. State: SUBMITTED (pending review).',
      ));

    state = state.copyWith(
      session: updatedSession,
      stage: DemoStage.supervisorReview,
      auditLogs: newLogs,
    );
  }

  /// Supervisor performs review: approve / flag / reject.
  void supervisorReview({
    required ApprovalStatus reviewStatus,
    required String supervisorName,
    String? reason,
  }) {
    final now = DateTime.now();
    final sessionStatus = switch (reviewStatus) {
      ApprovalStatus.approved => SessionStatus.approved,
      ApprovalStatus.flagged => SessionStatus.flagged,
      ApprovalStatus.rejected => SessionStatus.rejected,
      ApprovalStatus.pending => SessionStatus.submitted,
    };

    final updatedSession = Session(
      id: state.session?.id ?? 'DEMO-SES-1',
      studentId: state.student.id,
      date: state.session?.date ?? DateTime(now.year, now.month, now.day),
      windows: state.assignment.shiftWindows,
      status: sessionStatus,
      review: reviewStatus,
      checkInVerifiedAt: state.session?.checkInVerifiedAt,
      checkOutVerifiedAt: state.session?.checkOutVerifiedAt,
      verifiedHours: state.session?.verifiedHours ?? 3.0,
      reason: reason,
    );

    final actionName = switch (reviewStatus) {
      ApprovalStatus.approved => 'ATTENDANCE_APPROVED',
      ApprovalStatus.flagged => 'ATTENDANCE_FLAGGED',
      ApprovalStatus.rejected => 'ATTENDANCE_REJECTED',
      ApprovalStatus.pending => 'ATTENDANCE_PENDING',
    };

    final newLogs = List<DemoAuditEntry>.from(state.auditLogs)
      ..add(DemoAuditEntry(
        id: 'AUDIT-${now.millisecondsSinceEpoch}',
        timestamp: now,
        actor: supervisorName,
        actorRole: 'supervisor',
        action: actionName,
        details: 'Supervisor $supervisorName reviewed attendance: status set to ${reviewStatus.name.toUpperCase()}.',
        reason: reason,
      ));

    state = state.copyWith(
      session: updatedSession,
      stage: DemoStage.adminAudit,
      auditLogs: newLogs,
    );
  }

  /// Admin performs manual correction.
  void adminCorrection({
    required double newVerifiedHours,
    required String adminName,
    required String reason,
  }) {
    final now = DateTime.now();
    final oldHours = state.session?.verifiedHours ?? 0.0;

    final updatedSession = Session(
      id: state.session?.id ?? 'DEMO-SES-1',
      studentId: state.student.id,
      date: state.session?.date ?? DateTime(now.year, now.month, now.day),
      windows: state.assignment.shiftWindows,
      status: SessionStatus.approved,
      review: ApprovalStatus.approved,
      checkInVerifiedAt: state.session?.checkInVerifiedAt,
      checkOutVerifiedAt: state.session?.checkOutVerifiedAt,
      verifiedHours: newVerifiedHours,
      reason: 'Admin corrected hours from ${oldHours.toStringAsFixed(1)}h to ${newVerifiedHours.toStringAsFixed(1)}h: $reason',
    );

    final newLogs = List<DemoAuditEntry>.from(state.auditLogs)
      ..add(DemoAuditEntry(
        id: 'AUDIT-${now.millisecondsSinceEpoch}',
        timestamp: now,
        actor: adminName,
        actorRole: 'admin',
        action: 'MANUAL_HOURS_CORRECTION',
        details: 'Admin manually updated verified hours: ${oldHours.toStringAsFixed(1)}h -> ${newVerifiedHours.toStringAsFixed(1)}h.',
        reason: reason,
      ));

    state = state.copyWith(
      session: updatedSession,
      auditLogs: newLogs,
    );
  }
}

final demoScenarioProvider =
    StateNotifierProvider<DemoScenarioNotifier, DemoScenarioState>(
  (ref) => DemoScenarioNotifier(),
);
