import 'dart:convert';

import 'package:dokan_pro/core/database/outbox/outbox_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes integers, strings, bools, nulls, lists and maps', () {
    final payload = <String, Object?>{
      'paisa': 12550,
      'subunits': 750,
      'name': 'x',
      'flag': true,
      'none': null,
      'items': [
        1,
        {'nested': 'ok'},
      ],
    };
    expect(jsonDecode(encodeOutboxPayload(payload)), payload);
  });

  test('rejects floating point anywhere, including NaN and Infinity', () {
    for (final payload in <Map<String, Object?>>[
      {'amount': 125.5},
      {'amount': 1.0},
      {'nan': double.nan},
      {'inf': double.infinity},
      {
        'items': [1, 2.5],
      },
      {
        'nested': {'deep': 0.1},
      },
    ]) {
      expect(
        () => encodeOutboxPayload(payload),
        throwsA(isA<OutboxValidationException>()),
        reason: '$payload',
      );
    }
  });

  test('rejects unsupported types and non-string keys', () {
    expect(
      () => encodeOutboxPayload({'when': DateTime(2026)}),
      throwsA(isA<OutboxValidationException>()),
    );
    expect(
      () => encodeOutboxPayload({
        'map': {1: 'x'},
      }),
      throwsA(isA<OutboxValidationException>()),
    );
  });
}
