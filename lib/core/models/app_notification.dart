import 'package:flutter/material.dart';
import 'user_role.dart';

/// Kinds of in-app notification the connected demo can raise.
///
/// Each maps to an icon + accent in the notification centre. Persisted by
/// `.name`, so values may be appended but must not be renamed.
enum NotificationType {
  attendanceApproved,
  attendanceFlagged,
  attendanceRejected,
  checkOutSubmitted,
  shiftAdjusted,
  studentAdded,
  studentRemoved,
  adminMessage,
  payrollApproved,
  leaveStatusChanged,
  supervisorAdded,
  supervisorRemoved;

  String get label => switch (this) {
        NotificationType.attendanceApproved => 'Attendance approved',
        NotificationType.attendanceFlagged => 'Attendance flagged',
        NotificationType.attendanceRejected => 'Attendance rejected',
        NotificationType.checkOutSubmitted => 'Check-out submitted',
        NotificationType.shiftAdjusted => 'Shift updated',
        NotificationType.studentAdded => 'Student enrolled',
        NotificationType.studentRemoved => 'Student removed',
        NotificationType.adminMessage => 'Message',
        NotificationType.payrollApproved => 'Stipend approved',
        NotificationType.leaveStatusChanged => 'Leave status updated',
        NotificationType.supervisorAdded => 'Supervisor added',
        NotificationType.supervisorRemoved => 'Supervisor removed',
      };

  IconData get icon => switch (this) {
        NotificationType.attendanceApproved => Icons.check_circle_outline,
        NotificationType.attendanceFlagged => Icons.flag_outlined,
        NotificationType.attendanceRejected => Icons.cancel_outlined,
        NotificationType.checkOutSubmitted => Icons.how_to_reg_outlined,
        NotificationType.shiftAdjusted => Icons.schedule_outlined,
        NotificationType.studentAdded => Icons.person_add_outlined,
        NotificationType.studentRemoved => Icons.person_remove_outlined,
        NotificationType.adminMessage => Icons.message_outlined,
        NotificationType.payrollApproved => Icons.payments_outlined,
        NotificationType.leaveStatusChanged => Icons.event_note_outlined,
        NotificationType.supervisorAdded => Icons.badge_outlined,
        NotificationType.supervisorRemoved => Icons.badge_outlined,
      };
}

/// A single in-app notification addressed to one role, optionally scoped to a
/// specific principal within that role.
///
/// Named `AppNotification` (not `Notification`) to avoid colliding with
/// Flutter's `Notification` widget-tree class. When [recipientId] is null the
/// notification is a broadcast to every account of [recipientRole] (e.g. an
/// admin message to "all students").
class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientRole,
    this.recipientId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.senderName,
  });

  final String id;
  final UserRole recipientRole;

  /// Entity id of the single recipient (`STU-###` / `SV-##`), or null for a
  /// role-wide broadcast.
  final String? recipientId;

  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String? senderName;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        recipientRole: recipientRole,
        recipientId: recipientId,
        type: type,
        title: title,
        body: body,
        createdAt: createdAt,
        read: read ?? this.read,
        senderName: senderName,
      );

  /// True when this notification should be delivered to the principal
  /// identified by [role] + [entityId]. Broadcasts (null [recipientId]) reach
  /// every account of the role.
  bool addressedTo(UserRole role, String? entityId) {
    if (role != recipientRole) return false;
    if (recipientId == null) return true;
    return recipientId == entityId;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipientRole': recipientRole.name,
        'recipientId': recipientId,
        'type': type.name,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'read': read,
        'senderName': senderName,
      };

  static AppNotification fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as String,
        recipientRole: _role(j['recipientRole'] as String?),
        recipientId: j['recipientId'] as String?,
        type: _type(j['type'] as String?),
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        read: j['read'] as bool? ?? false,
        senderName: j['senderName'] as String?,
      );

  static UserRole _role(String? n) {
    for (final v in UserRole.values) {
      if (v.name == n) return v;
    }
    return UserRole.student;
  }

  static NotificationType _type(String? n) {
    for (final v in NotificationType.values) {
      if (v.name == n) return v;
    }
    return NotificationType.adminMessage;
  }
}
