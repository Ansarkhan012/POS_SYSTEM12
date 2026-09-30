import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Generates random RFC 4122 version-4 UUIDs (ADR-013).
///
/// IDs are identity, not chronology: never sort or order by them (GOTCHAS G37).
class UuidV4Generator {
  /// Uses [Random.secure] unless a [random] source is injected (tests only).
  UuidV4Generator({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  String next() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

final RegExp _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// True if [value] is a lowercase canonical UUIDv4 string.
bool isUuidV4(String value) => _uuidV4Pattern.hasMatch(value);

final uuidV4GeneratorProvider = Provider<UuidV4Generator>(
  (ref) => UuidV4Generator(),
);
