import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/models/app_notification.dart';
import '../../core/models/user_role.dart';
import '../dev_only.dart';

/// On-device notification inbox for the local (no-Firebase) build.
///
/// Holds every raised [AppNotification] and persists it via
/// `flutter_secure_storage` so the inbox survives an app restart. Scoping to a
/// principal is done at read time via [AppNotification.addressedTo], so a
/// single broadcast (null recipientId) is stored once yet reaches every account
/// of that role.
///
/// Mutations follow the codebase convention: they write + persist, and callers
/// `ref.invalidate(...)` the relevant provider to refresh the UI.
@DevOnly('Persistent in-app notification inbox for the local/demo build.')
class NotificationStore {
  NotificationStore._();

  static final NotificationStore instance = NotificationStore._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _key = 'el_notifications_v1';

  final List<AppNotification> _items = [];

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// A monotonic counter folded into generated ids to avoid collisions when
  /// several notifications are raised within the same millisecond.
  int _seq = 0;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final list = decoded['items'] as List?;
        if (list != null) {
          _items
            ..clear()
            ..addAll(list
                .map((e) => AppNotification.fromJson(e as Map<String, dynamic>)));
        }
        _seq = (decoded['seq'] as num?)?.toInt() ?? _items.length;
      }
    } catch (_) {
      // A corrupt inbox must never crash the app; start empty.
    }
    _loaded = true;
  }

  // --- reads ----------------------------------------------------------------

  /// Notifications addressed to [role] (+ optional [entityId]), newest first.
  List<AppNotification> forRole(UserRole role, String? entityId) {
    final list =
        _items.where((n) => n.addressedTo(role, entityId)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  int unreadCount(UserRole role, String? entityId) => _items
      .where((n) => !n.read && n.addressedTo(role, entityId))
      .length;

  // --- mutations (each persists) --------------------------------------------

  /// Raises a notification. [recipientId] null broadcasts to the whole role.
  AppNotification add({
    required UserRole recipientRole,
    String? recipientId,
    required NotificationType type,
    required String title,
    required String body,
    String? senderName,
  }) {
    _seq += 1;
    final n = AppNotification(
      id: 'NTF-${DateTime.now().millisecondsSinceEpoch}-$_seq',
      recipientRole: recipientRole,
      recipientId: recipientId,
      type: type,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      senderName: senderName,
    );
    _items.add(n);
    _persist();
    return n;
  }

  void markRead(String id) {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx < 0 || _items[idx].read) return;
    _items[idx] = _items[idx].copyWith(read: true);
    _persist();
  }

  /// Marks every notification addressed to the principal as read.
  void markAllRead(UserRole role, String? entityId) {
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      final n = _items[i];
      if (!n.read && n.addressedTo(role, entityId)) {
        _items[i] = n.copyWith(read: true);
        changed = true;
      }
    }
    if (changed) _persist();
  }

  void reset() {
    _items.clear();
    _seq = 0;
    _storage.delete(key: _key);
  }

  // --- persistence (fire-and-forget; failures are non-fatal) ----------------

  void _persist() {
    final map = <String, dynamic>{
      'seq': _seq,
      'items': _items.map((n) => n.toJson()).toList(),
    };
    _storage.write(key: _key, value: jsonEncode(map));
  }
}
