import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_locale.dart';
import '../../l10n/app_localizations.dart';

/// Runtime English ⇄ Urdu switch. Selecting Urdu makes the whole app RTL. The
/// choice lives in session memory only.
class LanguageMenuButton extends ConsumerWidget {
  const LanguageMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(appLocaleProvider);
    return PopupMenuButton<Locale>(
      tooltip: l10n.languageMenuTooltip,
      icon: const Icon(Icons.translate),
      onSelected: (locale) =>
          ref.read(appLocaleProvider.notifier).select(locale),
      itemBuilder: (context) => [
        for (final locale in AppLocales.supported)
          // A check mark (not color alone) shows the current language.
          CheckedPopupMenuItem<Locale>(
            value: locale,
            checked: locale == current,
            child: Text(_languageName(l10n, locale)),
          ),
      ],
    );
  }

  static String _languageName(AppLocalizations l10n, Locale locale) =>
      switch (locale.languageCode) {
        'ur' => l10n.languageUrdu,
        _ => l10n.languageEnglish,
      };
}
