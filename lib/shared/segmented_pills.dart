import 'package:flutter/material.dart';

import '../app/design/app_spacing.dart';
import '../app/theme/fold_decoration.dart';
import '../app/theme/mode_theme.dart';

/// 胶囊形态的分段选择器（闪卡来源 / 本轮内容 / 每轮张数等）。
///
/// 视觉与全局 [PillButton] 完全同构（同高 / 同圆角 / 同字号），由
/// `ModeTheme` 令牌驱动：
/// - 未选中：`chipBackground` 底 + `chipBorder` 55% 描边（PillButton 普通态）
/// - 选中：`primary` 0.16 淡底 + `primary` 前景（主题选中态，同 SegmentedButton）
///
/// 高度不硬编码：垂直内边距 / 图标 / 字号复用 `AppSpacing` 胶囊令牌，
/// 天然与「收藏 / 添加」等 PillButton 等高。
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  /// 候选项（至少一个；两个及以上时均分宽度）。
  final List<SegmentedPillItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    const theme = ModeThemes.love;
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: _PillItem<T>(
              theme: theme,
              item: items[i],
              isSelected: items[i].value == selected,
              onTap: onChanged,
            ),
          ),
        ],
      ],
    );
  }
}

class SegmentedPillItem<T> {
  const SegmentedPillItem({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

class _PillItem<T> extends StatelessWidget {
  const _PillItem({
    required this.theme,
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final ModeTheme theme;
  final SegmentedPillItem<T> item;
  final bool isSelected;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 选中态 = 实底高亮按钮：primary 填充 + onPrimary 文字，无描边；
    // 未选中 = chipBackground 底 + chipBorder 55% 描边（与 PillButton 普通态一致）。
    final foreground = isSelected ? scheme.onPrimary : theme.chipForeground;
    final background = isSelected ? scheme.primary : theme.chipBackground;
    final borderColor = isSelected
        ? Colors.transparent
        : theme.chipBorder.withValues(alpha: 0.55);

    return Material(
      color: background,
      shape: FoldShape(
        borderRadius: theme.chipRadius,
        side: BorderSide(color: borderColor, width: 1),
        fold: theme.cornerFold,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(item.value),
        customBorder: theme.cornerFold
            ? const FoldShape(
                borderRadius: BorderRadius.zero,
                side: BorderSide.none,
                fold: true,
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.pillVertical),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (item.icon != null) ...[
                Icon(item.icon, size: 16, color: foreground),
                const SizedBox(width: AppSpacing.pillGap),
              ],
              Flexible(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppSpacing.pillFontSize,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}