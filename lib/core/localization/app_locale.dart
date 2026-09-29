import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Locales Dokan Pro supports. English is the default; Urdu is a provisional
/// placeholder until Phase 14 (full content, RTL QA, numeral style Q11a).
abstract final class AppLocales {
  static const Locale english = Locale('en');
  static const Locale urdu = Locale('ur');

  static const List<Locale> supported = [english, urdu];
}

/// Holds the user-selected UI locale for the current session only.
///
/// Phase 1 forbids local persistence, so the choice resets on restart.
class AppLocaleController extends Notifier<Locale> {
  AppLocaleController({this.initial = AppLocales.english});

  /// Locale used when the provider is first built.
  final Locale initial;

  @override
  Locale build() => initial;

  /// Switches the UI locale at runtime.
  void select(Locale locale) {
    if (!AppLocales.supported.contains(locale)) {
      throw ArgumentError.value(locale, 'locale', 'Unsupported locale');
    }
    state = locale;
  }
}

final appLocaleProvider = NotifierProvider<AppLocaleController, Locale>(
  AppLocaleController.new,
);
