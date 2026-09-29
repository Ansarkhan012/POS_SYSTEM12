import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../environment/app_environment.dart';
import '../session/shell_session.dart';

/// Debug-only developer role preview. It exists so the role shells can be viewed
/// without authentication. It is clearly labeled as NOT sign-in, persists
/// nothing, and is only built when [isDeveloperPreviewAvailable] is true (which
/// is always false in release and profile builds).
class DeveloperPreviewBar extends ConsumerWidget {
  const DeveloperPreviewBar({super.key});

  static const Key barKey = Key('developer-role-preview');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final environment = ref.watch(appEnvironmentProvider);
    final role = ref.watch(shellSessionProvider);
    final current = _PreviewChoice.fromRole(role);

    return Material(
      key: barKey,
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
        child: Row(
          children: [
            Icon(Icons.developer_mode, color: colors.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.devPreviewBanner(environment.name),
                style: TextStyle(color: colors.onTertiaryContainer),
              ),
            ),
            PopupMenuButton<_PreviewChoice>(
              tooltip: l10n.devPreviewMenuTooltip,
              icon: Icon(
                Icons.switch_account,
                color: colors.onTertiaryContainer,
              ),
              onSelected: (choice) =>
                  ref.read(shellSessionProvider.notifier).preview(choice.role),
              itemBuilder: (context) => [
                for (final choice in _PreviewChoice.values)
                  CheckedPopupMenuItem<_PreviewChoice>(
                    value: choice,
                    checked: choice == current,
                    child: Text(choice.label(l10n)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Menu values; a dedicated "no session" entry avoids null menu values, which
/// PopupMenuButton treats as a cancelled selection.
enum _PreviewChoice {
  noSession(null),
  owner(ShellRole.owner),
  manager(ShellRole.manager),
  cashier(ShellRole.cashier);

  const _PreviewChoice(this.role);

  final ShellRole? role;

  static _PreviewChoice fromRole(ShellRole? role) =>
      values.firstWhere((choice) => choice.role == role);

  String label(AppLocalizations l10n) => switch (this) {
    _PreviewChoice.noSession => l10n.devPreviewNoSession,
    _PreviewChoice.owner => l10n.roleOwner,
    _PreviewChoice.manager => l10n.roleManager,
    _PreviewChoice.cashier => l10n.roleCashier,
  };
}
