import 'package:flutter/widgets.dart';

import 'app_spacing.dart';

/// 常用内边距组合，见 docs/design-spec.md §4。
abstract final class AppInsets {
  /// 卡片内边距：20 / 16 / 20 / 18（词头卡等大卡）。
  static const EdgeInsets card = EdgeInsets.fromLTRB(
    AppSpacing.xl,
    AppSpacing.lg,
    AppSpacing.xl,
    18,
  );

  /// 卡片内小容器（如英文释义块）：12。
  static const EdgeInsets cardInner = EdgeInsets.all(AppSpacing.md);

  /// 区块标题：20 / 16 / 20 / 8。
  static const EdgeInsets sectionHeader = EdgeInsets.fromLTRB(
    AppSpacing.xl,
    AppSpacing.lg,
    AppSpacing.xl,
    AppSpacing.sm,
  );

  /// 页面水平边距：16。
  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
  );

  /// 列表垂直：8。
  static const EdgeInsets pageVertical = EdgeInsets.symmetric(
    vertical: AppSpacing.sm,
  );

  /// 搜索框容器：16 / 4 / 16 / 12。
  static const EdgeInsets search = EdgeInsets.fromLTRB(
    AppSpacing.lg,
    AppSpacing.xxs,
    AppSpacing.lg,
    AppSpacing.md,
  );

  /// ListTile 内容：20 / 6。
  static const EdgeInsets listTile = EdgeInsets.symmetric(
    horizontal: AppSpacing.xl,
    vertical: AppSpacing.xs,
  );
}
