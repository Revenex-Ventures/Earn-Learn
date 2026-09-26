import 'package:flutter/material.dart';

import '../models/models.dart';
import 'app_colors.dart';

/// Semantic tone shared by every status presentation.
enum StatusTone {
  /// Business as usual: scheduled, off days, inactive.
  neutral,

  /// Confirmed/good: present, approved, verified, paid.
  positive,

  /// Needs action/movement: pending, in progress, upcoming.
  attention,

  /// Broken/blocked: absent, late, rejected, flagged, held.
  negative,
}

/// Centralized presentation mapping for a status.
class StatusStyle {
  const StatusStyle({required this.color, required this.icon, required this.label});

  final Color color;
  final IconData icon;
  final String label;

  Color get background => color.withValues(alpha: 0.12);
  Color get foreground => color;
  Color get border => color.withValues(alpha: 0.3);

  static StatusStyle fromAttendance(AttendanceStatus status) => status.style;
  static StatusStyle fromApproval(ApprovalStatus status) => status.style;
  static StatusStyle fromAssignment(AssignmentStatus status) => status.style;
  static StatusStyle fromLocation(LocationStatus status) => status.style;
  static StatusStyle fromShiftState(ShiftState state) => state.style;
}

/// Build a [StatusStyle] from a semantic tone. Single source of truth for
/// color allocation so every status in the app agrees on meaning.
StatusStyle styleFor(StatusTone tone, {required IconData icon, required String label}) {
  final color = switch (tone) {
    StatusTone.neutral => AppColors.slate,
    StatusTone.positive => AppColors.sage,
    StatusTone.attention => AppColors.marigold,
    StatusTone.negative => AppColors.clay,
  };
  return StatusStyle(color: color, icon: icon, label: label);
}

/// Light wash used behind tinted status visuals.
Color toneBackground(StatusTone tone) => styleFor(tone, icon: Icons.circle, label: '').background;

extension AttendanceStatusStyle on AttendanceStatus {
  StatusStyle get style => switch (this) {
        AttendanceStatus.present => styleFor(StatusTone.positive, icon: Icons.check_circle, label: label),
        AttendanceStatus.late => styleFor(StatusTone.negative, icon: Icons.access_time_filled, label: label),
        AttendanceStatus.absent => styleFor(StatusTone.negative, icon: Icons.cancel, label: label),
        AttendanceStatus.leave => styleFor(StatusTone.neutral, icon: Icons.event_busy, label: label),
        AttendanceStatus.pending => styleFor(StatusTone.attention, icon: Icons.schedule, label: label),
        AttendanceStatus.scheduled => styleFor(StatusTone.neutral, icon: Icons.more_horiz, label: label),
        AttendanceStatus.flagged => styleFor(StatusTone.negative, icon: Icons.flag, label: label),
      };
}

extension ApprovalStatusStyle on ApprovalStatus {
  StatusStyle get style => switch (this) {
        ApprovalStatus.pending => styleFor(StatusTone.attention, icon: Icons.hourglass_top, label: label),
        ApprovalStatus.approved => styleFor(StatusTone.positive, icon: Icons.verified, label: label),
        ApprovalStatus.rejected => styleFor(StatusTone.negative, icon: Icons.cancel, label: label),
        ApprovalStatus.flagged => styleFor(StatusTone.negative, icon: Icons.flag, label: label),
      };
}

extension AssignmentStatusStyle on AssignmentStatus {
  StatusStyle get style => switch (this) {
        AssignmentStatus.active => styleFor(StatusTone.positive, icon: Icons.work_outline, label: label),
        AssignmentStatus.future => styleFor(StatusTone.attention, icon: Icons.upcoming_outlined, label: label),
        AssignmentStatus.temporary => styleFor(StatusTone.attention, icon: Icons.timelapse, label: label),
        AssignmentStatus.inactive => styleFor(StatusTone.neutral, icon: Icons.event_busy, label: label),
        AssignmentStatus.completed => styleFor(StatusTone.positive, icon: Icons.check_circle_outline, label: label),
      };
}

extension LocationStatusStyle on LocationStatus {
  StatusStyle get style => switch (this) {
        LocationStatus.active => styleFor(StatusTone.positive, icon: Icons.location_on, label: label),
        LocationStatus.attention => styleFor(StatusTone.attention, icon: Icons.notification_important, label: label),
        LocationStatus.inactive => styleFor(StatusTone.neutral, icon: Icons.location_off, label: label),
      };
}

extension ShiftStateStyle on ShiftState {
  StatusStyle get style => switch (this) {
        ShiftState.upcoming => styleFor(StatusTone.attention, icon: Icons.timer_outlined, label: label),
        ShiftState.ready => styleFor(StatusTone.attention, icon: Icons.rotate_right, label: label),
        ShiftState.working => styleFor(StatusTone.attention, icon: Icons.work, label: label),
        ShiftState.completed => styleFor(StatusTone.positive, icon: Icons.check_circle, label: label),
        ShiftState.pendingVerification => styleFor(StatusTone.attention, icon: Icons.hourglass_top, label: label),
        ShiftState.missed => styleFor(StatusTone.negative, icon: Icons.event_busy, label: label),
        ShiftState.flagged => styleFor(StatusTone.negative, icon: Icons.flag, label: label),
        ShiftState.leave => styleFor(StatusTone.neutral, icon: Icons.event_available, label: label),
        ShiftState.offDay => styleFor(StatusTone.neutral, icon: Icons.beach_access, label: label),
      };
}

extension PaymentStatusStyle on PaymentStatus {
  StatusStyle get style => switch (this) {
        PaymentStatus.pending => styleFor(StatusTone.attention, icon: Icons.hourglass_top, label: label),
        PaymentStatus.inProgress => styleFor(StatusTone.attention, icon: Icons.autorenew, label: label),
        PaymentStatus.approved => styleFor(StatusTone.positive, icon: Icons.verified, label: label),
        PaymentStatus.paid => styleFor(StatusTone.positive, icon: Icons.payments, label: label),
        PaymentStatus.held => styleFor(StatusTone.negative, icon: Icons.lock, label: label),
      };
}

extension LeaveStatusStyle on LeaveStatus {
  StatusStyle get style => switch (this) {
        LeaveStatus.pending => styleFor(StatusTone.attention, icon: Icons.hourglass_top, label: label),
        LeaveStatus.approved => styleFor(StatusTone.positive, icon: Icons.event_available, label: label),
        LeaveStatus.rejected => styleFor(StatusTone.negative, icon: Icons.event_busy, label: label),
      };
}

extension AccountStatusStyle on AccountStatus {
  StatusStyle get style => switch (this) {
        AccountStatus.active => styleFor(StatusTone.positive, icon: Icons.badge, label: label),
        AccountStatus.inactive => styleFor(StatusTone.neutral, icon: Icons.person_off, label: label),
        AccountStatus.pending => styleFor(StatusTone.attention, icon: Icons.hourglass_top, label: label),
      };
}

extension AuditActionStyle on AuditAction {
  StatusStyle get style => switch (this) {
        AuditAction.attendanceApproved => styleFor(StatusTone.positive, icon: Icons.check_circle, label: label),
        AuditAction.attendanceFlagged => styleFor(StatusTone.negative, icon: Icons.flag, label: label),
        AuditAction.attendanceRejected => styleFor(StatusTone.negative, icon: Icons.cancel, label: label),
        AuditAction.correctionRequested => styleFor(StatusTone.attention, icon: Icons.edit_note, label: label),
        AuditAction.recordCreated => styleFor(StatusTone.neutral, icon: Icons.add_circle_outline, label: label),
      };
}

extension CalendarEventTypeStyle on CalendarEventType {
  StatusStyle get style => switch (this) {
        CalendarEventType.offDay => styleFor(StatusTone.neutral, icon: Icons.event_available, label: label),
        CalendarEventType.holiday => styleFor(StatusTone.neutral, icon: Icons.account_balance, label: label),
        CalendarEventType.festival => styleFor(StatusTone.attention, icon: Icons.celebration, label: label),
        CalendarEventType.event => styleFor(StatusTone.attention, icon: Icons.star_outline, label: label),
      };
}

extension SupervisorStatusStyle on SupervisorStatus {
  StatusStyle get style => switch (this) {
        SupervisorStatus.onDuty => styleFor(StatusTone.positive, icon: Icons.badge, label: label),
        SupervisorStatus.offDuty => styleFor(StatusTone.neutral, icon: Icons.schedule, label: label),
        SupervisorStatus.unavailable => styleFor(StatusTone.negative, icon: Icons.help_outline, label: label),
      };
}