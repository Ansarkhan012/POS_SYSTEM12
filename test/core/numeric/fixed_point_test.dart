import 'package:dokan_pro/core/numeric/fixed_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const maxInt = 9223372036854775807;
  const minInt = -9223372036854775808;

  group('checked arithmetic', () {
    test('adds and subtracts within range', () {
      expect(checkedAdd(2, 3), 5);
      expect(checkedSubtract(2, 3), -1);
      expect(checkedAdd(maxInt - 1, 1), maxInt);
      expect(checkedSubtract(minInt + 1, 1), minInt);
    });

    test('throws instead of wrapping on overflow', () {
      expect(
        () => checkedAdd(maxInt, 1),
        throwsA(isA<FixedPointOverflowException>()),
      );
      expect(
        () => checkedAdd(minInt, -1),
        throwsA(isA<FixedPointOverflowException>()),
      );
      expect(
        () => checkedSubtract(minInt, 1),
        throwsA(isA<FixedPointOverflowException>()),
      );
      expect(
        () => checkedSubtract(maxInt, -1),
        throwsA(isA<FixedPointOverflowException>()),
      );
    });

    test('toInt64 enforces the signed 64-bit range', () {
      expect(toInt64(maxInt64, 'x'), maxInt);
      expect(toInt64(minInt64, 'x'), minInt);
      expect(
        () => toInt64(maxInt64 + BigInt.one, 'x'),
        throwsA(isA<FixedPointOverflowException>()),
      );
    });
  });

  group('divideRoundHalfAwayFromZero', () {
    BigInt div(int n, int d) =>
        divideRoundHalfAwayFromZero(BigInt.from(n), BigInt.from(d));

    test('rounds half away from zero for positive and negative values', () {
      expect(div(25, 10), BigInt.from(3));
      expect(div(-25, 10), BigInt.from(-3));
      expect(div(24, 10), BigInt.from(2));
      expect(div(-24, 10), BigInt.from(-2));
      expect(div(26, 10), BigInt.from(3));
      expect(div(-26, 10), BigInt.from(-3));
      expect(div(0, 10), BigInt.zero);
      expect(div(30, 10), BigInt.from(3));
    });

    test('rejects non-positive denominators', () {
      expect(() => div(1, 0), throwsArgumentError);
      expect(() => div(1, -1), throwsArgumentError);
    });
  });

  group('scaled decimal parsing and formatting', () {
    test('parses canonical decimals exactly', () {
      expect(parseScaledDecimal('125.50', fractionDigits: 2), 12550);
      expect(parseScaledDecimal('125.5', fractionDigits: 2), 12550);
      expect(parseScaledDecimal('-0.01', fractionDigits: 2), -1);
      expect(parseScaledDecimal('7', fractionDigits: 3), 7000);
    });

    test('rejects non-canonical input', () {
      for (final bad in [
        '',
        ' 1',
        '1 ',
        '+1',
        '1.',
        '.5',
        '1.234',
        '1,000',
        '1e3',
        'NaN',
        '١٢',
      ]) {
        expect(
          () => parseScaledDecimal(bad, fractionDigits: 2),
          throwsFormatException,
          reason: '"$bad" must be rejected',
        );
      }
    });

    test('rejects values beyond 64-bit range', () {
      expect(
        () => parseScaledDecimal('99999999999999999999', fractionDigits: 2),
        throwsA(isA<FixedPointOverflowException>()),
      );
    });

    test('formats canonically, including the minimum value', () {
      expect(formatScaledDecimal(12550, fractionDigits: 2), '125.50');
      expect(formatScaledDecimal(-1, fractionDigits: 2), '-0.01');
      expect(formatScaledDecimal(750, fractionDigits: 3), '0.750');
      expect(
        formatScaledDecimal(minInt, fractionDigits: 2),
        '-92233720368547758.08',
      );
    });
  });
}
