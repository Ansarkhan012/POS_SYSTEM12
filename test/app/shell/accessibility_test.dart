import 'package:dokan_pro/app/session/shell_session.dart';
import 'package:dokan_pro/core/localization/app_locale.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  const sizes = {'phone': phonePortrait, 'tablet': tabletLandscape};
  const locales = [AppLocales.english, AppLocales.urdu];
  // `null` = no-session state (with the developer preview shown).
  const roles = <ShellRole?>[...ShellRole.values, null];

  for (final role in roles) {
    for (final size in sizes.entries) {
      for (final locale in locales) {
        final name = role?.name ?? 'no session';
        testWidgets('meets accessibility guidelines: $name, ${size.key}, '
            '${locale.languageCode}', (tester) async {
          final semantics = tester.ensureSemantics();
          await pumpDokanPro(
            tester,
            role: role,
            size: size.value,
            locale: locale,
            developerPreview: role == null,
          );

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          semantics.dispose();
        });
      }
    }
  }
}
