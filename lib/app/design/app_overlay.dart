import 'package:flutter/widgets.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// 全屏浮层 Token（Paper Editorial §16 新增）。
///
/// 页面内容全屏铺底，上下边缘被渐隐遮罩（[topFade] / [bottomFade]）覆盖；
/// 顶部标题栏与底部导航作为浮层直接压在渐变之上（对齐 SoWhat 全屏页模式：
/// 内容 → 上下渐变遮罩 → 顶部浮层 → 底部浮层）。
abstract final class AppOverlay {
  /// 顶部渐隐遮罩高度：内容滚入标题浮层下方时柔和淡出。
  static const double topFadeHeight = 160;

  /// 底部渐隐遮罩高度：内容滚入导航浮层下方时柔和淡出。
  static const double bottomFadeHeight = 180;

  /// 顶部标题浮层内容避让（不含状态栏安全区）。
  static const double topContentInset = 88;

  /// 底部导航浮层内容避让（不含底部安全区）：导航高 + 浮起余量。
  static const double bottomContentInset = AppSpacing.navHeight + AppSpacing.lg;

  /// 页面内容顶部避让：状态栏 + 顶部浮层。
  static double topInset(BuildContext context) =>
      MediaQuery.paddingOf(context).top + topContentInset;

  /// 页面内容底部避让：底部安全区 + 导航浮层。
  static double bottomInset(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + bottomContentInset;

  /// 顶部渐隐遮罩：paper → 透明。
  static BoxDecoration topFade() => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.paper,
        AppColors.paper.withValues(alpha: 0.90),
        AppColors.paper.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.6, 1.0],
    ),
  );

  /// 底部渐隐遮罩：paper → 透明。
  static BoxDecoration bottomFade() => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        AppColors.paper,
        AppColors.paper.withValues(alpha: 0.85),
        AppColors.paper.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
  );
}
