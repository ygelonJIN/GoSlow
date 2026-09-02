/// 全屏页面模板与侧栏面板的几何令牌，见 docs/design-spec.md §5。
///
/// 与 IGotYou `AppSizes` 完全同构（两者源出 SoWhat 全屏页模板）：
/// - 内容首条距屏幕顶端固定 140（不含安全区），底部留白 236；
/// - 顶部遮罩固定 170、底部遮罩固定 160（底部遮罩另加底部安全区）；
/// - 顶栏胶囊 / 标题 SafeArea 下 16 / 8 / 16 / 0；
/// - 设置侧栏：内容上下避让 80 / 150（各自另加安全区），遮罩 150 / 200。
abstract final class AppSizes {
  AppSizes._();

  // ── 全屏页面模板（以主界面为基准，所有页面 / 未来页面统一）──
  /// 页面水平边距。
  static const double pageEdge = 16;

  /// 首条目距顶（自屏幕顶端固定，不含安全区）。
  static const double contentTopInset = 140;

  /// 内容底部留白（自屏幕底端固定，不含安全区）。
  static const double contentBottomInset = 236;

  /// 顶部遮罩高（固定，不含安全区）。
  static const double topScrimHeight = 170;

  /// 底部遮罩高（不含底部安全区；实际渲染另加 `padding.bottom`）。
  static const double bottomScrimHeight = 160;

  /// 顶栏胶囊 / 标题距顶。
  static const double topChromeInset = 8;

  // ── 设置侧栏（75% 宽滑出面板，surface 同色遮罩，独立于整页模板）──
  /// 侧栏内容顶部 = 安全区 + 80。
  static const double settingsTopInset = 80;

  /// 侧栏内容底部 = 安全区 + 150。
  static const double settingsBottomInset = 150;

  /// 侧栏顶部遮罩高。
  static const double settingsTopScrim = 150;

  /// 侧栏底部遮罩高。
  static const double settingsBottomScrim = 200;
}