import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../local_data_failure.dart';
import 'database_key.dart';

/// The cipher scheme configured in SQLite3 Multiple Ciphers: SQLCipher 4
/// compatible (ADR-029).
const String expectedCipher = 'sqlcipher';

/// The 16-byte header of an unencrypted SQLite database file.
const String plaintextSqliteHeader = 'SQLite format 3\u0000';

/// Configures a freshly opened raw connection for encryption and verifies it.
/// It must run before any other statement on the connection (ADR-027,
/// ADR-029 Part 3):
///
/// 1. select the SQLCipher-4-compatible scheme (`cipher`, `legacy = 4`);
/// 2. apply the raw 256-bit key (no KDF);
/// 3. require `PRAGMA cipher` to report the expected cipher (plain SQLite
///    returns nothing) — otherwise [EncryptionNotActive];
/// 4. perform a real read so a wrong key fails — [LocalDataUnavailable].
///
/// Errors never include the key: SQLite exceptions (which may quote the
/// failing statement) are replaced by typed failures without a cause.
void configureEncryptedConnection(Database raw, DatabaseKey key) {
  final hex = key.toHex();
  if (hex.isEmpty) {
    // Unreachable for a valid DatabaseKey; SQLite3MC treats an empty key as
    // "no encryption", so this is guarded explicitly.
    throw const EncryptionNotActive('empty key');
  }

  try {
    raw.execute("PRAGMA cipher = '$expectedCipher';");
    raw.execute('PRAGMA legacy = 4;');
  } on SqliteException {
    throw const EncryptionNotActive('cipher configuration failed');
  }

  try {
    raw.execute('PRAGMA key = "x\'$hex\'";');
  } on SqliteException {
    throw const EncryptionNotActive('applying the key failed');
  }

  final String? cipher;
  try {
    final rows = raw.select('PRAGMA cipher;');
    cipher = rows.isEmpty ? null : rows.first.values.first as String?;
  } on SqliteException {
    throw const EncryptionNotActive('cipher pragma unavailable');
  }
  if (cipher != expectedCipher) {
    throw const EncryptionNotActive('expected cipher is not active');
  }

  try {
    raw.select('SELECT count(*) FROM sqlite_master;');
  } on SqliteException {
    throw const LocalDataUnavailable(
      LocalDataUnavailableReason.wrongKeyOrUnreadableDatabase,
    );
  }

  raw.execute('PRAGMA foreign_keys = ON;');
}

/// True if [file]'s first 16 bytes are the plaintext SQLite header.
bool hasPlaintextSqliteHeader(File file) {
  if (!file.existsSync() || file.lengthSync() < 16) return false;
  final handle = file.openSync();
  try {
    final header = handle.readSync(16);
    return String.fromCharCodes(header) == plaintextSqliteHeader;
  } finally {
    handle.closeSync();
  }
}
