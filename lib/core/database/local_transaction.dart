import 'app_database.dart';

/// Proof that code runs inside a local database transaction.
///
/// Only [LocalTransactionRunner] can create one, so APIs that must be atomic
/// with business writes (e.g. `OutboxWriter.append`) take it as a parameter:
/// writing outside a transaction is impossible at the type level (ADR-005, G02).
final class LocalWriteContext {
  LocalWriteContext._(this.database);

  final AppDatabase database;

  bool _active = true;

  /// False once the transaction callback has finished.
  bool get isActive => _active;
}

/// Runs local writes in a single atomic transaction: business rows, outbox
/// event and device sequence all commit together or not at all.
class LocalTransactionRunner {
  const LocalTransactionRunner(this._database);

  final AppDatabase _database;

  Future<T> run<T>(Future<T> Function(LocalWriteContext context) action) {
    return _database.transaction(() async {
      final context = LocalWriteContext._(_database);
      try {
        return await action(context);
      } finally {
        context._active = false;
      }
    });
  }
}
