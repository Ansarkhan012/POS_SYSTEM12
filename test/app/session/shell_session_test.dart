import 'package:dokan_pro/app/session/shell_session.dart';
import 'package:dokan_pro/app/shell/shell_navigation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShellSessionController', () {
    test('defaults to no session', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(shellSessionProvider), isNull);
    });

    test('role can be injected through an override', () {
      final container = ProviderContainer(
        overrides: [
          shellSessionProvider.overrideWith(
            () => ShellSessionController(initialRole: ShellRole.manager),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(shellSessionProvider), ShellRole.manager);
    });

    test('navigation resets to home when the role changes', () {
      final container = ProviderContainer(
        overrides: [
          shellSessionProvider.overrideWith(
            () => ShellSessionController(initialRole: ShellRole.owner),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(shellNavigationProvider.notifier).select(3);
      expect(container.read(shellNavigationProvider), 3);

      container.read(shellSessionProvider.notifier).preview(ShellRole.cashier);
      expect(container.read(shellNavigationProvider), 0);
    });
  });
}
