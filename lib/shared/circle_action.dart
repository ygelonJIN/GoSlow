import 'package:flutter/material.dart';

import '../app/design/design.dart';

/// 圆形图标按钮（纸感 §10）：30×30 墨底圆 + 纸色图标。
///
/// 顶部浮层标题栏右侧的动作按钮（如内容页「+」）。
class CircleAction extends StatelessWidget {
  const CircleAction({super.key, required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: AppColors.ink,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: AppColors.card),
      ),
    );
  }
}
