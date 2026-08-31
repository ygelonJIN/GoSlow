import 'package:flutter/widgets.dart';

/// 动效 Token，见 docs/design-spec.md §7。
abstract final class AppMotion {
  static const Duration durationShort = Duration(milliseconds: 150);
  static const Duration durationMedium = Duration(milliseconds: 250);
  static const Duration durationLong = Duration(milliseconds: 350);

  static const Curve curveStandard = Curves.easeInOutCubic;
  static const Curve curveEmphasized = Curves.easeOutCubic;
}
