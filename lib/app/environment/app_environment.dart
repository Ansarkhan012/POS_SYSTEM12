import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Build-time environment, supplied with `--dart-define=APP_ENV=<value>` or
/// `--dart-define-from-file=config/<file>.json`.
///
/// This carries no secrets, keys, tokens or backend URLs (SECURITY.md §9).
enum AppEnvironment {
  dev,
  prod;

  /// Name of the compile-time define that selects the environment.
  static const String defineName = 'APP_ENV';

  /// Parses a raw `APP_ENV` value.
  ///
  /// An absent (empty) value means [dev]. Any other unknown value throws a
  /// [FormatException] so a misconfigured build fails fast instead of silently
  /// running with the wrong environment.
  static AppEnvironment parse(String raw) {
    switch (raw) {
      case '':
      case 'dev':
        return AppEnvironment.dev;
      case 'prod':
        return AppEnvironment.prod;
    }
    throw FormatException(
      'Invalid $defineName value "$raw". Expected "dev" or "prod".',
    );
  }

  /// Reads and parses the compile-time `APP_ENV` define.
  static AppEnvironment fromDefines() =>
      parse(const String.fromEnvironment(defineName));
}

/// The active [AppEnvironment]. `main` overrides it with the value parsed at
/// startup; tests may override it freely.
final appEnvironmentProvider = Provider<AppEnvironment>(
  (ref) => AppEnvironment.fromDefines(),
);
