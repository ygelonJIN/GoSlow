import 'package:flutter/material.dart';

import '../app/design/app_radius.dart';
import '../app/design/app_spacing.dart';
import '../app/theme/mode_theme.dart';

/// 圆形图标按钮：主色底圆 + 纸色图标。
///
/// 顶部浮层标题栏右侧的动作按钮（如内容页「+」）。
class CircleAction extends StatelessWidget {
  const CircleAction({super.key, required this.icon, this.onTap, this.mode});

  final IconData icon;
  final VoidCallback? onTap;
  final ModeTheme? mode;

  @override
  Widget build(BuildContext context) {
    final theme = mode ?? ModeThemes.theme1;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: theme.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: AppSpacing.pillIcon, color: theme.onPrimary),
      ),
    );
  }
}
