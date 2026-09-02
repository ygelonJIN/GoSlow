import 'package:flutter/widgets.dart';

import 'app_colors.dart';
import 'app_sizes.dart';

/// 全屏浮层 Token（Paper Editorial §16 新增，几何对齐 IGotYou 模板）。
///
/// 页面内容全屏铺底，上下边缘被渐隐遮罩（[topFade] / [bottomFade]）覆盖；
/// 顶部标题栏与底部导航作为浮层直接压在渐变之上（对齐 SoWhat 全屏页模式：
/// 内容 → 上下渐变遮罩 → 顶部浮层 → 底部浮层）。
abstract final class AppOverlay {
  /// 顶部渐隐遮罩高度：固定 170（不含安全区），与顶部内容避让
  /// （[topInset]）同配，内容滚入标题浮层下方时柔和淡出。
  static const double topFadeHeight = AppSizes.topScrimHeight;

  /// 底部渐隐遮罩高度：固定 160（不含底部安全区）；实际渲染高度为
  /// [bottomScrimHeight]（= 安全区 + 160），见 [bottomFadeHeightFor]。
  static const double bottomFadeHeight = AppSizes.bottomScrimHeight;

  /// 顶部标题浮层内容避让（自屏幕顶端固定，全渠道一致，= 首条目距顶）。
  static const double topContentInset = AppSizes.contentTopInset;

  /// 底部导航浮层内容避让（不含底部安全区）：PillButton 高（~54）+ 浮起余量。
  static const double bottomContentInset = 70;

  /// 底部遮罩实际高度：底部安全区 + 160（与 IGotYou `VaultBottomScrim` 一致）。
  static double bottomScrimHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + bottomFadeHeight;

  /// 页面内容顶部避让（自屏幕顶端固定）。
  static double topInset(BuildContext context) => topContentInset;

  /// 页面内容底部避让：底部安全区 + 导航浮层。
  static double bottomInset(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + bottomContentInset;

  /// 顶部渐隐遮罩：paper → 透明（4 档渐变，与 IGotYou `topScrim` 同构）。
  static BoxDecoration topFade() => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.paper,
        AppColors.paper.withValues(alpha: 0.90),
        AppColors.paper.withValues(alpha: 0.48),
        AppColors.paper.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.34, 0.72, 1.0],
    ),
  );

  /// 底部渐隐遮罩：paper → 透明（自下而上，4 档渐变对称）。
  static BoxDecoration bottomFade() => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        AppColors.paper,
        AppColors.paper.withValues(alpha: 0.90),
        AppColors.paper.withValues(alpha: 0.48),
        AppColors.paper.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.34, 0.72, 1.0],
    ),
  );

  /// 侧栏 / 面板顶部渐隐：与面板底色同色（surface 1 → 0.92 → 0），
  /// 与 IGotYou `surfaceTopScrim` 同构。
  static BoxDecoration surfaceTopFade(Color surface) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        surface.withValues(alpha: 1),
        surface.withValues(alpha: 0.92),
        surface.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.6, 1.0],
    ),
  );

  /// 侧栏 / 面板底部渐隐：与面板底色同色（自下而上）。
  static BoxDecoration surfaceBottomFade(Color surface) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        surface.withValues(alpha: 1),
        surface.withValues(alpha: 0.92),
        surface.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.6, 1.0],
    ),
  );
}