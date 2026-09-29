import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/shell_session.dart';

/// Index of the selected shell destination. Resets to the role's home (index 0)
/// whenever the presented role changes.
class ShellNavigationController extends Notifier<int> {
  @override
  int build() {
    ref.watch(shellSessionProvider);
    return 0;
  }

  void select(int index) {
    if (index < 0) throw RangeError.value(index, 'index');
    state = index;
  }
}

final shellNavigationProvider =
    NotifierProvider<ShellNavigationController, int>(
      ShellNavigationController.new,
    );
