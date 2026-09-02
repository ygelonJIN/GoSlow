import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/design/design.dart';
import '../data/models/word_entry.dart';
import '../data/providers/app_providers.dart';
import 'overlay_page.dart';
import 'pill_button.dart';

/// 打开「当前考纲」选择页（全屏），返回新的考纲选择集合；取消/返回 null。
///
/// 多选规则：可同时选中多个考纲；「全部考纲」互斥独占，选中后忽略其他选择；
/// 全部取消选中时按「全部考纲」处理。
Future<Set<String>?> showExamTagPicker(
  BuildContext context,
  Set<String> current,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<Set<String>>(
      builder: (_) => ExamTagPickerPage(current: current),
    ),
  );
}

/// 考纲选择页（全屏）：每行显示考纲名 + 总词数/已认识数，支持多选。
///
/// 全屏铺底 + 顶部/底部 50px 渐隐遮罩（见 OverlayPage 模板）；底部悬浮
/// 「完成」胶囊。全部取消选择时确认回退为「全部考纲」。
class ExamTagPickerPage extends ConsumerStatefulWidget {
  const ExamTagPickerPage({super.key, required this.current});

  final Set<String> current;

  @override
  ConsumerState<ExamTagPickerPage> createState() => _ExamTagPickerPageState();
}

class _ExamTagPickerPageState extends ConsumerState<ExamTagPickerPage> {
  late Set<String> _selected = {...widget.current};

  void _toggleAll() {
    setState(() => _selected = {kAllTag});
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selected.contains(kAllTag)) {
        // 从「全部」切到具体考纲：清空全部，只保留当前项。
        _selected = {tag};
        return;
      }
      if (!_selected.add(tag)) {
        _selected.remove(tag);
      }
    });
  }

  void _confirm() {
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

    return OverlayPage(
      title: '选择当前考纲',
      kicker: 'EXAM TAGS',
      topFadeHeight: 50,
      bottomFadeHeight: 50,
      bottomBar: PillButton(
        icon: Icons.check,
        label: '完成',
        highlight: true,
        onTap: _confirm,
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppOverlay.topInset(context),
          AppSpacing.lg,
          AppOverlay.bottomInset(context) + AppSpacing.xl3,
        ),
        children: [
          Text(
            '可多选；「全部考纲」与其他考纲互斥',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _ExamTagRow(
            title: '全部考纲',
            selected: allSelected,
            onTap: _toggleAll,
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final tag in kExamTags) ...[
            _ExamTagRow(
              title: kExamTagNames[tag] ?? tag,
              caption: _countsLabel(counts[tag]),
              selected: !allSelected && _selected.contains(tag),
              onTap: () => _toggleTag(tag),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }

  static String _countsLabel(ExamTagCounts? c) {
    if (c == null) return '—';
    return '${c.total} / ${c.known}';
  }
}

/// 考纲选择行：考纲名 + 词数（总/已认识）+ 选中态。
class _ExamTagRow extends StatelessWidget {
  const _ExamTagRow({
    required this.title,
    required this.selected,
    required this.onTap,
    this.caption,
  });

  final String title;
  final String? caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (caption != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Text(
                    caption!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 22,
                color: selected ? scheme.primary : AppColors.line,
              ),
            ],
          ),
        ),
      ),
    );
  }
}