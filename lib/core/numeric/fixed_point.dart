/// Exact integer helpers shared by Money and Quantity (ADR-008, ADR-015).
///
/// Nothing in this library uses binary floating point.
library;

/// Thrown when a fixed-point operation would leave the signed 64-bit range.
final class FixedPointOverflowException implements Exception {
  const FixedPointOverflowException(this.operation);

  final String operation;

  @override
  String toString() =>
      'FixedPointOverflowException: $operation overflows signed 64-bit';
}

/// Smallest signed 64-bit value.
final BigInt minInt64 = -(BigInt.one << 63);

/// Largest signed 64-bit value.
final BigInt maxInt64 = (BigInt.one << 63) - BigInt.one;

/// `a + b`, throwing instead of silently wrapping on overflow.
int checkedAdd(int a, int b) {
  final result = a + b;
  if (((a ^ result) & (b ^ result)) < 0) {
    throw const FixedPointOverflowException('addition');
  }
  return result;
}

/// `a - b`, throwing instead of silently wrapping on overflow.
int checkedSubtract(int a, int b) {
  final result = a - b;
  if (((a ^ b) & (a ^ result)) < 0) {
    throw const FixedPointOverflowException('subtraction');
  }
  return result;
}

/// Converts [value] to an `int`, throwing if it is outside signed 64-bit range.
int toInt64(BigInt value, String operation) {
  if (value < minInt64 || value > maxInt64) {
    throw FixedPointOverflowException(operation);
  }
  return value.toInt();
}

/// Divides [numerator] by a positive [denominator] and rounds the quotient to
/// the nearest integer, **half away from zero** (e.g. 2.5 → 3, −2.5 → −3).
BigInt divideRoundHalfAwayFromZero(BigInt numerator, BigInt denominator) {
  if (denominator <= BigInt.zero) {
    throw ArgumentError.value(denominator, 'denominator', 'must be positive');
  }
  final magnitude = numerator.abs();
  var quotient = magnitude ~/ denominator;
  final remainder = magnitude.remainder(denominator);
  if (remainder * BigInt.two >= denominator) {
    quotient += BigInt.one;
  }
  return numerator.isNegative ? -quotient : quotient;
}

/// Parses a canonical ASCII decimal string into an integer scaled by
/// `10^fractionDigits` without using floating point.
///
/// Accepted: optional leading `-`, one or more ASCII digits, optionally a `.`
/// followed by 1..[fractionDigits] ASCII digits. Anything else (signs `+`,
/// spaces, separators, exponents, locale digits, too many fraction digits)
/// throws a [FormatException].
int parseScaledDecimal(String input, {required int fractionDigits}) {
  final pattern = RegExp('^(-)?([0-9]+)(?:\\.([0-9]{1,$fractionDigits}))?\$');
  final match = pattern.firstMatch(input);
  if (match == null) {
    throw FormatException(
      'Expected a decimal with at most $fractionDigits fraction digits',
      input,
    );
  }
  final negative = match.group(1) != null;
  final whole = BigInt.parse(match.group(2)!);
  final fraction = (match.group(3) ?? '').padRight(fractionDigits, '0');
  final scale = BigInt.from(10).pow(fractionDigits);
  final magnitude =
      whole * scale + (fraction.isEmpty ? BigInt.zero : BigInt.parse(fraction));
  return toInt64(negative ? -magnitude : magnitude, 'parsing "$input"');
}

/// Formats [scaled] (an integer scaled by `10^fractionDigits`) as a canonical
/// ASCII decimal string, e.g. `formatScaledDecimal(-12550, 2) == '-125.50'`.
///
/// This is a serialization/debugging format, not localized display text.
String formatScaledDecimal(int scaled, {required int fractionDigits}) {
  final value = BigInt.from(scaled);
  final scale = BigInt.from(10).pow(fractionDigits);
  final magnitude = value.abs();
  final whole = magnitude ~/ scale;
  final fraction = magnitude
      .remainder(scale)
      .toString()
      .padLeft(fractionDigits, '0');
  final sign = value.isNegative ? '-' : '';
  return fractionDigits == 0 ? '$sign$whole' : '$sign$whole.$fraction';
}
