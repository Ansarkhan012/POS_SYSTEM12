import 'package:dokan_pro/core/numeric/fixed_point.dart';
import 'package:dokan_pro/core/quantity/quantity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Quantity', () {
    test('1 unit = 1000 subunits', () {
      expect(Quantity.units(1).subunits, 1000);
      expect(Quantity.units(2).subunits, 2000);
      expect(Quantity.subunitsPerUnit, 1000);
    });

    test('parses canonical decimals without floating point', () {
      expect(Quantity.parse('0.750').subunits, 750);
      expect(Quantity.parse('0.25').subunits, 250);
      expect(Quantity.parse('1').subunits, 1000);
      expect(Quantity.parse('2').subunits, 2000);
      expect(Quantity.parse('-1.5').subunits, -1500);
    });

    test('rejects more than 3 fraction digits and junk', () {
      for (final bad in ['0.0005', '1.2345', 'abc', '1kg', '']) {
        expect(() => Quantity.parse(bad), throwsFormatException, reason: bad);
      }
    });

    test('toDecimalString is canonical', () {
      expect(const Quantity.subunits(750).toDecimalString(), '0.750');
      expect(const Quantity.subunits(2000).toDecimalString(), '2.000');
    });

    test('requirePositive', () {
      expect(const Quantity.subunits(1).requirePositive().subunits, 1);
      expect(() => Quantity.zero.requirePositive(), throwsArgumentError);
      expect(
        () => const Quantity.subunits(-1000).requirePositive(),
        throwsArgumentError,
      );
    });

    test('arithmetic detects overflow', () {
      expect(
        const Quantity.subunits(750) + const Quantity.subunits(250),
        Quantity.units(1),
      );
      expect(
        () =>
            const Quantity.subunits(9223372036854775807) +
            const Quantity.subunits(1),
        throwsA(isA<FixedPointOverflowException>()),
      );
      expect(
        () => Quantity.units(9223372036854776),
        throwsA(isA<FixedPointOverflowException>()),
      );
    });
  });

  group('QuantityRule', () {
    test('wholeUnitsOnly rejects non-multiples of 1000', () {
      for (final bad in [1500, 250, 999, 1001, -1500]) {
        final quantity = Quantity.subunits(bad);
        expect(QuantityRule.wholeUnitsOnly.allows(quantity), isFalse);
        expect(
          () => QuantityRule.wholeUnitsOnly.validate(quantity),
          throwsA(isA<QuantityRuleViolation>()),
        );
      }
      for (final good in [0, 1000, 2000, -2000]) {
        expect(
          QuantityRule.wholeUnitsOnly.allows(Quantity.subunits(good)),
          isTrue,
        );
      }
    });

    test('fractionalAllowed accepts values below 1000', () {
      for (final value in [1, 250, 750, 999, 1500]) {
        final quantity = Quantity.subunits(value);
        expect(QuantityRule.fractionalAllowed.validate(quantity), quantity);
      }
    });
  });
}
