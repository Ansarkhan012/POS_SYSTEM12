/// Confidence in an event's device time (ADR-023). Phase 2 has no server, so
/// every event is [unknown]; later phases add values together with the
/// business-date and skew rules (open question Q6).
enum TimeConfidence { unknown }

/// Caller-supplied part of an outbox event (OFFLINE_SYNC §3).
///
/// Shop, session and actor IDs are always supplied by the caller and never
/// defaulted; they come from Phase 3 onwards. The writer adds event ID,
/// device ID, device sequence, time and status.
final class OutboxEventDraft {
  const OutboxEventDraft({
    required this.eventType,
    required this.schemaVersion,
    required this.payload,
    required this.shopId,
    required this.localSessionId,
    required this.actorUserId,
    this.idempotencyKey,
  });

  final String eventType;
  final int schemaVersion;

  /// Serialized as canonical JSON; only null, bool, int, String, lists and
  /// string-keyed maps are allowed (no floating point).
  final Map<String, Object?> payload;

  final String shopId;
  final String localSessionId;
  final String actorUserId;

  /// Defaults to the generated event ID.
  final String? idempotencyKey;
}
