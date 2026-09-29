import 'package:dokan_pro/app/session/shell_session.dart';
import 'package:dokan_pro/core/localization/app_locale.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  const sizes = {'phone': phonePortrait, 'tablet': tabletLandscape};
  const locales = [AppLocales.english, AppLocales.urdu];
  const scales = [1.0, 2.0];
  const roles = <ShellRole?>[...ShellRole.values, null];

  for (final role in roles) {
    for (final size in sizes.entries) {
      for (final locale in locales) {
        for (final scale in scales) {
          final name = role?.name ?? 'no session';
          testWidgets('no overflow or layout exceptions: $name, ${size.key}, '
              '${locale.languageCode}, text scale $scale', (tester) async {
            await pumpDokanPro(
              tester,
              role: role,
              size: size.value,
              locale: locale,
              textScale: scale,
              developerPreview: true,
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
}
