import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/environment/app_environment.dart';

void main() {
  // Parsed before anything renders so an invalid APP_ENV fails fast.
  final environment = AppEnvironment.fromDefines();

  runApp(
    ProviderScope(
      overrides: [appEnvironmentProvider.overrideWithValue(environment)],
      child: const DokanProApp(),
    ),
  );
}
