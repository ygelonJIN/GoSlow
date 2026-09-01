import 'package:flutter/material.dart';

import '../app/design/design.dart';
import '../app/theme/mode_theme.dart';
import 'feedback_dialog.dart';
import 'pill_button.dart';

/// 全屏页「全屏内容 + 浮层控制」骨架（源自 SoWhat Battle/Memory 页）。
///
/// 层级自底向上：
/// 1. 全屏内容（[child] 全屏铺底，滚动区自行用 `AppOverlay` 避让浮层）
/// 2. 顶部渐隐遮罩 + 底部渐隐遮罩（[IgnorePointer]，直接盖在内容上，
///    内容滚到浮层下方时自然淡出）
/// 3. 顶部浮层：返回胶囊 + 标题 + 可选右侧动作
/// 4. 底部悬浮条（[bottomBar]，可选）
///
/// 全局主题下自动继承配色 / 圆角 / 字体，后续新增页面直接复用。
class OverlayPage extends StatelessWidget {
  const OverlayPage({
    super.key,
    required this.child,
    required this.title,
    this.kicker,
    this.topTrailing,
    this.bottomBar,
    this.topFadeHeight = AppOverlay.topFadeHeight,
    this.bottomFadeHeight = AppOverlay.bottomFadeHeight,
    this.onBack,
  });

  /// 全屏内容区（全屏铺底，滚动区自行避让上下浮层）。
  final Widget child;

  /// 顶部浮层标题（可含上方小字 kicker）。
  final String title;
  final String? kicker;

  /// 顶部浮层右侧动作（如设置页状态点）。
  final Widget? topTrailing;

  /// 底部悬浮条（压在底部渐隐之上）。
  final Widget? bottomBar;

  /// 顶部 / 底部渐隐遮罩高度（默认对齐 [AppOverlay]）。
  final double topFadeHeight;
  final double bottomFadeHeight;

  /// 返回回调；为 null 时默认 `Navigator.pop`。
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    const mode = ModeThemes.love;
    return Scaffold(
      backgroundColor: mode.background,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Stack(
          children: [
            // 内容全屏铺底：滚动到浮层下方时被渐变遮罩自然淡出。
            Positioned.fill(child: child),
            // 顶部渐隐：内容滚动到浮层标题下方时过渡淡出。
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topFadeHeight,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        mode.background.withValues(alpha: 1),
                        mode.background.withValues(alpha: 0.9),
                        mode.background.withValues(alpha: 0),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // 底部渐变遮罩。
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: bottomFadeHeight,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        mode.background.withValues(alpha: 1),
                        mode.background.withValues(alpha: 0.85),
                        mode.background.withValues(alpha: 0),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // 顶部浮层：返回胶囊 + 标题 + 右侧动作。
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 16, 6),
                  child: Row(
                    children: [
                      PillButton(
                        icon: Icons.arrow_back_rounded,
                        label: '',
                        highlight: true,
                        onTap: onBack ?? () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (kicker != null) ...[
                              Text(
                                kicker!,
                                style: TextStyle(
                                  color: mode.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.12 * 10,
                                ),
                              ),
                              const SizedBox(height: 1),
                            ],
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: mode.text,
                                fontSize: 20,
                                fontWeight: mode.strongWeight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (topTrailing != null) topTrailing!,
                    ],
                  ),
                ),
              ),
            ),
            // 底部悬浮条。
            if (bottomBar != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: bottomBar!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 主题化确认弹窗（删除 / 危险操作统一用）。
///
/// 卡片语言 + 主色图标瓷片，返回 true/false 由调用方决定动作。
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
  IconData icon = Icons.error_outline,
}) async {
  const mode = ModeThemes.love;
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: mode.cardBackground,
      title: Text(title, style: TextStyle(color: mode.cardTitle)),
      content: Text(
        message,
        style: TextStyle(color: mode.cardBody, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel, style: TextStyle(color: mode.cardMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: mode.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// 便捷提示：主题化 FeedbackDialog（成功 / 失败 / 引导提示共用）。
void showFeedback(
  BuildContext context, {
  required String message,
  IconData icon = Icons.info_outline,
  String title = '提示',
}) {
  FeedbackDialog.show(
    context,
    message: message,
    icon: icon,
    title: title,
  );
}
