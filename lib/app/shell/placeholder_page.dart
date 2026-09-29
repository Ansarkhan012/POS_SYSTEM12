import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Empty placeholder for a destination: localized title and "not available yet"
/// text only. No data, numbers or fake content.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      icon: Icons.construction_outlined,
      title: title,
      message: AppLocalizations.of(context).placeholderNotAvailable,
    );
  }
}

/// Neutral page shown when there is no session. It contains no sign-in form or
/// PIN field: authentication does not exist in Phase 1.
class NoSessionPage extends StatelessWidget {
  const NoSessionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _CenteredMessage(
      icon: Icons.store_outlined,
      title: l10n.noSessionTitle,
      message: l10n.noSessionMessage,
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              style: textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
