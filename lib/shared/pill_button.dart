import 'package:flutter/material.dart';

import '../app/design/app_spacing.dart';
import '../app/theme/fold_decoration.dart';
import '../app/theme/mode_theme.dart';

/// 胶囊形态的通用按钮，用于顶部栏、底部悬浮条等处的操作。
///
/// 视觉完全由 `ModeTheme` 驱动（GoSlow 全局主题）：
/// - `highlight = true`：主色填充（选中 / 强调态）
/// - `highlight = false`：表面色填充（普通态）
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.icon,
    required this.label,
    this.mode,
    this.highlight = false,
    this.compact = false,
    this.onTap,
  });

  final ModeTheme? mode;
  final IconData icon;
  final String label;

  /// 是否高亮（主色填充）。
  final bool highlight;

  /// 是否紧凑（更小的内边距，用于日期等次要信息）。
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = mode ?? ModeThemes.theme1;
    final scheme = Theme.of(context).colorScheme;
    final foreground = highlight ? scheme.onPrimary : theme.chipForeground;
    final background = highlight ? scheme.primary : theme.chipBackground;
    final borderColor = (highlight ? scheme.primary : theme.chipBorder)
        .withValues(alpha: 0.55);

    final inkBorderRadius = theme.cornerFold ? null : theme.chipRadius;

    return Material(
      color: background,
      shape: FoldShape(
        borderRadius: theme.chipRadius,
        side: BorderSide(color: borderColor, width: 1),
        fold: theme.cornerFold,
      ),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: inkBorderRadius,
        customBorder: theme.cornerFold
            ? const FoldShape(
                borderRadius: BorderRadius.zero,
                side: BorderSide.none,
                fold: true,
              )
            : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.md : AppSpacing.pillHorizontal,
            vertical: compact ? 9 : AppSpacing.pillVertical,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: AppSpacing.pillIcon, color: foreground),
              if (label.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.pillGap),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppSpacing.pillFontSize,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
