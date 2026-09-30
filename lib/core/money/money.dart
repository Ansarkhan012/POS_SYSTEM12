import '../numeric/fixed_point.dart';
import '../quantity/quantity.dart';

/// An amount of money in signed 64-bit integer **paisa** (1 PKR = 100 paisa),
/// ADR-008. There is deliberately no `double` constructor, getter or operator.
final class Money implements Comparable<Money> {
  const Money.paisa(this.paisa);

  /// Parses a canonical ASCII decimal rupee amount with at most 2 fraction
  /// digits, e.g. `"125.50"` → 12,550 paisa. Never uses floating point.
  factory Money.parse(String input) =>
      Money.paisa(parseScaledDecimal(input, fractionDigits: 2));

  static const Money zero = Money.paisa(0);

  /// Signed integer paisa.
  final int paisa;

  Money operator +(Money other) => Money.paisa(checkedAdd(paisa, other.paisa));

  Money operator -(Money other) =>
      Money.paisa(checkedSubtract(paisa, other.paisa));

  Money operator -() => Money.paisa(checkedSubtract(0, paisa));

  bool get isNegative => paisa < 0;

  /// Line amount = unit price × quantity / 1000, rounded to the nearest paisa
  /// **half away from zero** (ADR-008), using exact integer arithmetic.
  ///
  /// Throws [FixedPointOverflowException] if the result exceeds 64-bit range.
  static Money lineAmount({
    required Money unitPrice,
    required Quantity quantity,
  }) {
    final product =
        BigInt.from(unitPrice.paisa) * BigInt.from(quantity.subunits);
    final rounded = divideRoundHalfAwayFromZero(
      product,
      BigInt.from(Quantity.subunitsPerUnit),
    );
    return Money.paisa(toInt64(rounded, 'line amount'));
  }

  /// Canonical ASCII decimal rupees, e.g. `"-125.50"`. Not localized display
  /// text (numeral style is open question Q11a).
  String toDecimalString() => formatScaledDecimal(paisa, fractionDigits: 2);

  @override
  int compareTo(Money other) => paisa.compareTo(other.paisa);

  @override
  bool operator ==(Object other) => other is Money && other.paisa == paisa;

  @override
  int get hashCode => paisa.hashCode;

  @override
  String toString() => 'Money(${toDecimalString()})';
}
