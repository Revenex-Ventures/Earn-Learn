import '../../core/models/models.dart';
import '../dev_only.dart';
import 'runtime_store.dart';

/// Record of supervisor decisions for the local/demo build.
///
/// Thin facade over [RuntimeStore] so decisions taken on demo fixture items
/// (which have no backing session) are **persisted on-device** and survive an
/// app restart, exactly like real submitted sessions. Kept as a separate type
/// so existing call sites don't change.
@DevOnly('Persisted supervisor decisions for the local/demo queue.')
class LocalReviewStore {
  LocalReviewStore._();

  static final LocalReviewStore instance = LocalReviewStore._();

  /// Records a supervisor decision (and optional note) for a queue item.
  void record(String itemId, ApprovalStatus status, {String? note}) =>
      RuntimeStore.instance.recordDecision(itemId, status, note: note);

  /// The decision recorded for [itemId], if any.
  ApprovalStatus? decisionFor(String itemId) =>
      RuntimeStore.instance.decisionFor(itemId);

  /// The note recorded for [itemId], if any.
  String? noteFor(String itemId) => RuntimeStore.instance.noteFor(itemId);

  /// Clears all recorded decisions (used by tests).
  void reset() => RuntimeStore.instance.reset();
}
