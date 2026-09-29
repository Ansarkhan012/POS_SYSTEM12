import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../session/shell_session.dart';

/// Placeholder destinations of the shell. None has any feature behind it yet.
enum ShellDestination {
  checkout(Icons.point_of_sale_outlined, Icons.point_of_sale),
  more(Icons.more_horiz, Icons.more_horiz),
  summary(Icons.dashboard_outlined, Icons.dashboard),
  sales(Icons.receipt_long_outlined, Icons.receipt_long),
  inventory(Icons.inventory_2_outlined, Icons.inventory_2),
  udhaar(Icons.menu_book_outlined, Icons.menu_book),
  management(Icons.settings_outlined, Icons.settings),
  operations(Icons.storefront_outlined, Icons.storefront),
  reports(Icons.assessment_outlined, Icons.assessment),
  approvals(Icons.fact_check_outlined, Icons.fact_check);

  const ShellDestination(this.icon, this.selectedIcon);

  final IconData icon;
  final IconData selectedIcon;

  String label(AppLocalizations l10n) => switch (this) {
    ShellDestination.checkout => l10n.destinationCheckout,
    ShellDestination.more => l10n.destinationMore,
    ShellDestination.summary => l10n.destinationSummary,
    ShellDestination.sales => l10n.destinationSales,
    ShellDestination.inventory => l10n.destinationInventory,
    ShellDestination.udhaar => l10n.destinationUdhaar,
    ShellDestination.management => l10n.destinationManagement,
    ShellDestination.operations => l10n.destinationOperations,
    ShellDestination.reports => l10n.destinationReports,
    ShellDestination.approvals => l10n.destinationApprovals,
  };
}

/// Destinations per role. Capability depends on role only, never on device size
/// (GOTCHAS G50). The first entry is the role's home.
List<ShellDestination> destinationsFor(ShellRole role) => switch (role) {
  // Checkout-first with exactly one secondary entry point (DESIGN.md §1);
  // nothing owner/analytics-related and nothing implying cost or profit.
  ShellRole.cashier => const [ShellDestination.checkout, ShellDestination.more],
  ShellRole.owner => const [
    ShellDestination.summary,
    ShellDestination.sales,
    ShellDestination.inventory,
    ShellDestination.udhaar,
    ShellDestination.management,
  ],
  ShellRole.manager => const [
    ShellDestination.operations,
    ShellDestination.inventory,
    ShellDestination.reports,
    ShellDestination.approvals,
  ],
};
