/// 间距 Token（4pt 基准），见 docs/design-spec.md §4。
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xl2 = 24;
  static const double xl3 = 32;
  static const double xl4 = 48;

  /// 底部导航高度（规范 §8）。
  static const double navHeight = 64;

  /// 空状态图标尺寸（规范 §8）。
  static const double emptyIcon = 56;

  /// 卡片前置头像内图标尺寸（规范 §10）。
  static const double cardIcon = 22;

  // ---- 胶囊按钮（PillButton / SegmentedPills 等全局统一）----
  /// 胶囊按钮垂直内边距：所有胶囊控件（收藏 / 添加 / 底部导航 / 分段选择）一致。
  static const double pillVertical = 10;

  /// 胶囊按钮水平内边距（普通态）。
  static const double pillHorizontal = 16;

  /// 胶囊按钮图标与文字间距。
  static const double pillGap = 6;

  /// 胶囊按钮文字字号。
  static const double pillFontSize = 13.5;
}
