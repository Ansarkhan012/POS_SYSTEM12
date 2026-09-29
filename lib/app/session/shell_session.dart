import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Roles the shell can present.
///
/// PRESENTATION ONLY — this is NOT authorization. Server-side authorization,
/// Row Level Security and the server-side sync boundary (ADR-014) are
/// authoritative. Showing or hiding a destination grants nothing (GOTCHAS G52).
enum ShellRole { owner, manager, cashier }

/// The role currently presented by the shell; `null` means "no session".
///
/// Phase 1 has no authentication, so the default is always no session. The
/// only way to change it is the debug-only developer role preview.
class ShellSessionController extends Notifier<ShellRole?> {
  ShellSessionController({this.initialRole});

  /// Role used when the provider is first built; `null` (no session) by default.
  final ShellRole? initialRole;

  @override
  ShellRole? build() => initialRole;

  /// Sets the previewed role. Used only by the developer role preview; this is
  /// not sign-in and persists nothing.
  void preview(ShellRole? role) => state = role;
}

final shellSessionProvider =
    NotifierProvider<ShellSessionController, ShellRole?>(
      ShellSessionController.new,
    );

/// Whether the developer role preview may be offered. Tests override this.
///
/// Widgets must also check [kDebugMode] (see [isDeveloperPreviewAvailable]) so
/// the preview is compiled out of release and profile builds.
final developerRolePreviewEnabledProvider = Provider<bool>((ref) => kDebugMode);

/// True only in debug builds and only when the preview is enabled.
bool isDeveloperPreviewAvailable(WidgetRef ref) =>
    kDebugMode && ref.watch(developerRolePreviewEnabledProvider);
