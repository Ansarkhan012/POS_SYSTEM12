import 'package:flutter/widgets.dart';

/// Material window-size classes. Presentation depends on width only, never on
/// role (GOTCHAS G50/G51).
enum WindowSizeClass {
  /// Width < 600 dp.
  compact,

  /// 600 dp ≤ width < 840 dp.
  medium,

  /// Width ≥ 840 dp.
  expanded;

  static WindowSizeClass fromWidth(double width) {
    if (width < 600) return WindowSizeClass.compact;
    if (width < 840) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }

  static WindowSizeClass of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);
}
