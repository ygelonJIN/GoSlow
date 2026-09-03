import 'package:flutter/material.dart';

import '../app/design/app_colors.dart';
import '../app/design/app_overlay.dart';
import '../app/design/app_radius.dart';
import '../app/design/app_spacing.dart';
import '../app/theme/fold_decoration.dart';
import '../app/theme/mode_theme.dart';

/// 底部弹层拖拽条（点词面板 / 收藏完整卡 / 考纲与张数选择面板共用）。
class DragHandle extends StatelessWidget {
  const DragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.line,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}

/// 弹出主题化底部选择面板（CutBox 卡片语言），返回面板 pop 值；点遮罩返回 null。
///
/// - `isScrollControlled`：面板内容可随键盘 / 长列表自适应，最高到
///   [maxHeightFactor] 屏高，超出内部滚动。
/// - `builder` 内容自行套 [AppSheetFrame]（拖拽条 + 标题 + 滚动区 + 底部动作）。
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double? heightFactor = 0.52,
  double maxHeightFactor = 0.68,
}) {
  const mode = ModeThemes.theme1;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final height = MediaQuery.sizeOf(ctx).height;
      final frame = CutBox(
        fold: mode.cornerFold,
        color: mode.cardBackground,
        borderRadius: BorderRadius.vertical(top: mode.cardRadius.topLeft),
        border: Border.all(color: mode.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
        clipBehavior: Clip.antiAlias,
        child: builder(ctx),
      );
      if (heightFactor != null) {
        return SizedBox(height: height * heightFactor, child: frame);
      }
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height * maxHeightFactor),
        child: frame,
      );
    },
  );
}

/// 主题化底部选择面板骨架：拖拽条 + 标题 + 说明 + 滚动内容 + 底部动作条。
///
/// 内容区是独立的 ListView；上下渐变遮罩和浮层控件直接覆盖在列表之上，
/// 因此滚动到标题或底部动作条下方的内容会自然淡出。
class AppSheetFrame extends StatelessWidget {
  const AppSheetFrame({
    super.key,
    this.title,
    this.caption,
    required this.child,
    this.bottomBar,
    this.scrollable = true,
    this.showFades = true,
    this.compact = false,
    this.scrollTopPadding = 96,
    this.scrollBottomPadding = 156,
    this.bottomFadeHeight = 70,
  });

  /// 面板标题（如「当前考纲」）；为空时只显示拖拽条。
  final String? title;

  /// 标题下的小字说明（如多选规则 / 每轮抽几张）。
  final String? caption;

  /// 可滚动内容区。
  final Widget child;

  /// 底部常驻动作条（如「完成」胶囊）。
  final Widget? bottomBar;

  /// 是否让内容区使用 ListView。点词正面的固定内容应关闭。
  final bool scrollable;

  /// 是否显示上下渐变遮罩。点词正面不需要遮罩。
  final bool showFades;

  /// 固定内容面板使用更紧凑的顶部和底部内边距。
  final bool compact;

  /// 滚动内容与面板上下浮层之间的避让距离。
  final double scrollTopPadding;
  final double scrollBottomPadding;

  /// 当前弹层底部渐变遮罩高度。
  final double bottomFadeHeight;

  @override
  Widget build(BuildContext context) {
    const mode = ModeThemes.theme1;
    final surface = mode.cardBackground;
    const topOverlayHeight = 104.0;
    final bottomOverlayHeight = bottomFadeHeight;

    return SafeArea(
      child: Stack(
        children: [
          if (scrollable)
            ListView(
              shrinkWrap: true,
              primary: false,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                scrollTopPadding,
                AppSpacing.lg,
                scrollBottomPadding,
              ),
              children: [child],
            )
          else
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                compact ? 24 : 96,
                AppSpacing.lg,
                compact ? 12 : 22,
              ),
              child: child,
            ),
          if (showFades) ...[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topOverlayHeight,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: AppOverlay.surfaceTopFade(surface),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: bottomOverlayHeight,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: AppOverlay.surfaceBottomFade(surface),
                ),
              ),
            ),
          ],
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DragHandle(),
                if (title != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      caption!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (bottomBar != null)
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.sm,
              child: bottomBar!,
            ),
        ],
      ),
    );
  }
}

/// 主题化单选 / 多选行（卡片内一行 + 尾部信息 + 勾选），供底部选择面板共用。
class AppSheetChoiceRow extends StatelessWidget {
  const AppSheetChoiceRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  /// 主标题（考纲名 / 张数）。
  final String title;

  /// 尾部信息（勾选图标左侧，右对齐；如考纲行的总词数 / 已认识数）。
  final String? trailing;

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Text(
                    trailing!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 22,
                color: selected ? scheme.primary : AppColors.line,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
