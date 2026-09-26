import 'package:flutter/material.dart';

enum AuditAction {
  attendanceApproved,
  attendanceFlagged,
  attendanceRejected,
  correctionRequested,
  recordCreated;

  String get label => switch (this) {
        AuditAction.attendanceApproved => 'Approved',
        AuditAction.attendanceFlagged => 'Flagged',
        AuditAction.attendanceRejected => 'Rejected',
        AuditAction.correctionRequested => 'Correction requested',
        AuditAction.recordCreated => 'Record created',
      };

  IconData get icon => switch (this) {
        AuditAction.attendanceApproved => Icons.check_circle,
        AuditAction.attendanceFlagged => Icons.flag,
        AuditAction.attendanceRejected => Icons.cancel,
        AuditAction.correctionRequested => Icons.edit_note,
        AuditAction.recordCreated => Icons.add_circle_outline,
      };
}

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.actorName,
    required this.createdAt,
    this.note,
  });

  final String id;
  final AuditAction action;
  final String targetType;
  final String targetId;
  final String actorName;
  final DateTime createdAt;
  final String? note;

  static const String collection = 'audit_logs';
}