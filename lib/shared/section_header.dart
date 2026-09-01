import 'package:flutter/material.dart';

import '../app/design/design.dart';

/// 区块标题（Paper Editorial v2.0 §9）。
/// 暖纸底上的 muted 小标题，跟踪 .08em，对齐预览 A 的 11px 区块头。
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.action, this.padding});

  final String text;
  final Widget? action;

  /// 覆盖默认内边距；页首第一个条目可传 `top: 0` 以对齐 [AppOverlay.topInset]。
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? AppInsets.sectionHeader,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
