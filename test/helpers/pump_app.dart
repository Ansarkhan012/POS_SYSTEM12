import 'package:dokan_pro/app/app.dart';
import 'package:dokan_pro/app/environment/app_environment.dart';
import 'package:dokan_pro/app/session/shell_session.dart';
import 'package:dokan_pro/core/localization/app_locale.dart';
import 'package:dokan_pro/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phone portrait (compact).
const Size phonePortrait = Size(390, 844);

/// Medium width.
const Size mediumWidth = Size(700, 1000);

/// Tablet landscape (expanded).
const Size tabletLandscape = Size(1280, 800);

/// Pumps the full app with state injected through provider overrides only.
///
/// Every call builds a fresh [ProviderScope] (unique key): re-pumping a scope
/// with different `overrideWith` overrides would otherwise keep the previous
/// container and silently ignore the new role/locale.
Future<void> pumpDokanPro(
  WidgetTester tester, {
  ShellRole? role,
  Locale locale = AppLocales.english,
  Size size = phonePortrait,
  double textScale = 1.0,
  bool developerPreview = false,
  AppEnvironment environment = AppEnvironment.dev,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        shellSessionProvider.overrideWith(
          () => ShellSessionController(initialRole: role),
        ),
        appLocaleProvider.overrideWith(
          () => AppLocaleController(initial: locale),
        ),
        developerRolePreviewEnabledProvider.overrideWithValue(developerPreview),
        appEnvironmentProvider.overrideWithValue(environment),
      ],
      child: const DokanProApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Localizations currently used by the shell.
AppLocalizations shellL10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(Scaffold).first));

/// Labels of the visible navigation destinations, whatever the component.
List<String> destinationLabels(WidgetTester tester) {
  final bars = find.byType(NavigationBar);
  if (bars.evaluate().isNotEmpty) {
    return [
      for (final destination in tester.widget<NavigationBar>(bars).destinations)
        (destination as NavigationDestination).label,
    ];
  }
  final rails = find.byType(NavigationRail);
  if (rails.evaluate().isNotEmpty) {
    return [
      for (final destination
          in tester.widget<NavigationRail>(rails).destinations)
        (destination.label as Text).data!,
    ];
  }
  return const [];
}

/// Which navigation component type is shown, or `null` if none.
Type? navigationType(WidgetTester tester) {
  if (find.byType(NavigationBar).evaluate().isNotEmpty) return NavigationBar;
  if (find.byType(NavigationRail).evaluate().isNotEmpty) return NavigationRail;
  return null;
}
