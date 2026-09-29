import 'package:dokan_pro/core/localization/app_locale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLocaleController', () {
    test('defaults to English', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(appLocaleProvider), AppLocales.english);
    });

    test('switches between supported locales', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(appLocaleProvider.notifier).select(AppLocales.urdu);
      expect(container.read(appLocaleProvider), AppLocales.urdu);
      container.read(appLocaleProvider.notifier).select(AppLocales.english);
      expect(container.read(appLocaleProvider), AppLocales.english);
    });

    test('rejects unsupported locales', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        () => container
            .read(appLocaleProvider.notifier)
            .select(const Locale('fr')),
        throwsArgumentError,
      );
    });

    test('initial locale can be injected through an override', () {
      final container = ProviderContainer(
        overrides: [
          appLocaleProvider.overrideWith(
            () => AppLocaleController(initial: AppLocales.urdu),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(appLocaleProvider), AppLocales.urdu);
    });
  });
}
