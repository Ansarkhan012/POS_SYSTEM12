import 'package:dokan_pro/app/environment/app_environment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppEnvironment', () {
    test('missing APP_ENV defaults to dev', () {
      // Tests run without --dart-define, so the define is absent here.
      expect(AppEnvironment.fromDefines(), AppEnvironment.dev);
      expect(AppEnvironment.parse(''), AppEnvironment.dev);
    });

    test('dev and prod parse correctly', () {
      expect(AppEnvironment.parse('dev'), AppEnvironment.dev);
      expect(AppEnvironment.parse('prod'), AppEnvironment.prod);
    });

    test('invalid values fail fast', () {
      for (final invalid in ['staging', 'PROD', 'Dev', ' dev', 'production']) {
        expect(
          () => AppEnvironment.parse(invalid),
          throwsFormatException,
          reason: 'APP_ENV="$invalid" must be rejected',
        );
      }
    });

    test('provider can be overridden', () {
      final container = ProviderContainer(
        overrides: [
          appEnvironmentProvider.overrideWithValue(AppEnvironment.prod),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(appEnvironmentProvider), AppEnvironment.prod);
    });
  });
}
