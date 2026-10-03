import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/models/models.dart';
import '../../domain/attendance/session.dart';
import '../../domain/attendance/session_status.dart';

/// On-device persistent store for live Earn & Learn activity in the local
/// (no-Firebase) build.
///
/// Holds submitted duty sessions (student check-in / check-out) and supervisor
/// review decisions, and survives app restarts by serialising to
/// `flutter_secure_storage`. This is what connects the three portals into one
/// loop: a student's check-out is written here, the supervisor queue reads it
/// live, and the approve / flag / reject decision written back is visible to
/// the student on their next read — even after the app is closed and reopened.
///
/// The Firestore build ignores this store entirely; server state is canonical
/// there.
class RuntimeStore {
  RuntimeStore._();

  static final RuntimeStore instance = RuntimeStore._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _sessionsKey = 'el_runtime_sessions_v1';
  static const String _decisionsKey = 'el_runtime_decisions_v1';

  /// Submitted sessions keyed by `studentId|sessionId` so two students sharing
  /// a date-based session id never collide.
  final Map<String, Session> _sessions = <String, Session>{};

  /// Supervisor decisions / notes for demo fixture items (which have no backing
  /// [Session]). Real sessions carry their own review state.
  final Map<String, ApprovalStatus> _decisions = <String, ApprovalStatus>{};
  final Map<String, String> _notes = <String, String>{};

  bool _loaded = false;
  bool get isLoaded => _loaded;

  static String keyFor(String studentId, String sessionId) =>
      '$studentId|$sessionId';

  // PERSIST_PLACEHOLDER

  /// Hydrates the store from disk. Call once at app boot (before `runApp`).
  Future<void> load() async {
    if (_loaded) return;
    try {
      final rawSessions = await _storage.read(key: _sessionsKey);
      if (rawSessions != null && rawSessions.isNotEmpty) {
        final decoded = jsonDecode(rawSessions) as Map<String, dynamic>;
        decoded.forEach((k, v) {
          final session = _sessionFromJson(v as Map<String, dynamic>);
          if (session != null) _sessions[k] = session;
        });
      }
      final rawDecisions = await _storage.read(key: _decisionsKey);
      if (rawDecisions != null && rawDecisions.isNotEmpty) {
        final decoded = jsonDecode(rawDecisions) as Map<String, dynamic>;
        final dec = decoded['decisions'] as Map<String, dynamic>? ?? const {};
        dec.forEach((k, v) {
          final st = _approvalFromName(v as String?);
          if (st != null) _decisions[k] = st;
        });
        final nts = decoded['notes'] as Map<String, dynamic>? ?? const {};
        nts.forEach((k, v) => _notes[k] = v as String);
      }
    } catch (_) {
      // A corrupt or unreadable store must never crash the app; start clean.
    }
    _loaded = true;
  }

  // --- sessions -------------------------------------------------------------

  void putSession(Session session) {
    _sessions[keyFor(session.studentId, session.id)] = session;
    _persistSessions();
  }

  Session? session(String studentId, String sessionId) =>
      _sessions[keyFor(studentId, sessionId)];

  List<Session> sessionsFor(String studentId) => _sessions.values
      .where((s) => s.studentId == studentId)
      .toList(growable: false);

  List<Session> allSessions() => _sessions.values.toList(growable: false);

  // --- fixture-item decisions ----------------------------------------------

  void recordDecision(String itemId, ApprovalStatus status, {String? note}) {
    _decisions[itemId] = status;
    if (note != null && note.trim().isNotEmpty) _notes[itemId] = note.trim();
    _persistDecisions();
  }

  ApprovalStatus? decisionFor(String itemId) => _decisions[itemId];
  String? noteFor(String itemId) => _notes[itemId];

  /// Clears all persisted activity (used by tests / a "reset demo" action).
  void reset() {
    _sessions.clear();
    _decisions.clear();
    _notes.clear();
    _persistSessions();
    _persistDecisions();
  }

  // APPEND_PLACEHOLDER

  // --- persistence (fire-and-forget; failures are non-fatal for the demo) ---

  void _persistSessions() {
    final map = <String, dynamic>{};
    _sessions.forEach((k, v) => map[k] = _sessionToJson(v));
    _storage.write(key: _sessionsKey, value: jsonEncode(map));
  }

  void _persistDecisions() {
    final map = <String, dynamic>{
      'decisions': _decisions.map((k, v) => MapEntry(k, v.name)),
      'notes': _notes,
    };
    _storage.write(key: _decisionsKey, value: jsonEncode(map));
  }

  // --- (de)serialisation ----------------------------------------------------

  Map<String, dynamic> _sessionToJson(Session s) => <String, dynamic>{
        'id': s.id,
        'studentId': s.studentId,
        'date': s.date.toIso8601String(),
        'windows': [
          for (final w in s.windows)
            {'start': w.start.inMinutes, 'end': w.end.inMinutes},
        ],
        'status': s.status.name,
        'review': s.review.name,
        'checkInRequestedAt': s.checkInRequestedAt?.toIso8601String(),
        'checkInVerifiedAt': s.checkInVerifiedAt?.toIso8601String(),
        'checkOutRequestedAt': s.checkOutRequestedAt?.toIso8601String(),
        'checkOutVerifiedAt': s.checkOutVerifiedAt?.toIso8601String(),
        'verifiedHours': s.verifiedHours,
        'reason': s.reason,
        'createdAt': s.createdAt?.toIso8601String(),
        'updatedAt': s.updatedAt?.toIso8601String(),
      };

  Session? _sessionFromJson(Map<String, dynamic> j) {
    try {
      DateTime? dt(Object? v) =>
          v == null ? null : DateTime.tryParse(v as String);
      final windows = <ShiftWindow>[
        for (final w in (j['windows'] as List? ?? const []))
          ShiftWindow(
            start: Duration(minutes: ((w as Map)['start'] as num).toInt()),
            end: Duration(minutes: (w['end'] as num).toInt()),
          ),
      ];
      return Session(
        id: j['id'] as String,
        studentId: j['studentId'] as String,
        date: DateTime.parse(j['date'] as String),
        windows: windows,
        status:
            _statusFromName(j['status'] as String?) ?? SessionStatus.submitted,
        review:
            _approvalFromName(j['review'] as String?) ?? ApprovalStatus.pending,
        checkInRequestedAt: dt(j['checkInRequestedAt']),
        checkInVerifiedAt: dt(j['checkInVerifiedAt']),
        checkOutRequestedAt: dt(j['checkOutRequestedAt']),
        checkOutVerifiedAt: dt(j['checkOutVerifiedAt']),
        verifiedHours: (j['verifiedHours'] as num?)?.toDouble() ?? 0,
        reason: j['reason'] as String?,
        createdAt: dt(j['createdAt']),
        updatedAt: dt(j['updatedAt']),
      );
    } catch (_) {
      return null;
    }
  }

  SessionStatus? _statusFromName(String? n) {
    if (n == null) return null;
    for (final v in SessionStatus.values) {
      if (v.name == n) return v;
    }
    return null;
  }

  ApprovalStatus? _approvalFromName(String? n) {
    if (n == null) return null;
    for (final v in ApprovalStatus.values) {
      if (v.name == n) return v;
    }
    return null;
  }
}
