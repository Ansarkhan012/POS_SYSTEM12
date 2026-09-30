import 'dart:convert';

/// Thrown when an outbox event or payload is invalid. Nothing is written.
final class OutboxValidationException implements Exception {
  const OutboxValidationException(this.message);

  final String message;

  @override
  String toString() => 'OutboxValidationException: $message';
}

/// Encodes [payload] as JSON after rejecting anything that is not null, bool,
/// int, String, a list, or a string-keyed map. In particular any `double`
/// (including NaN/Infinity) is rejected: money is integer paisa and quantities
/// are integer subunits (ADR-008, ADR-015, GOTCHAS G18).
String encodeOutboxPayload(Map<String, Object?> payload) {
  _validate(payload, r'$');
  return jsonEncode(payload);
}

void _validate(Object? value, String path) {
  switch (value) {
    case null || bool() || int() || String():
      return;
    case double():
      throw OutboxValidationException('floating-point value at $path');
    case List<Object?>():
      for (var i = 0; i < value.length; i++) {
        _validate(value[i], '$path[$i]');
      }
    case Map<Object?, Object?>():
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String) {
          throw OutboxValidationException('non-string key at $path');
        }
        _validate(entry.value, '$path.$key');
      }
    default:
      throw OutboxValidationException(
        'unsupported ${value.runtimeType} at $path',
      );
  }
}
