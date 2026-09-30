import 'dart:math';

import 'package:dokan_pro/core/identifiers/uuid_v4.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UuidV4Generator', () {
    test('produces RFC 4122 version-4 IDs', () {
      final generator = UuidV4Generator();
      for (var i = 0; i < 1000; i++) {
        final id = generator.next();
        expect(isUuidV4(id), isTrue, reason: id);
        expect(id[14], '4'); // version nibble
        expect('89ab'.contains(id[19]), isTrue); // variant bits 10xx
      }
    });

    test('IDs are unique over 100k draws', () {
      final generator = UuidV4Generator();
      final ids = <String>{for (var i = 0; i < 100000; i++) generator.next()};
      expect(ids, hasLength(100000));
    });

    test('an injected random source makes output deterministic', () {
      final a = UuidV4Generator(random: Random(42));
      final b = UuidV4Generator(random: Random(42));
      expect(a.next(), b.next());
    });

    test('isUuidV4 rejects other formats', () {
      for (final bad in [
        '',
        'not-a-uuid',
        '123e4567-e89b-12d3-a456-426614174000', // version 1
        '123E4567-E89B-42D3-A456-426614174000', // uppercase
        '123e4567-e89b-42d3-c456-426614174000', // wrong variant
      ]) {
        expect(isUuidV4(bad), isFalse, reason: bad);
      }
    });
  });
}
