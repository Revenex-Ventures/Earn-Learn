import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';
import '../../core/models/models.dart';
import '../../data/data.dart';
import '../../data/local/notification_store.dart';
import '../../shared/components/components.dart';
import '../auth/auth_session.dart';

/// Role-aware in-app notification centre (local build).
///
/// Lists every notification addressed to the signed-in principal newest-first,
/// lets them mark one or all read, and stays in sync with the shell badge by
/// invalidating [notificationsProvider] + [notificationUnreadProvider] after any
/// mutation. Reached from each role's profile screen.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  ({UserRole? role, String? entityId}) get _principal {
    final role = AuthSession.role;
    final entityId = switch (role) {
      UserRole.student => AuthSession.studentId,
      UserRole.supervisor => AuthSession.supervisorId,
      _ => null,
    };
    return (role: role, entityId: entityId);
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(notificationsProvider);
    ref.invalidate(notificationUnreadProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(notificationsProvider);
    final principal = _principal;
    final store = NotificationStore.instance;

    return Scaffold(
      backgroundColor: AppColors.warmIvory,
      appBar: AppBar(
        backgroundColor: AppColors.warmSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              if (principal.role == null) return;
              store.markAllRead(principal.role!, principal.entityId);
              await _refresh(ref);
            },
            child: Text(
              'Mark all read',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.forestSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load notifications',
          message: error.toString(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'No notifications yet',
              message:
                  'Approvals, shift changes and messages will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final n = items[i];
                return _NotificationTile(
                  notification: n,
                  onTap: n.read
                      ? null
                      : () async {
                          store.markRead(n.id);
                          await _refresh(ref);
                        },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Visual accent + icon for one notification type.
(IconData, Color) _visuals(NotificationType type) => switch (type) {
      NotificationType.attendanceApproved =>
        (Icons.verified_outlined, AppColors.forestSoft),
      NotificationType.payrollApproved =>
        (Icons.payments_outlined, AppColors.forestSoft),
      NotificationType.attendanceRejected =>
        (Icons.cancel_outlined, AppColors.goldSoftDeep),
      NotificationType.attendanceFlagged =>
        (Icons.flag_outlined, AppColors.goldSoftDeep),
      NotificationType.checkOutSubmitted =>
        (Icons.inbox_outlined, AppColors.forestSoftBright),
      NotificationType.shiftAdjusted =>
        (Icons.schedule_outlined, AppColors.forestSoftBright),
      NotificationType.studentAdded =>
        (Icons.person_add_alt_outlined, AppColors.forestSoftBright),
      NotificationType.studentRemoved =>
        (Icons.person_remove_outlined, AppColors.slateWarm),
      NotificationType.adminMessage =>
        (Icons.campaign_outlined, AppColors.goldSoftDeep),
      NotificationType.leaveStatusChanged =>
        (Icons.event_note_outlined, AppColors.terraSpark),
      NotificationType.supervisorAdded =>
        (Icons.badge_outlined, AppColors.goldSoftDeep),
      NotificationType.supervisorRemoved =>
        (Icons.badge_outlined, AppColors.claySoftReject),
    };

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, this.onTap});

  final AppNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, accent) = _visuals(notification.type);
    return WarmCard(
      ivory: notification.read,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WarmIconWell(
            icon: icon,
            background: accent.withValues(alpha: 0.12),
            foreground: accent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: AppTextStyles.titleSmall.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!notification.read)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 8, top: 4),
                        decoration: const BoxDecoration(
                          color: AppColors.forestSoft,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  notification.body,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.slateWarm),
                ),
                const SizedBox(height: 6),
                Text(
                  _timeAgo(notification.createdAt),
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.slateWarm),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _timeAgo(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final d = when;
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Reusable profile nav card that opens the notification centre at [route] and
/// shows the signed-in principal's unread count. Refreshes the badge on return.
class NotificationsNavCard extends ConsumerWidget {
  const NotificationsNavCard({super.key, required this.route});

  final String route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationUnreadProvider).valueOrNull ?? 0;
    return WarmCard(
      onTap: () async {
        await context.push(route);
        ref.invalidate(notificationUnreadProvider);
      },
      child: Row(
        children: [
          WarmIconWell(
            icon: Icons.notifications_none,
            background: AppColors.forestSoft.withValues(alpha: 0.12),
            foreground: AppColors.forestSoft,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: AppTextStyles.titleSmall
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Approvals, shift changes and messages',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.slateWarm),
                ),
              ],
            ),
          ),
          if (unread > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: PremiumBadge(label: '$unread', tone: BadgeTone.gold),
            ),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.slateWarm),
        ],
      ),
    );
  }
}

/// Admin compose card — broadcasts a message to all students or all
/// supervisors. Stored once as a broadcast (null recipientId) and delivered to
/// every account of the target role via [AppNotification.addressedTo].
class AdminMessageCard extends ConsumerWidget {
  const AdminMessageCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WarmCard(
      onTap: () => _openComposer(context, ref),
      child: Row(
        children: [
          WarmIconWell(
            icon: Icons.campaign_outlined,
            background: AppColors.goldSoftDeep.withValues(alpha: 0.14),
            foreground: AppColors.goldSoftDeep,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Send announcement',
                  style: AppTextStyles.titleSmall
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Message all students or all supervisors',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.slateWarm),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.slateWarm),
        ],
      ),
    );
  }

  Future<void> _openComposer(BuildContext context, WidgetRef ref) async {
    var target = UserRole.student;
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    final sent = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.warmSurface,
              title: const Text('Send announcement'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recipients',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    SegmentedButton<UserRole>(
                      segments: const [
                        ButtonSegment(
                            value: UserRole.student, label: Text('Students')),
                        ButtonSegment(
                            value: UserRole.supervisor,
                            label: Text('Supervisors')),
                      ],
                      selected: {target},
                      onSelectionChanged: (s) =>
                          setState(() => target = s.first),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: titleCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyCtrl,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forestSoft,
                  ),
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty &&
                        bodyCtrl.text.trim().isEmpty) {
                      return;
                    }
                    NotificationStore.instance.add(
                      recipientRole: target,
                      recipientId: null,
                      type: NotificationType.adminMessage,
                      title: titleCtrl.text.trim().isEmpty
                          ? 'Announcement'
                          : titleCtrl.text.trim(),
                      body: bodyCtrl.text.trim(),
                      senderName: 'Program Office',
                    );
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    bodyCtrl.dispose();

    if (sent == true) {
      ref.invalidate(notificationsProvider);
      ref.invalidate(notificationUnreadProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement sent.')),
        );
      }
    }
  }
}
