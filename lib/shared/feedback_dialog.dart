import 'package:flutter/material.dart';

import '../app/design/app_radius.dart';
import '../app/design/app_spacing.dart';
import '../app/theme/fold_decoration.dart';
import '../app/theme/mode_theme.dart';

/// 全局限定的反馈（错误 / 提示共用一个组件），避免各处样式漂移。
///
/// 卡片色圆角面板 + 主色图标瓷片 + 标题 + 正文 + 「知道了」主按钮。
/// 全局主题下自动符合视觉规范，避免再用与主题格格不入的 SnackBar。
class FeedbackDialog {
  FeedbackDialog._();

  /// 打开一条主题化提示弹窗（默认信息图标）。
  static void show(
    BuildContext context, {
    ModeTheme? mode,
    required String message,
    IconData icon = Icons.info_outline,
    String title = '提示',
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _open(
      context,
      mode ?? ModeThemes.theme1,
      icon: icon,
      title: title,
      body: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// 错误反馈（默认警示图标）。
  static void error(
    BuildContext context,
    String message, {
    ModeTheme? mode,
    String title = '出错了',
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _open(
      context,
      mode ?? ModeThemes.theme1,
      icon: Icons.error_outline,
      title: title,
      body: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void _open(
    BuildContext context,
    ModeTheme mode, {
    required IconData icon,
    required String title,
    required String body,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => _FeedbackDialog(
        mode: mode,
        icon: icon,
        title: title,
        body: body,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );
  }
}

/// 反馈弹窗外观：卡片色 + 模式圆角 + 主色图标瓷片。
class _FeedbackDialog extends StatelessWidget {
  const _FeedbackDialog({
    required this.mode,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final ModeTheme mode;
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: CutBox(
        width: 292,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        fold: mode.cornerFold,
        color: mode.cardBackground,
        borderRadius: mode.cardRadius,
        border: Border.all(color: mode.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: (mode.cardShadowAlpha + 0.08).clamp(0, 1),
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: mode.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: 17, color: mode.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: mode.cardTitle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              body,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mode.cardMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onAction?.call();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pillHorizontal,
                    vertical: AppSpacing.pillVertical,
                  ),
                  shape: FoldShape(
                    borderRadius: mode.chipRadius,
                    fold: mode.cornerFold,
                  ),
                ),
                child: Text(
                  actionLabel ?? '知道了',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: mode.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
