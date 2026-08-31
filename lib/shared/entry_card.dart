import 'package:flutter/material.dart';

import '../app/design/design.dart';

/// 列表入口卡片 v2.0（Paper Editorial）。
///
/// 纯白卡 + 1px line 描边 + seedSoft 图标底，对齐预览 A 圆角 16 / 内距 20·16。
class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleColor = enabled ? AppColors.ink : AppColors.inkMuted;
    return Card(
      child: ListTile(
        enabled: enabled,
        onTap: enabled ? onTap : null,
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: enabled
              ? AppColors.seedSoft
              : AppColors.line.withValues(alpha: AppColors.alphaSurface),
          foregroundColor: enabled ? scheme.primary : AppColors.inkMuted,
          child: Icon(icon, size: AppSpacing.cardIcon),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: titleColor,
              ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.inkMuted,
              ),
        ),
        trailing: trailing ??
            (enabled
                ? const Icon(Icons.chevron_right, color: AppColors.inkMuted, size: 20)
                : null),
      ),
    );
  }
}
