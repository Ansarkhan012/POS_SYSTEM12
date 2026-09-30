import 'dart:io';
import 'dart:math';

import 'package:dokan_pro/core/database/app_database.dart';
import 'package:dokan_pro/core/database/encryption/database_key.dart';
import 'package:dokan_pro/core/database/encryption/encrypted_connection.dart';
import 'package:dokan_pro/core/identifiers/uuid_v4.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as raw_sqlite;

import 'database_test_support.dart';
import 'generated/schema.dart';

/// Schema and migration tests run exclusively on **encrypted files** (same
/// engine, scheme and raw-key configuration as production). Drift's in-memory
/// `SchemaVerifier` is not used: SQLite3 Multiple Ciphers cannot key an
/// in-memory database, and unkeyed test databases are not allowed.

QueryExecutor _encryptedExecutor(File file, DatabaseKey key) => NativeDatabase(
  file,
  setup: (raw) => configureEncryptedConnection(raw, key),
);

/// Structural description of a schema: tables (incl. STRICT), columns,
/// indexes, and whitespace-normalized table/trigger SQL (covers CHECKs).
Future<Map<String, Object?>> _describe(GeneratedDatabase db) async {
  // Whitespace and identifier quoting are formatting, not schema: Drift quotes
  // primary-key columns differently in generated reference schemas.
  String normalize(String? sql) =>
      (sql ?? '').replaceAll(RegExp(r'\s+'), '').replaceAll('"', '');
  Future<List<Map<String, Object?>>> rows(String sql) async => [
    for (final r in await db.customSelect(sql).get()) r.data,
  ];

  final description = <String, Object?>{};
  final entities = await rows(
    "SELECT type, name, sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' "
    'ORDER BY type, name',
  );
  for (final entity in entities) {
    final type = entity['type']! as String;
    final name = entity['name']! as String;
    description['$type:$name:sql'] = normalize(entity['sql'] as String?);
    if (type == 'table') {
      description['table:$name:columns'] = await rows(
        "PRAGMA table_info('$name')",
      );
      description['table:$name:indexes'] = await rows(
        "PRAGMA index_list('$name')",
      );
      description['table:$name:strict'] = (await rows(
        "PRAGMA table_list('$name')",
      )).single['strict'];
    }
  }
  return description;
}

void main() {
  late TestDatabaseEnvironment env;

  setUp(() async => env = await TestDatabaseEnvironment.create());

  /// Creates an encrypted database at [version] from the committed dump.
  Future<File> referenceAt(int version, DatabaseKey key) async {
    final file = File('${env.directory.path}/reference_v$version.db');
    final db = GeneratedHelper().databaseForVersion(
      _encryptedExecutor(file, key),
      version,
    );
    await db.customSelect('SELECT 1').get();
    await db.close();
    expect(hasPlaintextSqliteHeader(file), isFalse);
    return file;
  }

  Future<Map<String, Object?>> describeReference(
    File file,
    DatabaseKey key,
  ) async {
    final db = GeneratedHelper().databaseForVersion(
      _encryptedExecutor(file, key),
      AppDatabase.currentSchemaVersion,
    );
    final description = await _describe(db);
    await db.close();
    return description;
  }

  test('the committed schema dump is at the current schema version', () {
    expect(GeneratedHelper.versions.last, AppDatabase.currentSchemaVersion);
    expect(AppDatabase.currentSchemaVersion, 1);
  });

  test('a fresh encrypted app database matches the committed dump', () async {
    final key = DatabaseKey.generate(Random.secure());
    final reference = await describeReference(
      await referenceAt(AppDatabase.currentSchemaVersion, key),
      key,
    );

    final db = await env.open();
    expect(await _describe(db), reference);
    expect(hasPlaintextSqliteHeader(env.databaseFile), isFalse);
  });

  test(
    'every dumped version upgrades to the current schema (encrypted)',
    () async {
      final key = DatabaseKey.generate(Random.secure());
      final expected = await describeReference(
        await referenceAt(AppDatabase.currentSchemaVersion, key),
        key,
      );

      for (final version in GeneratedHelper.versions) {
        final file = File('${env.directory.path}/upgrade_from_v$version.db');
        final old = GeneratedHelper().databaseForVersion(
          _encryptedExecutor(file, key),
          version,
        );
        await old.customSelect('SELECT 1').get();
        await old.close();

        final upgraded = AppDatabase(
          _encryptedExecutor(file, key),
          ids: UuidV4Generator(),
          clock: FixedDeviceClock(),
        );
        expect(await _describe(upgraded), expected, reason: 'from v$version');
        final userVersion = await upgraded
            .customSelect('PRAGMA user_version')
            .getSingle();
        expect(
          userVersion.data.values.single,
          AppDatabase.currentSchemaVersion,
        );
        await upgraded.close();
        expect(hasPlaintextSqliteHeader(file), isFalse);
      }
    },
  );

  test('schema v1 contains only the foundation tables and triggers', () async {
    final db = await env.open();
    final rows = await db
        .customSelect(
          "SELECT type, name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'",
        )
        .get();
    expect(
      {for (final row in rows) '${row.data['type']}:${row.data['name']}'},
      {
        'table:device_identity',
        'table:outbox_events',
        'trigger:device_identity_immutable',
        'trigger:device_identity_no_delete',
        'trigger:device_identity_sequence_monotonic',
        'trigger:outbox_events_envelope_immutable',
        'trigger:outbox_events_no_delete',
      },
    );
  });

  test('both foundation tables are STRICT', () async {
    final db = await env.open();
    for (final table in ['device_identity', 'outbox_events']) {
      final info = await db
          .customSelect("PRAGMA table_list('$table')")
          .getSingle();
      expect(info.data['strict'], 1, reason: table);
    }
  });

  test('foreign keys are enforced on every connection', () async {
    final db = await env.open();
    final result = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(result.data.values.single, 1);
  });

  test(
    'an unknown schema version fails closed without touching data',
    () async {
      final created = await env.open();
      await env.close(created);

      // Pretend the file came from a newer app version (downgrade).
      final key = DatabaseKey.fromStoredHex(env.storedKeyHex);
      final raw = raw_sqlite.sqlite3.open(env.databaseFile.path);
      configureEncryptedConnection(raw, key);
      raw
        ..execute('PRAGMA user_version = 2;')
        ..close();
      final before = env.databaseFile.readAsBytesSync().toList();

      await expectLater(
        env.opener().open(),
        throwsA(
          predicate(
            (Object e) => e.toString().contains('No migration from schema v2'),
          ),
        ),
      );
      expect(env.databaseFile.readAsBytesSync().toList(), before);
    },
  );
}
