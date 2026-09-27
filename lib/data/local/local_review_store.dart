import '../../core/models/models.dart';
import '../dev_only.dart';

/// In-memory record of supervisor decisions for the local/demo build.
///
/// The local verification queue is served from static fixtures; without a
/// place to remember decisions, an item a supervisor just approved would
/// reappear as "pending" on the next read. This singleton lets the queue
/// reflect the actions taken during the running session. It is intentionally
/// **not** persisted — the Firestore build carries real state on the server.
@DevOnly('Session-scoped supervisor decisions for the local/demo queue.')
class LocalReviewStore {
  LocalReviewStore._();

  static final LocalReviewStore instance = LocalReviewStore._();

  final Map<String, ApprovalStatus> _decisions = <String, ApprovalStatus>{};
  final Map<String, String> _notes = <String, String>{};

  /// Records a supervisor decision (and optional note) for a queue item.
  void record(String itemId, ApprovalStatus status, {String? note}) {
    _decisions[itemId] = status;
    if (note != null && note.trim().isNotEmpty) {
      _notes[itemId] = note.trim();
    }
  }

  /// The decision recorded for [itemId] during this session, if any.
  ApprovalStatus? decisionFor(String itemId) => _decisions[itemId];

  /// The note recorded for [itemId] during this session, if any.
  String? noteFor(String itemId) => _notes[itemId];

  /// Clears all recorded decisions (used by tests).
  void reset() {
    _decisions.clear();
    _notes.clear();
  }
}
