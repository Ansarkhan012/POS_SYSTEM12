import '../app_database.dart';

/// Reads the install ID (P2-D5): created once with the database, never
/// regenerated while the database exists.
class DeviceIdentityReader {
  const DeviceIdentityReader(this._database);

  final AppDatabase _database;

  Future<String> installId() async =>
      (await _database.select(_database.deviceIdentity).getSingle()).installId;
}
