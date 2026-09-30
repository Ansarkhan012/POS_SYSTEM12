import 'package:drift/drift.dart';

/// Single-row table holding the install ID and the per-device event sequence
/// counter (P2-D5, OFFLINE_SYNC §7). STRICT: column types are enforced.
@DataClassName('DeviceIdentityRow')
class DeviceIdentity extends Table {
  @override
  String get tableName => 'device_identity';

  @override
  bool get isStrict => true;

  /// Always 1; enforces a single row.
  IntColumn get singleton => integer().withDefault(const Constant(1))();

  /// Client-generated random UUIDv4 install ID (future device_id).
  TextColumn get installId => text()();

  IntColumn get createdAtUtcMicros => integer()();

  /// Last assigned device sequence number; 0 before the first event.
  IntColumn get lastDeviceSeq => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {singleton};

  @override
  List<String> get customConstraints => const [
    'CHECK (singleton = 1)',
    'CHECK (last_device_seq >= 0)',
    'CHECK (length(install_id) > 0)',
  ];
}

/// Local outbox: one immutable row per syncable local change (ADR-005,
/// OFFLINE_SYNC §3). Append-only, enforced by triggers in
/// `foundation_triggers.drift`. Only the sync bookkeeping columns
/// ([syncStatus], [attempts], [lastError], [nextAttemptAtUtcMicros]) may be
/// updated, and only by Phase 8. STRICT: no floating-point values.
@DataClassName('OutboxEventRow')
class OutboxEvents extends Table {
  @override
  String get tableName => 'outbox_events';

  @override
  bool get isStrict => true;

  /// Random UUIDv4. Identity only — never used for ordering (G37).
  TextColumn get eventId => text()();

  TextColumn get idempotencyKey => text().unique()();

  TextColumn get shopId => text()();

  /// The install ID (P2-D5).
  TextColumn get deviceId => text()();

  TextColumn get localSessionId => text()();

  /// Device-asserted for offline sessions (ADR-021).
  TextColumn get actorUserId => text()();

  /// Monotonic, gap-free per device; the only ordering of the outbox.
  IntColumn get deviceSeq => integer().unique()();

  TextColumn get eventType => text()();

  IntColumn get schemaVersion => integer()();

  /// Canonical JSON; money and quantities are integers (no floating point).
  TextColumn get payloadJson => text()();

  IntColumn get occurredAtUtcMicros => integer()();

  IntColumn get deviceUtcOffsetMinutes => integer()();

  /// Unknown (null) until a server exists (Phase 8).
  IntColumn get serverOffsetMillis => integer().nullable()();

  IntColumn get serverOffsetObservedAtUtcMicros => integer().nullable()();

  /// Validated in Dart (`TimeConfidence`); Phase 2 writes only `unknown`.
  TextColumn get timeConfidence => text()();

  TextColumn get syncStatus => text().withDefault(const Constant('PENDING'))();

  IntColumn get attempts => integer().withDefault(const Constant(0))();

  TextColumn get lastError => text().nullable()();

  IntColumn get nextAttemptAtUtcMicros => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {eventId};

  @override
  List<String> get customConstraints => const [
    'CHECK (device_seq > 0)',
    'CHECK (schema_version > 0)',
    'CHECK (attempts >= 0)',
    'CHECK (length(event_id) > 0)',
    'CHECK (length(idempotency_key) > 0)',
    'CHECK (length(shop_id) > 0)',
    'CHECK (length(device_id) > 0)',
    'CHECK (length(local_session_id) > 0)',
    'CHECK (length(actor_user_id) > 0)',
    'CHECK (length(event_type) > 0)',
    'CHECK (length(time_confidence) > 0)',
    "CHECK (sync_status IN ('PENDING', 'IN_FLIGHT', 'ACKED', 'REJECTED', "
        "'CONFLICT'))",
  ];
}
