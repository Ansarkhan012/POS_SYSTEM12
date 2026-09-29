import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../session/shell_session.dart';
import 'developer_preview_bar.dart';
import 'language_menu_button.dart';
import 'placeholder_page.dart';
import 'shell_destinations.dart';
import 'shell_navigation.dart';
import 'window_size_class.dart';

/// Role-aware, adaptive navigation shell.
///
/// - Role (from [shellSessionProvider]) decides WHICH destinations exist.
/// - Window width decides HOW they are presented (bar vs rail).
///
/// Role here is presentation only and never authorization (GOTCHAS G52).
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(shellSessionProvider);
    final showPreview = isDeveloperPreviewAvailable(ref);

    if (role == null) {
      return _ShellScaffold(
        title: AppLocalizations.of(context).appTitle,
        showPreview: showPreview,
        body: const NoSessionPage(),
      );
    }
    return _RoleShell(role: role, showPreview: showPreview);
  }
}

class _RoleShell extends ConsumerWidget {
  const _RoleShell({required this.role, required this.showPreview});

  final ShellRole role;
  final bool showPreview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final destinations = destinationsFor(role);
    final selected = ref
        .watch(shellNavigationProvider)
        .clamp(0, destinations.length - 1);
    final current = destinations[selected];
    final page = PlaceholderPage(
      key: ValueKey(current),
      title: current.label(l10n),
    );
    void onSelected(int index) =>
        ref.read(shellNavigationProvider.notifier).select(index);

    final sizeClass = WindowSizeClass.of(context);
    if (sizeClass == WindowSizeClass.compact) {
      return _ShellScaffold(
        title: current.label(l10n),
        showPreview: showPreview,
        body: page,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: onSelected,
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label(l10n),
              ),
          ],
        ),
      );
    }

    final extended = sizeClass == WindowSizeClass.expanded;
    return _ShellScaffold(
      title: current.label(l10n),
      showPreview: showPreview,
      body: Row(
        children: [
          _ScrollableRail(
            child: NavigationRail(
              extended: extended,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              selectedIndex: selected,
              onDestinationSelected: onSelected,
              destinations: [
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label(l10n)),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: page),
        ],
      ),
    );
  }
}

/// Lets the rail scroll instead of overflowing under large text scales.
class _ScrollableRail extends StatelessWidget {
  const _ScrollableRail({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({
    required this.title,
    required this.showPreview,
    required this.body,
    this.bottomNavigationBar,
  });

  final String title;
  final bool showPreview;
  final Widget body;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: const [LanguageMenuButton()]),
      body: Column(
        children: [
          if (showPreview) const DeveloperPreviewBar(),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
