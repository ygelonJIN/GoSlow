import 'package:flutter/material.dart';

import '../app/design/app_spacing.dart';
import '../app/theme/fold_decoration.dart';
import '../app/theme/mode_theme.dart';

/// 三档自评按钮（认识 / 模糊 / 不认识）——全局唯一实现。
///
/// 主题化：全圆胶囊（`chipRadius`）+ 图标 / 文字竖排 + 语义色。
/// 颜色沿用设计规范 §6「三档自评」：
/// - 认识：`primary` 实底 + 浅色文字
/// - 模糊：`accent` 13% 淡底 + accent 描边
/// - 不认识：`card` 底 + `line` 描边
///
/// 高度由 `AppSpacing` 胶囊令牌驱动，不硬编码。
class RatingButton extends StatelessWidget {
  const RatingButton({
    super.key,
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
    required this.border,
    this.onTap,
    this.dense = false,
  });

  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;
  final Color border;
  final VoidCallback? onTap;

  /// 紧凑态（用于底部释义面板 / 收藏页浮窗，略矮）。
  final bool dense;

  @override
  Widget build(BuildContext context) {
    const theme = ModeThemes.theme1;
    return Material(
      color: bg,
      shape: FoldShape(
        borderRadius: theme.chipRadius,
        side: BorderSide(color: border, width: 1),
        fold: theme.cornerFold,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: dense ? AppSpacing.sm : AppSpacing.pillVertical,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: dense ? 20 : 22, color: fg),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: fg, letterSpacing: 0.04 * 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
