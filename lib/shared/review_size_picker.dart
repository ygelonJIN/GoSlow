import 'package:flutter/material.dart';

import '../app/design/design.dart';
import '../data/providers/app_providers.dart';
import 'app_sheet.dart';

/// 打开「复习每轮张数」选择底部面板（无页面跳转，主题化 CutBox 弹层），
/// 每次点击立即通过 [onChanged] 保存；返回值保留用于兼容调用方。
Future<int?> showReviewSizePicker(
  BuildContext context,
  int current, {
  ValueChanged<int>? onChanged,
}) {
  return showAppSheet<int>(
    context,
    builder: (_) => _ReviewSizeSheet(current: current, onChanged: onChanged),
  );
}

class _ReviewSizeSheet extends StatefulWidget {
  const _ReviewSizeSheet({required this.current, this.onChanged});

  final int current;
  final ValueChanged<int>? onChanged;

  @override
  State<_ReviewSizeSheet> createState() => _ReviewSizeSheetState();
}

class _ReviewSizeSheetState extends State<_ReviewSizeSheet> {
  late int _selected = widget.current;

  @override
  Widget build(BuildContext context) {
    return AppSheetFrame(
      title: '复习每轮张数',
      caption: '每轮抽几张内容词卡',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final size in kReviewSessionSizes) ...[
            AppSheetChoiceRow(
              title: formatSessionSize(size),
              selected: _selected == size,
              onTap: () {
                setState(() => _selected = size);
                widget.onChanged?.call(size);
              },
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}