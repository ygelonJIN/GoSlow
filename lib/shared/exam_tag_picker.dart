import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/design/design.dart';
import '../data/models/word_entry.dart';
import '../data/providers/app_providers.dart';
import 'app_sheet.dart';

/// 打开「当前考纲」选择底部面板（无页面跳转，主题化 CutBox 弹层），
/// 每次点击立即通过 [onChanged] 保存；关闭时返回当前选择集合。
///
/// 多选规则：可同时选中多个考纲；「全部考纲」互斥独占，选中后忽略其他选择；
/// 全部取消选中时按「全部考纲」处理。
Future<Set<String>?> showExamTagPicker(
  BuildContext context,
  Set<String> current, {
  ValueChanged<Set<String>>? onChanged,
}) {
  return showAppSheet<Set<String>>(
    context,
    builder: (_) => _ExamTagSheet(current: current, onChanged: onChanged),
  );
}

class _ExamTagSheet extends ConsumerStatefulWidget {
  const _ExamTagSheet({required this.current, this.onChanged});

  final Set<String> current;
  final ValueChanged<Set<String>>? onChanged;

  @override
  ConsumerState<_ExamTagSheet> createState() => _ExamTagSheetState();
}

class _ExamTagSheetState extends ConsumerState<_ExamTagSheet> {
  late Set<String> _selected = {...widget.current};

  void _toggleAll() {
    setState(() => _selected = {kAllTag});
    widget.onChanged?.call({..._selected});
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selected.contains(kAllTag)) {
        _selected = {tag};
      } else {
        if (!_selected.add(tag)) {
          _selected.remove(tag);
        }
      }
    });
    widget.onChanged?.call(_selected.isEmpty ? {kAllTag} : {..._selected});
  }

  void _saveAndClose() {
    Navigator.of(context).pop(
      _selected.isEmpty ? {kAllTag} : {..._selected},
    );
  }

  @override
  Widget build(BuildContext context) {
    final countsAsync = ref.watch(examTagCountsProvider);
    final counts = countsAsync.maybeWhen(
      data: (m) => m,
      orElse: () => const <String, ExamTagCounts>{},
    );
    final allSelected = _selected.contains(kAllTag);

    return WillPopScope(
      onWillPop: () async {
        _saveAndClose();
        return false;
      },
      child: AppSheetFrame(
        title: '选择当前考纲',
        caption: '可多选；「全部考纲」与其他考纲互斥',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSheetChoiceRow(
              title: kAllTagLabel,
              selected: allSelected,
              onTap: _toggleAll,
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final tag in kExamTags) ...[
              AppSheetChoiceRow(
                title: examTagName(tag),
                trailing: _countsLabel(counts[tag]),
                selected: !allSelected && _selected.contains(tag),
                onTap: () => _toggleTag(tag),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }

  static String _countsLabel(ExamTagCounts? c) {
    if (c == null) return '—';
    return '${c.total} / ${c.known}';
  }
}