import '../numeric/fixed_point.dart';

/// A quantity in fixed-point integer subunits: 1 unit = 1000 subunits
/// (ADR-015). Examples: 1 piece = 1000, 0.750 kg = 750.
///
/// Quantities are signed so that later phases can express movements; use
/// [requirePositive] where only positive quantities are valid.
final class Quantity implements Comparable<Quantity> {
  const Quantity.subunits(this.subunits);

  /// Whole [units], e.g. `Quantity.units(2)` = 2000 subunits.
  factory Quantity.units(int units) => Quantity.subunits(
    toInt64(BigInt.from(units) * BigInt.from(subunitsPerUnit), 'units'),
  );

  /// Parses a canonical ASCII decimal (at most 3 fraction digits), e.g.
  /// `"0.750"` → 750, `"2"` → 2000. Never uses floating point.
  factory Quantity.parse(String input) =>
      Quantity.subunits(parseScaledDecimal(input, fractionDigits: 3));

  /// Subunits per unit (ADR-015).
  static const int subunitsPerUnit = 1000;

  static const Quantity zero = Quantity.subunits(0);

  /// Signed integer subunits.
  final int subunits;

  /// True when this is an exact number of whole units.
  bool get isWholeUnits => subunits % subunitsPerUnit == 0;

  bool get isPositive => subunits > 0;

  /// Returns this quantity, or throws [ArgumentError] if it is not positive.
  Quantity requirePositive() {
    if (!isPositive) {
      throw ArgumentError.value(subunits, 'quantity', 'must be positive');
    }
    return this;
  }

  Quantity operator +(Quantity other) =>
      Quantity.subunits(checkedAdd(subunits, other.subunits));

  Quantity operator -(Quantity other) =>
      Quantity.subunits(checkedSubtract(subunits, other.subunits));

  /// Canonical ASCII decimal, e.g. `"0.750"`. Not localized display text.
  String toDecimalString() => formatScaledDecimal(subunits, fractionDigits: 3);

  @override
  int compareTo(Quantity other) => subunits.compareTo(other.subunits);

  @override
  bool operator ==(Object other) =>
      other is Quantity && other.subunits == subunits;

  @override
  int get hashCode => subunits.hashCode;

  @override
  String toString() => 'Quantity(${toDecimalString()})';
}

/// Thrown when a quantity violates its [QuantityRule].
final class QuantityRuleViolation implements Exception {
  const QuantityRuleViolation(this.rule, this.quantity);

  final QuantityRule rule;
  final Quantity quantity;

  @override
  String toString() =>
      'QuantityRuleViolation: ${quantity.toDecimalString()} violates '
      '${rule.name}';
}

/// Whether a product may be sold in fractions (ADR-015, ADR-018).
///
/// The selling-unit model that assigns a rule to a product is Phase 4/5 (Q14);
/// this is only the validation primitive.
enum QuantityRule {
  /// Only multiples of 1000 subunits (whole pieces) are valid.
  wholeUnitsOnly,

  /// Any subunit amount is valid, including values below 1000 (loose goods).
  fractionalAllowed;

  bool allows(Quantity quantity) => switch (this) {
    QuantityRule.wholeUnitsOnly => quantity.isWholeUnits,
    QuantityRule.fractionalAllowed => true,
  };

  /// Returns [quantity] or throws [QuantityRuleViolation].
  Quantity validate(Quantity quantity) {
    if (!allows(quantity)) throw QuantityRuleViolation(this, quantity);
    return quantity;
  }
}
