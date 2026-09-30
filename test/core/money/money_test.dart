import 'package:dokan_pro/core/money/money.dart';
import 'package:dokan_pro/core/numeric/fixed_point.dart';
import 'package:dokan_pro/core/quantity/quantity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Money line(int pricePaisa, int subunits) => Money.lineAmount(
    unitPrice: Money.paisa(pricePaisa),
    quantity: Quantity.subunits(subunits),
  );

  group('Money', () {
    test('stores integer paisa', () {
      expect(const Money.paisa(100).paisa, 100);
      expect(Money.parse('125.50').paisa, 12550);
      expect(Money.parse('1').paisa, 100);
    });

    test('adds, subtracts and negates with overflow detection', () {
      expect(
        const Money.paisa(150) + const Money.paisa(50),
        const Money.paisa(200),
      );
      expect(
        const Money.paisa(150) - const Money.paisa(200),
        const Money.paisa(-50),
      );
      expect(-const Money.paisa(5), const Money.paisa(-5));
      expect(
        () => const Money.paisa(9223372036854775807) + const Money.paisa(1),
        throwsA(isA<FixedPointOverflowException>()),
      );
      expect(
        () => -const Money.paisa(-9223372036854775808),
        throwsA(isA<FixedPointOverflowException>()),
      );
    });

    test('parsing rejects over-precision and junk', () {
      for (final bad in ['1.005', '12.3.4', 'Rs 5', '5.00 ', '']) {
        expect(() => Money.parse(bad), throwsFormatException, reason: bad);
      }
      expect(Money.parse('-125.50').paisa, -12550);
    });

    test('toDecimalString round-trips', () {
      for (final text in ['0.00', '125.50', '-0.01', '99999.99']) {
        expect(Money.parse(text).toDecimalString(), text);
      }
    });

    test('equality and ordering are by paisa', () {
      expect(Money.parse('1.10'), const Money.paisa(110));
      expect(const Money.paisa(1).compareTo(const Money.paisa(2)), lessThan(0));
    });
  });

  group('Money.lineAmount (price × quantity / 1000, half away from zero)', () {
    test('exact results', () {
      expect(line(20000, 2000), const Money.paisa(40000));
      expect(line(15000, 250), const Money.paisa(3750)); // 0.250 kg @ Rs 150
      expect(line(0, 5000), Money.zero);
      expect(line(12345, 0), Money.zero);
    });

    test('.5 paisa rounds away from zero (positive and negative)', () {
      expect(line(12550, 250), const Money.paisa(3138)); // 3137.5 → 3138
      expect(line(-12550, 250), const Money.paisa(-3138)); // −3137.5 → −3138
      expect(line(12550, -250), const Money.paisa(-3138));
      expect(line(1, 500), const Money.paisa(1)); // 0.5 → 1
      expect(line(-1, 500), const Money.paisa(-1)); // −0.5 → −1
    });

    test('just below and above .5', () {
      expect(line(1, 499), Money.zero); // 0.499 → 0
      expect(line(1, 501), const Money.paisa(1)); // 0.501 → 1
      expect(line(-1, 499), Money.zero); // −0.499 → 0
      expect(line(-1, 501), const Money.paisa(-1));
      expect(line(3, 1), Money.zero); // 0.003 → 0
    });

    test('1 subunit and large values are exact', () {
      expect(line(1000, 1), const Money.paisa(1));
      expect(
        line(9223372036854775807, 1000),
        const Money.paisa(9223372036854775807),
      );
    });

    test('overflow is detected, never wrapped', () {
      expect(
        () => line(9223372036854775807, 2000),
        throwsA(isA<FixedPointOverflowException>()),
      );
    });
  });
}
