import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:dokan_pro/core/database/app_database.dart';
import 'package:dokan_pro/core/database/device/device_identity_reader.dart';
import 'package:dokan_pro/core/database/encryption/database_key.dart';
import 'package:dokan_pro/core/database/encryption/encrypted_connection.dart';
import 'package:dokan_pro/core/database/local_transaction.dart';
import 'package:dokan_pro/core/database/outbox/outbox_event_draft.dart';
import 'package:dokan_pro/core/database/outbox/outbox_payload.dart';
import 'package:dokan_pro/core/database/outbox/outbox_reader.dart';
import 'package:dokan_pro/core/database/outbox/outbox_writer.dart';
import 'package:dokan_pro/core/identifiers/uuid_v4.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as raw_sqlite;

import '../database_test_support.dart';

/// Test-only "business" table: exists only in test databases, never in the
/// production schema.
const _createTestBusinessTable =
    'CREATE TABLE IF NOT EXISTS test_business_rows '
    '(id TEXT PRIMARY KEY, label TEXT NOT NULL) STRICT';

Matcher _failsWith(String text) =>
    throwsA(predicate((Object e) => e.toString().contains(text), text));

void main() {
  late TestDatabaseEnvironment env;
  late AppDatabase db;
  late OutboxWriter writer;
  late LocalTransactionRunner runner;

  setUp(() async {
    env = await TestDatabaseEnvironment.create();
    db = await env.open();
    writer = OutboxWriter(ids: env.ids, clock: env.clock);
    runner = LocalTransactionRunner(db);
    await db.customStatement(_createTestBusinessTable);
  });

  Future<List<OutboxEventRow>> events() =>
      OutboxReader(db).eventsInDeviceSeqOrder();

  Future<int> lastSeq() async =>
      (await db.select(db.deviceIdentity).getSingle()).lastDeviceSeq;

  Future<int> businessRows() async =>
      (await db
              .customSelect('SELECT count(*) AS c FROM test_business_rows')
              .getSingle())
          .read<int>('c');

  group('envelope', () {
    test('append writes a complete PENDING envelope', () async {
      env.clock
        ..utcMicros = 1759300000123456
        ..offsetMinutes = 300;
      final row = await runner.run(
        (ctx) => writer.append(
          ctx,
          testDraft(eventType: 'test.created', payload: {'paisa': 12550}),
        ),
      );

      expect(isUuidV4(row.eventId), isTrue);
      expect(row.idempotencyKey, row.eventId);
      expect(row.deviceId, await DeviceIdentityReader(db).installId());
      expect(row.deviceSeq, 1);
      expect(row.shopId, 'test-shop');
      expect(row.localSessionId, 'test-session');
      expect(row.actorUserId, 'test-actor');
      expect(row.eventType, 'test.created');
      expect(row.schemaVersion, 1);
      expect(jsonDecode(row.payloadJson), {'paisa': 12550});
      expect(row.occurredAtUtcMicros, 1759300000123456);
      expect(row.deviceUtcOffsetMinutes, 300);
      expect(row.serverOffsetMillis, isNull);
      expect(row.serverOffsetObservedAtUtcMicros, isNull);
      expect(row.timeConfidence, TimeConfidence.unknown.name);
      expect(row.syncStatus, 'PENDING');
      expect(row.attempts, 0);
      expect(row.lastError, isNull);
      expect(row.nextAttemptAtUtcMicros, isNull);
    });

    test(
      'a supplied idempotency key is kept; duplicates are rejected',
      () async {
        await runner.run(
          (ctx) => writer.append(ctx, testDraft(idempotencyKey: 'same-key')),
        );
        await expectLater(
          runner.run(
            (ctx) => writer.append(ctx, testDraft(idempotencyKey: 'same-key')),
          ),
          _failsWith('UNIQUE'),
        );
        expect(await events(), hasLength(1));
        expect(await lastSeq(), 1, reason: 'rolled back: no sequence consumed');
      },
    );

    test('invalid drafts are rejected before anything is written', () async {
      final invalid = <OutboxEventDraft>[
        testDraft(eventType: ' '),
        const OutboxEventDraft(
          eventType: 'x',
          schemaVersion: 0,
          payload: {},
          shopId: 's',
          localSessionId: 'l',
          actorUserId: 'a',
        ),
        const OutboxEventDraft(
          eventType: 'x',
          schemaVersion: 1,
          payload: {},
          shopId: '',
          localSessionId: 'l',
          actorUserId: 'a',
        ),
        const OutboxEventDraft(
          eventType: 'x',
          schemaVersion: 1,
          payload: {},
          shopId: 's',
          localSessionId: '',
          actorUserId: 'a',
        ),
        const OutboxEventDraft(
          eventType: 'x',
          schemaVersion: 1,
          payload: {},
          shopId: 's',
          localSessionId: 'l',
          actorUserId: '',
        ),
        testDraft(idempotencyKey: ''),
        testDraft(payload: {'amount': 1.5}),
      ];
      for (final draft in invalid) {
        await expectLater(
          runner.run((ctx) => writer.append(ctx, draft)),
          throwsA(isA<OutboxValidationException>()),
        );
      }
      expect(await events(), isEmpty);
      expect(await lastSeq(), 0);
    });

    test('appending outside the transaction is refused', () async {
      late LocalWriteContext escaped;
      await runner.run((ctx) async => escaped = ctx);
      expect(escaped.isActive, isFalse);
      await expectLater(
        writer.append(escaped, testDraft()),
        throwsA(isA<StateError>()),
      );
      expect(await events(), isEmpty);
    });
  });

  group('atomic write (business row + outbox + device sequence)', () {
    Future<void> writeBusinessRowWithEvent(String id, {bool fail = false}) =>
        runner.run((ctx) async {
          await db.customInsert(
            'INSERT INTO test_business_rows (id, label) VALUES (?, ?)',
            variables: [Variable<String>(id), const Variable<String>('row')],
          );
          await writer.append(ctx, testDraft(payload: {'row': id}));
          if (fail) throw StateError('simulated failure after both writes');
        });

    test('commit persists both', () async {
      await writeBusinessRowWithEvent('a');
      expect(await businessRows(), 1);
      expect(await events(), hasLength(1));
      expect(await lastSeq(), 1);
    });

    test('an exception persists neither and consumes no sequence', () async {
      await expectLater(
        writeBusinessRowWithEvent('a', fail: true),
        throwsA(isA<StateError>()),
      );
      expect(await businessRows(), 0);
      expect(await events(), isEmpty);
      expect(await lastSeq(), 0);

      await writeBusinessRowWithEvent('b');
      expect((await events()).single.deviceSeq, 1, reason: 'gap-free');
    });

    test(
      'state is consistent after close and reopen following an abort',
      () async {
        await writeBusinessRowWithEvent('a');
        await expectLater(
          writeBusinessRowWithEvent('b', fail: true),
          throwsA(isA<StateError>()),
        );
        await env.close(db);

        db = await env.open();
        runner = LocalTransactionRunner(db);
        expect(await businessRows(), 1);
        expect(await events(), hasLength(1));
        expect(await lastSeq(), 1);
        await writeBusinessRowWithEvent('c');
        expect((await events()).map((e) => e.deviceSeq), [1, 2]);
      },
    );

    test('a killed writer isolate leaves no partial data', () async {
      final keyHex = env.storedKeyHex;
      final path = env.databaseFile.path;
      final ready = ReceivePort();
      final isolate = await Isolate.spawn<List<Object>>(
        _writeWithoutCommitting,
        [path, keyHex, ready.sendPort],
      );
      await ready.first; // Uncommitted writes are now pending in the isolate.
      isolate.kill(priority: Isolate.immediate);

      // The committed state is unaffected by the killed, uncommitted work.
      expect(await businessRows(), 0);
      expect(await events(), isEmpty);
      expect(await lastSeq(), 0);
      final integrity = await db.customSelect('PRAGMA integrity_check').get();
      expect(integrity.single.data.values.single, 'ok');
    });
  });

  group('device sequence', () {
    test('is strictly increasing and gap-free over 1000 appends', () async {
      for (var i = 0; i < 1000; i++) {
        await runner.run((ctx) => writer.append(ctx, testDraft()));
      }
      final seqs = (await events()).map((e) => e.deviceSeq).toList();
      expect(seqs, List<int>.generate(1000, (i) => i + 1));
    });

    test('stays unique and gap-free under concurrent transactions', () async {
      await Future.wait([
        for (var i = 0; i < 200; i++)
          runner.run((ctx) => writer.append(ctx, testDraft())),
      ]);
      final seqs = (await events()).map((e) => e.deviceSeq).toList();
      expect(seqs, List<int>.generate(200, (i) => i + 1));
      expect(await lastSeq(), 200);
    });

    test('continues after reopen', () async {
      await runner.run((ctx) => writer.append(ctx, testDraft()));
      await env.close(db);
      db = await env.open();
      runner = LocalTransactionRunner(db);
      final row = await runner.run((ctx) => writer.append(ctx, testDraft()));
      expect(row.deviceSeq, 2);
    });

    test('read order is device_seq only, not IDs or times', () async {
      env.clock.utcMicros = 3000;
      await runner.run((ctx) => writer.append(ctx, testDraft(eventType: 'a')));
      env.clock.utcMicros = 1000; // device clock moved backwards
      await runner.run((ctx) => writer.append(ctx, testDraft(eventType: 'b')));
      env.clock.utcMicros = 2000;
      await runner.run((ctx) => writer.append(ctx, testDraft(eventType: 'c')));
      expect((await events()).map((e) => e.eventType), ['a', 'b', 'c']);
    });
  });

  group('database-enforced integrity', () {
    setUp(() async {
      await runner.run((ctx) => writer.append(ctx, testDraft()));
    });

    test('outbox rows cannot be deleted, even with raw SQL', () async {
      await expectLater(
        db.delete(db.outboxEvents).go(),
        _failsWith('append-only'),
      );
      await expectLater(
        db.customStatement('DELETE FROM outbox_events'),
        _failsWith('append-only'),
      );
      expect(await events(), hasLength(1));
    });

    test('envelope columns cannot be updated', () async {
      for (final column in [
        "payload_json = '{}'",
        'device_seq = 99',
        "shop_id = 'other'",
        "event_id = 'x'",
        'occurred_at_utc_micros = 0',
        "time_confidence = 'x'",
      ]) {
        await expectLater(
          db.customStatement('UPDATE outbox_events SET $column'),
          _failsWith('immutable'),
          reason: column,
        );
      }
    });

    test('sync bookkeeping columns remain updatable for Phase 8', () async {
      await db.customStatement(
        "UPDATE outbox_events SET sync_status = 'IN_FLIGHT', attempts = 1",
      );
      expect((await events()).single.syncStatus, 'IN_FLIGHT');
    });

    test('CHECK and STRICT constraints reject invalid values', () async {
      for (final statement in [
        "UPDATE outbox_events SET sync_status = 'DONE'",
        'UPDATE outbox_events SET attempts = -1',
        'UPDATE outbox_events SET attempts = 1.5',
      ]) {
        await expectLater(
          db.customStatement(statement),
          throwsA(isA<Object>()),
          reason: statement,
        );
      }
      final row = (await events()).single;
      await expectLater(
        db.customStatement(
          'INSERT INTO outbox_events (event_id, idempotency_key, shop_id, '
          'device_id, local_session_id, actor_user_id, device_seq, event_type, '
          'schema_version, payload_json, occurred_at_utc_micros, '
          'device_utc_offset_minutes, time_confidence) VALUES '
          "('e2', 'k2', 's', '${row.deviceId}', 'l', 'a', 0, 't', 1, '{}', "
          "0, 0, 'unknown')",
        ),
        _failsWith('CHECK'),
      );
      await expectLater(
        db.customStatement(
          'INSERT INTO outbox_events (event_id, idempotency_key, shop_id, '
          'device_id, local_session_id, actor_user_id, device_seq, event_type, '
          'schema_version, payload_json, occurred_at_utc_micros, '
          'device_utc_offset_minutes, time_confidence) VALUES '
          "('e3', 'k3', 's', 'd', 'l', 'a', 2.5, 't', 1, '{}', 0, 0, "
          "'unknown')",
        ),
        throwsA(isA<Object>()),
        reason: 'STRICT table rejects a REAL device_seq',
      );
    });

    test('device identity cannot be deleted, re-keyed or rewound', () async {
      await expectLater(
        db.customStatement('DELETE FROM device_identity'),
        _failsWith('must not be deleted'),
      );
      await expectLater(
        db.customStatement("UPDATE device_identity SET install_id = 'x'"),
        _failsWith('immutable'),
      );
      await expectLater(
        db.customStatement('UPDATE device_identity SET last_device_seq = 0'),
        _failsWith('must not decrease'),
      );
      await expectLater(
        db.customStatement(
          'INSERT INTO device_identity (singleton, install_id, '
          "created_at_utc_micros) VALUES (2, 'x', 0)",
        ),
        throwsA(isA<Object>()),
        reason: 'single-row table',
      );
    });
  });
}

/// Runs in a separate isolate: opens its own encrypted connection, starts a
/// transaction, writes a business row, an outbox row and a sequence bump, then
/// signals and waits to be killed without committing.
Future<void> _writeWithoutCommitting(List<Object> args) async {
  final path = args[0] as String;
  final keyHex = args[1] as String;
  final ready = args[2] as SendPort;
  final raw = raw_sqlite.sqlite3.open(path);
  configureEncryptedConnection(raw, DatabaseKey.fromStoredHex(keyHex));
  raw
    ..execute('BEGIN IMMEDIATE')
    ..execute("INSERT INTO test_business_rows (id, label) VALUES ('k', 'x')")
    ..execute('UPDATE device_identity SET last_device_seq = 1')
    ..execute(
      'INSERT INTO outbox_events (event_id, idempotency_key, shop_id, '
      'device_id, local_session_id, actor_user_id, device_seq, event_type, '
      'schema_version, payload_json, occurred_at_utc_micros, '
      'device_utc_offset_minutes, time_confidence) SELECT '
      "'killed', 'killed', 's', install_id, 'l', 'a', 1, 't', 1, '{}', 0, 0, "
      "'unknown' FROM device_identity",
    );
  ready.send(true);
  await Completer<void>().future; // Never completes; the isolate is killed.
}
