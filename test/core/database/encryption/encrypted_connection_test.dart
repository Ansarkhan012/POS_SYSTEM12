import 'dart:math';

import 'package:dokan_pro/core/database/encryption/database_key.dart';
import 'package:dokan_pro/core/database/encryption/encrypted_connection.dart';
import 'package:dokan_pro/core/database/local_data_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Scripted stand-in for a raw connection, used only to exercise the
/// production guard in [configureEncryptedConnection] for engines that are
/// NOT encrypted — without ever opening plain SQLite.
class _ScriptedDatabase implements Database {
  _ScriptedDatabase({
    this.cipherRows = const [
      ['sqlcipher'],
    ],
    this.failOn,
    this.failRead = false,
  });

  final List<List<Object?>> cipherRows;
  final String? failOn;
  final bool failRead;
  final List<String> executed = [];

  SqliteException _error(String sql) => SqliteException(
    extendedResultCode: 1,
    message: 'scripted failure',
    causingStatement: sql,
  );

  @override
  void execute(String sql, [List<Object?> parameters = const []]) {
    executed.add(sql);
    if (failOn != null && sql.contains(failOn!)) throw _error(sql);
  }

  @override
  ResultSet select(String sql, [List<Object?> parameters = const []]) {
    executed.add(sql);
    if (sql.startsWith('PRAGMA cipher;')) {
      return ResultSet(['cipher'], null, cipherRows);
    }
    if (failRead) throw _error(sql);
    return ResultSet(
      ['count(*)'],
      null,
      [
        [0],
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final key = DatabaseKey.generate(Random.secure());

  test('configures scheme, then raw key, then verifies, then reads', () {
    final db = _ScriptedDatabase();
    configureEncryptedConnection(db, key);
    expect(db.executed, [
      "PRAGMA cipher = 'sqlcipher';",
      'PRAGMA legacy = 4;',
      'PRAGMA key = "x\'${key.toHex()}\'";',
      'PRAGMA cipher;',
      'SELECT count(*) FROM sqlite_master;',
      'PRAGMA foreign_keys = ON;',
    ]);
  });

  test('plain SQLite (no cipher pragma result) is refused', () {
    final db = _ScriptedDatabase(cipherRows: const []);
    expect(
      () => configureEncryptedConnection(db, key),
      throwsA(isA<EncryptionNotActive>()),
    );
    expect(db.executed, isNot(contains('SELECT count(*) FROM sqlite_master;')));
  });

  test('an unexpected cipher is refused', () {
    final db = _ScriptedDatabase(
      cipherRows: const [
        ['chacha20'],
      ],
    );
    expect(
      () => configureEncryptedConnection(db, key),
      throwsA(isA<EncryptionNotActive>()),
    );
  });

  test('a wrong key (failed read) is LocalDataUnavailable', () {
    final db = _ScriptedDatabase(failRead: true);
    expect(
      () => configureEncryptedConnection(db, key),
      throwsA(
        isA<LocalDataUnavailable>().having(
          (f) => f.reason,
          'reason',
          LocalDataUnavailableReason.wrongKeyOrUnreadableDatabase,
        ),
      ),
    );
  });

  test('a failing key PRAGMA never leaks the key through the error', () {
    final db = _ScriptedDatabase(failOn: 'PRAGMA key');
    try {
      configureEncryptedConnection(db, key);
      fail('expected a failure');
    } on EncryptionNotActive catch (failure) {
      expect(failure.toString(), isNot(contains(key.toHex())));
    }
  });

  test('a failing cipher configuration is refused', () {
    final db = _ScriptedDatabase(failOn: 'PRAGMA cipher =');
    expect(
      () => configureEncryptedConnection(db, key),
      throwsA(isA<EncryptionNotActive>()),
    );
  });
}
