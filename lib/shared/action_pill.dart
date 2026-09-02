import 'package:flutter/material.dart';

import '../app/design/app_colors.dart';
import '../app/design/app_radius.dart';
import '../app/design/app_spacing.dart';

/// 紧凑动作胶囊（朗读 / 收藏等行内小操作）——全局唯一实现。
///
/// 视觉语言：seedSoft 底 + line 描边 + 全圆胶囊；`filled` 态（如已收藏）
/// 切为主色淡底 + 主色描边。字号 / 间距 / 图标尺寸全部走 `AppSpacing` 令牌。
class ActionPill extends StatelessWidget {
  const ActionPill({
    super.key,
    required this.icon,
    required this.label,
    this.filled = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: filled
              ? scheme.primary.withValues(alpha: AppColors.alphaSubtle)
              : AppColors.seedSoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: filled
                ? scheme.primary.withValues(alpha: 0.2)
                : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSpacing.pillIcon, color: scheme.primary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}