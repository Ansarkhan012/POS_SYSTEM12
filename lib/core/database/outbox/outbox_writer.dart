import 'package:drift/drift.dart';

import '../../identifiers/uuid_v4.dart';
import '../../numeric/fixed_point.dart';
import '../../time/device_clock.dart';
import '../app_database.dart';
import '../local_transaction.dart';
import 'outbox_event_draft.dart';
import 'outbox_payload.dart';

/// Appends events to the local outbox inside a [LocalWriteContext], i.e. in
/// the same transaction as the business rows they describe (ADR-005).
///
/// In that transaction it assigns the next gap-free device sequence number;
/// a rollback consumes no number. Transmission is Phase 8.
class OutboxWriter {
  OutboxWriter({required this._ids, required this._clock});

  final UuidV4Generator _ids;
  final DeviceClock _clock;

  Future<OutboxEventRow> append(
    LocalWriteContext context,
    OutboxEventDraft draft,
  ) async {
    if (!context.isActive) {
      throw StateError(
        'OutboxWriter.append must run inside LocalTransactionRunner.run',
      );
    }
    _validate(draft);
    final payloadJson = encodeOutboxPayload(draft.payload);

    final db = context.database;
    final identity = await db.select(db.deviceIdentity).getSingle();
    final deviceSeq = checkedAdd(identity.lastDeviceSeq, 1);
    await (db.update(db.deviceIdentity)..where((t) => t.singleton.equals(1)))
        .write(DeviceIdentityCompanion(lastDeviceSeq: Value(deviceSeq)));

    final eventId = _ids.next();
    final now = _clock.now();
    return db
        .into(db.outboxEvents)
        .insertReturning(
          OutboxEventsCompanion.insert(
            eventId: eventId,
            idempotencyKey: draft.idempotencyKey ?? eventId,
            shopId: draft.shopId,
            deviceId: identity.installId,
            localSessionId: draft.localSessionId,
            actorUserId: draft.actorUserId,
            deviceSeq: deviceSeq,
            eventType: draft.eventType,
            schemaVersion: draft.schemaVersion,
            payloadJson: payloadJson,
            occurredAtUtcMicros: now.utcMicros,
            deviceUtcOffsetMinutes: now.utcOffsetMinutes,
            timeConfidence: TimeConfidence.unknown.name,
          ),
        );
  }

  static void _validate(OutboxEventDraft draft) {
    void requireText(String value, String field) {
      if (value.trim().isEmpty) {
        throw OutboxValidationException('$field must not be empty');
      }
    }

    requireText(draft.eventType, 'eventType');
    requireText(draft.shopId, 'shopId');
    requireText(draft.localSessionId, 'localSessionId');
    requireText(draft.actorUserId, 'actorUserId');
    final idempotencyKey = draft.idempotencyKey;
    if (idempotencyKey != null) requireText(idempotencyKey, 'idempotencyKey');
    if (draft.schemaVersion <= 0) {
      throw const OutboxValidationException('schemaVersion must be positive');
    }
  }
}
