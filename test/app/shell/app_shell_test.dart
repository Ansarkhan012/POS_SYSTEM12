import 'package:dokan_pro/app/session/shell_session.dart';
import 'package:dokan_pro/app/shell/app_shell.dart';
import 'package:dokan_pro/app/shell/developer_preview_bar.dart';
import 'package:dokan_pro/app/shell/placeholder_page.dart';
import 'package:dokan_pro/core/localization/app_locale.dart';
import 'package:dokan_pro/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

const _sizes = <String, Size>{
  'phone portrait': phonePortrait,
  'medium width': mediumWidth,
  'tablet landscape': tabletLandscape,
};

List<String> _expectedLabels(AppLocalizations l10n, ShellRole role) =>
    switch (role) {
      ShellRole.cashier => [l10n.destinationCheckout, l10n.destinationMore],
      ShellRole.owner => [
        l10n.destinationSummary,
        l10n.destinationSales,
        l10n.destinationInventory,
        l10n.destinationUdhaar,
        l10n.destinationManagement,
      ],
      ShellRole.manager => [
        l10n.destinationOperations,
        l10n.destinationInventory,
        l10n.destinationReports,
        l10n.destinationApprovals,
      ],
    };

Type _expectedNavigation(Size size) =>
    size.width < 600 ? NavigationBar : NavigationRail;

void main() {
  group('No session', () {
    for (final entry in _sizes.entries) {
      testWidgets('default shell is neutral at ${entry.key}', (tester) async {
        await pumpDokanPro(tester, size: entry.value);
        final l10n = shellL10n(tester);

        expect(find.byType(NoSessionPage), findsOneWidget);
        expect(find.text(l10n.noSessionTitle), findsOneWidget);
        expect(find.text(l10n.noSessionMessage), findsOneWidget);
        expect(navigationType(tester), isNull);
        expect(destinationLabels(tester), isEmpty);
        // No authentication UI exists in Phase 1.
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(EditableText), findsNothing);
      });
    }
  });

  group('Role × size matrix', () {
    for (final role in ShellRole.values) {
      for (final entry in _sizes.entries) {
        testWidgets('${role.name} at ${entry.key}', (tester) async {
          await pumpDokanPro(tester, role: role, size: entry.value);
          final l10n = shellL10n(tester);

          expect(navigationType(tester), _expectedNavigation(entry.value));
          expect(destinationLabels(tester), _expectedLabels(l10n, role));
          expect(find.byType(PlaceholderPage), findsOneWidget);

          if (entry.value == tabletLandscape) {
            final rail = tester.widget<NavigationRail>(
              find.byType(NavigationRail),
            );
            expect(rail.extended, isTrue);
          }
          if (entry.value == mediumWidth) {
            final rail = tester.widget<NavigationRail>(
              find.byType(NavigationRail),
            );
            expect(rail.extended, isFalse);
          }
        });
      }
    }

    for (final entry in _sizes.entries) {
      testWidgets('cashier opens on Checkout with exactly one secondary entry '
          'and no owner destinations at ${entry.key}', (tester) async {
        await pumpDokanPro(tester, role: ShellRole.cashier, size: entry.value);
        final l10n = shellL10n(tester);

        final labels = destinationLabels(tester);
        expect(labels, hasLength(2));
        expect(labels.first, l10n.destinationCheckout);
        expect(labels.last, l10n.destinationMore);

        // Home: the Checkout placeholder is the selected page and app bar title.
        final page = tester.widget<PlaceholderPage>(
          find.byType(PlaceholderPage),
        );
        expect(page.title, l10n.destinationCheckout);
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text(l10n.destinationCheckout),
          ),
          findsOneWidget,
        );

        for (final ownerOnly in [
          l10n.destinationSummary,
          l10n.destinationSales,
          l10n.destinationUdhaar,
          l10n.destinationManagement,
          l10n.destinationReports,
        ]) {
          expect(find.text(ownerOnly), findsNothing);
        }
      });
    }
  });

  group('Capability comes from role only', () {
    for (final role in ShellRole.values) {
      testWidgets('${role.name} has identical destinations at every size', (
        tester,
      ) async {
        final perSize = <List<String>>[];
        for (final size in _sizes.values) {
          await pumpDokanPro(tester, role: role, size: size);
          perSize.add(destinationLabels(tester));
        }
        expect(perSize, hasLength(_sizes.length));
        expect(perSize.first, _expectedLabels(shellL10n(tester), role));
        for (final labels in perSize) {
          expect(labels, perSize.first);
        }
      });
    }
  });

  group('Layout comes from width only', () {
    for (final entry in _sizes.entries) {
      testWidgets('all roles use the same navigation type at ${entry.key}', (
        tester,
      ) async {
        final types = <Type?>{};
        for (final role in ShellRole.values) {
          await pumpDokanPro(tester, role: role, size: entry.value);
          // Guard against a stale scope: the requested role must be shown.
          expect(
            destinationLabels(tester),
            _expectedLabels(shellL10n(tester), role),
          );
          types.add(navigationType(tester));
        }
        expect(types, {_expectedNavigation(entry.value)});
      });
    }
  });

  group('Navigation', () {
    testWidgets('selecting a destination shows its placeholder', (
      tester,
    ) async {
      await pumpDokanPro(tester, role: ShellRole.owner);
      final l10n = shellL10n(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(l10n.destinationInventory),
        ),
      );
      await tester.pumpAndSettle();

      final page = tester.widget<PlaceholderPage>(find.byType(PlaceholderPage));
      expect(page.title, l10n.destinationInventory);
    });
  });

  group('Locale switch', () {
    for (final size in [phonePortrait, tabletLandscape]) {
      testWidgets('switches to Urdu (RTL) and back without restart at $size', (
        tester,
      ) async {
        await pumpDokanPro(tester, role: ShellRole.cashier, size: size);
        final en = shellL10n(tester);
        final ur = await AppLocalizations.delegate.load(AppLocales.urdu);

        expect(find.text(en.destinationCheckout), findsWidgets);
        expect(
          Directionality.of(tester.element(find.byType(AppShell))),
          TextDirection.ltr,
        );

        await tester.tap(find.byTooltip(en.languageMenuTooltip));
        await tester.pumpAndSettle();
        await tester.tap(find.text(en.languageUrdu).last);
        await tester.pumpAndSettle();

        expect(find.text(ur.destinationCheckout), findsWidgets);
        expect(find.text(en.destinationCheckout), findsNothing);
        expect(
          Directionality.of(tester.element(find.byType(AppShell))),
          TextDirection.rtl,
        );
        expect(
          Directionality.of(tester.element(find.byType(PlaceholderPage))),
          TextDirection.rtl,
        );

        await tester.tap(find.byTooltip(ur.languageMenuTooltip));
        await tester.pumpAndSettle();
        await tester.tap(find.text(ur.languageEnglish).last);
        await tester.pumpAndSettle();

        expect(find.text(en.destinationCheckout), findsWidgets);
        expect(
          Directionality.of(tester.element(find.byType(AppShell))),
          TextDirection.ltr,
        );
      });
    }
  });

  group('Developer role preview gating', () {
    testWidgets('absent when the preview flag is disabled', (tester) async {
      await pumpDokanPro(tester);
      final l10n = shellL10n(tester);

      expect(find.byKey(DeveloperPreviewBar.barKey), findsNothing);
      expect(find.byTooltip(l10n.devPreviewMenuTooltip), findsNothing);
    });

    testWidgets('absent for a role when the preview flag is disabled', (
      tester,
    ) async {
      await pumpDokanPro(tester, role: ShellRole.cashier);
      expect(find.byKey(DeveloperPreviewBar.barKey), findsNothing);
    });

    testWidgets('present and labeled as a development preview when enabled', (
      tester,
    ) async {
      await pumpDokanPro(tester, developerPreview: true);
      final l10n = shellL10n(tester);

      expect(find.byKey(DeveloperPreviewBar.barKey), findsOneWidget);
      expect(find.text(l10n.devPreviewBanner('dev')), findsOneWidget);
      expect(find.byTooltip(l10n.devPreviewMenuTooltip), findsOneWidget);
    });

    testWidgets('previews a role and returns to no session', (tester) async {
      await pumpDokanPro(tester, developerPreview: true);
      final l10n = shellL10n(tester);

      await tester.tap(find.byTooltip(l10n.devPreviewMenuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.roleCashier).last);
      await tester.pumpAndSettle();

      expect(destinationLabels(tester), [
        l10n.destinationCheckout,
        l10n.destinationMore,
      ]);

      await tester.tap(find.byTooltip(l10n.devPreviewMenuTooltip));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.devPreviewNoSession).last);
      await tester.pumpAndSettle();

      expect(find.byType(NoSessionPage), findsOneWidget);
      expect(navigationType(tester), isNull);
    });
  });
}
