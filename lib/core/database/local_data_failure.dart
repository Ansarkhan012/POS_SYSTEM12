/// Typed failures of the local data foundation. Messages never contain key
/// material.
sealed class LocalDataFailure implements Exception {
  const LocalDataFailure();

  String get message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Why local data cannot be opened. The existing database file is always left
/// untouched (P2-D3); there is no recovery key (ADR-027).
enum LocalDataUnavailableReason {
  /// An encrypted database exists but its key is absent from secure storage.
  keyMissing,

  /// The stored key is malformed.
  keyCorrupt,

  /// The key did not decrypt the database (wrong key or corrupt file).
  wrongKeyOrUnreadableDatabase,
}

final class LocalDataUnavailable extends LocalDataFailure {
  const LocalDataUnavailable(this.reason);

  final LocalDataUnavailableReason reason;

  @override
  String get message =>
      'Local data is unavailable (${reason.name}). '
      'The encrypted database was left untouched.';
}

/// Platform secure storage could not be read or written.
final class SecureStorageUnavailable extends LocalDataFailure {
  const SecureStorageUnavailable();

  @override
  String get message => 'Platform secure storage is unavailable.';
}

/// The encrypted SQLite engine is not active, or the file is not encrypted.
/// Nothing is written when this is raised.
final class EncryptionNotActive extends LocalDataFailure {
  const EncryptionNotActive(this.detail);

  final String detail;

  @override
  String get message => 'Database encryption is not active: $detail';
}
