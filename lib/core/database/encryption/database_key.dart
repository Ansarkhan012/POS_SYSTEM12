import 'dart:math';
import 'dart:typed_data';

/// A 256-bit database encryption key (ADR-027).
///
/// Generated only from a cryptographically secure RNG, never derived from a
/// PIN or any user input. [toString] never reveals the key.
final class DatabaseKey {
  DatabaseKey._(this._bytes);

  /// Generates a fresh key from [secureRandom] (must be [Random.secure] in
  /// production).
  factory DatabaseKey.generate(Random secureRandom) => DatabaseKey._(
    Uint8List.fromList(
      List<int>.generate(lengthInBytes, (_) => secureRandom.nextInt(256)),
    ),
  );

  /// Restores a key from its stored 64-character lowercase hex form.
  ///
  /// Throws [FormatException] (without echoing the input) if malformed.
  factory DatabaseKey.fromStoredHex(String stored) {
    if (!_storedHexPattern.hasMatch(stored)) {
      throw const FormatException('Stored database key is malformed');
    }
    final bytes = Uint8List(lengthInBytes);
    for (var i = 0; i < lengthInBytes; i++) {
      bytes[i] = int.parse(stored.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return DatabaseKey._(bytes);
  }

  static const int lengthInBytes = 32;

  static final RegExp _storedHexPattern = RegExp(r'^[0-9a-f]{64}$');

  final Uint8List _bytes;

  /// 64 lowercase hex characters; used for secure storage and the raw-key
  /// PRAGMA only. Never log it.
  String toHex() =>
      _bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  @override
  String toString() => 'DatabaseKey(<redacted>)';
}
