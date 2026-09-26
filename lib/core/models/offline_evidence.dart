/// Domain types for offline evidence capture and duplicate prevention.
///
/// During offline periods the client queues evidence locally, preserving
/// server-authoritative timestamps. On reconnection the queue is
/// replayed with idempotency keys to prevent duplicates.
library;

/// A single piece of evidence captured while offline.
class OfflineEvidence {
  const OfflineEvidence({
    required this.operationId,
    required this.type,
    required this.capturedAt,
    required this.payload,
  });

  final String operationId;
  final String type;
  final DateTime capturedAt;
  final Map<String, Object?> payload;
}

/// An idempotency key used when replaying offline evidence to prevent
/// duplicate server-side records.
class IdempotencyKey {
  const IdempotencyKey({required this.operationId, required this.scope});

  final String operationId;
  final String scope;
}