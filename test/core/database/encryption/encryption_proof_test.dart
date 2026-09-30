import 'dart:convert';
import 'dart:io';

import 'package:dokan_pro/core/database/encryption/encrypted_connection.dart';
import 'package:dokan_pro/core/database/local_transaction.dart';
import 'package:dokan_pro/core/database/outbox/outbox_reader.dart';
import 'package:dokan_pro/core/database/outbox/outbox_writer.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../database_test_support.dart';

/// Independent proofs that the database is actually encrypted (ADR-027,
/// ADR-029 Part 3). Configuration alone is never treated as proof.
void main() {
  late TestDatabaseEnvironment env;

  setUp(() async => env = await TestDatabaseEnvironment.create());

  Future<void> writeMarker(String marker) async {
    final db = await env.open();
    final writer = OutboxWriter(ids: env.ids, clock: env.clock);
    await LocalTransactionRunner(
      db,
    ).run((ctx) => writer.append(ctx, testDraft(payload: {'marker': marker})));
    await env.close(db);
  }

  test('the SQLite3 Multiple Ciphers engine reports the SQLCipher scheme', () {
    final raw = sqlite3.openInMemory();
    addTearDown(raw.close);
    final rows = raw.select("PRAGMA cipher = 'sqlcipher';");
    expect(rows, isNotEmpty, reason: 'plain SQLite has no cipher pragma');
    expect(rows.first.values.first, 'sqlcipher');
  });

  test('database file header is not the plaintext SQLite header', () async {
    await writeMarker('header-check');
    final header = env.databaseFile.readAsBytesSync().sublist(0, 16);
    expect(String.fromCharCodes(header), isNot(plaintextSqliteHeader));
    expect(hasPlaintextSqliteHeader(env.databaseFile), isFalse);
  });

  test('database cannot be read without the key', () async {
    await writeMarker('no-key');
    final raw = sqlite3.open(env.databaseFile.path);
    addTearDown(raw.close);
    expect(
      () => raw.select('SELECT count(*) FROM sqlite_master;'),
      throwsA(isA<SqliteException>()),
    );
  });

  test('database cannot be read with a wrong key', () async {
    await writeMarker('wrong-key');
    final raw = sqlite3.open(env.databaseFile.path);
    addTearDown(raw.close);
    raw
      ..execute("PRAGMA cipher = 'sqlcipher';")
      ..execute('PRAGMA legacy = 4;')
      ..execute('PRAGMA key = "x\'${'ab' * 32}\'";');
    expect(
      () => raw.select('SELECT count(*) FROM sqlite_master;'),
      throwsA(isA<SqliteException>()),
    );
  });

  test(
    'a plaintext marker never appears in raw DB, journal or WAL bytes',
    () async {
      const marker = 'DOKAN-PRO-PLAINTEXT-MARKER-7f3e9c1a';
      final markerBytes = utf8.encode(marker);

      final db = await env.open();
      final writer = OutboxWriter(ids: env.ids, clock: env.clock);
      final runner = LocalTransactionRunner(db);
      await db.customStatement(
        'CREATE TABLE test_marker (id INTEGER PRIMARY KEY, text TEXT NOT NULL) '
        'STRICT',
      );
      await runner.run((ctx) async {
        await writer.append(ctx, testDraft(payload: {'marker': marker}));
        await db.customInsert(
          'INSERT INTO test_marker (id, text) VALUES (1, ?)',
          variables: [const Variable<String>(marker)],
        );
      });

      // While a transaction rewrites the page holding the marker, the rollback
      // journal holds the original page: it must be encrypted too.
      var journalChecked = false;
      await runner.run((ctx) async {
        await db.customUpdate(
          "UPDATE test_marker SET text = 'replaced' WHERE id = 1",
        );
        for (final entry in env.rawFiles().entries) {
          expect(
            containsBytes(entry.value, markerBytes),
            isFalse,
            reason: 'marker found in "${entry.key}" file during transaction',
          );
          if (entry.key != '') journalChecked = true;
        }
      });
      await env.close(db);

      for (final entry in env.rawFiles().entries) {
        expect(
          containsBytes(entry.value, markerBytes),
          isFalse,
          reason: 'marker found in "${entry.key}" file after close',
        );
      }
      expect(journalChecked, isTrue, reason: 'a journal file should exist');
    },
  );

  test('the correct key reopens the database and reads the data', () async {
    await writeMarker('reopen-marker');
    final db = await env.open();
    final events = await OutboxReader(db).eventsInDeviceSeqOrder();
    expect(events, hasLength(1));
    expect(jsonDecode(events.single.payloadJson), {'marker': 'reopen-marker'});
    await env.close(db);
  });

  test('the key in secure storage is 64 hex characters (256 bits)', () async {
    await writeMarker('key-shape');
    expect(env.storedKeyHex, matches(RegExp(r'^[0-9a-f]{64}$')));
    // The key is not stored in, next to, or alongside the database files.
    for (final entity in env.directory.listSync(recursive: true)) {
      if (entity is File) {
        expect(
          containsBytes(
            entity.readAsBytesSync(),
            utf8.encode(env.storedKeyHex),
          ),
          isFalse,
          reason: 'key hex found in ${entity.path}',
        );
      }
    }
  });

  test('journal mode keeps no plaintext side files after close', () async {
    await writeMarker('side-files');
    final leftovers = env.rawFiles().keys.where((suffix) => suffix != '');
    expect(leftovers, isEmpty);
    expect(File('${env.databaseFile.path}-wal').existsSync(), isFalse);
  });
}
