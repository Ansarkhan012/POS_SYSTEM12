import 'dart:convert';
import 'dart:io';

import 'package:dokan_pro/app/shell/app_shell.dart';
import 'package:dokan_pro/core/localization/app_locale.dart';
import 'package:dokan_pro/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

Map<String, Object?> _readArb(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync())
        as Map<String, Object?>;

Set<String> _messageKeys(Map<String, Object?> arb) =>
    arb.keys.where((key) => !key.startsWith('@')).toSet();

void main() {
  group('Localization setup', () {
    test('supported locales are exactly en and ur', () {
      expect(AppLocalizations.supportedLocales.toSet(), {
        const Locale('en'),
        const Locale('ur'),
      });
      expect(AppLocalizations.supportedLocales, hasLength(2));
      expect(AppLocales.supported.toSet(), {
        AppLocales.english,
        AppLocales.urdu,
      });
    });

    test('both locales load', () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final ur = await AppLocalizations.delegate.load(const Locale('ur'));
      expect(en.appTitle, 'Dokan Pro');
      expect(ur.appTitle, isNotEmpty);
      expect(ur.destinationCheckout, isNot(en.destinationCheckout));
    });

    testWidgets('ur resolves to RTL and en to LTR', (tester) async {
      await pumpDokanPro(tester, locale: AppLocales.urdu);
      expect(
        Directionality.of(tester.element(find.byType(AppShell))),
        TextDirection.rtl,
      );

      await pumpDokanPro(tester);
      expect(
        Directionality.of(tester.element(find.byType(AppShell))),
        TextDirection.ltr,
      );
    });

    test('every key in app_en.arb exists in app_ur.arb (and vice versa)', () {
      final en = _messageKeys(_readArb('app_en.arb'));
      final ur = _messageKeys(_readArb('app_ur.arb'));
      expect(en.difference(ur), isEmpty, reason: 'missing in app_ur.arb');
      expect(ur.difference(en), isEmpty, reason: 'unknown in app_ur.arb');
    });

    test('every Urdu value is marked provisional', () {
      final ur = _readArb('app_ur.arb');
      for (final key in _messageKeys(ur)) {
        if (key == '@@locale') continue;
        final meta = ur['@$key'] as Map<String, Object?>?;
        expect(
          meta?['description'],
          contains('PROVISIONAL'),
          reason: '"$key" must be marked provisional until Phase 14',
        );
      }
    });
  });
}
