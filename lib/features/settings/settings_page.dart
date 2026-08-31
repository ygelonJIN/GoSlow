import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design/design.dart';
import '../../data/dict/dict_providers.dart';
import '../../data/models/word_entry.dart';
import '../../data/providers/app_providers.dart';
import '../../features/celebration/celebration_page.dart';
import '../../features/stats/stats_page.dart';
import '../../shared/entry_card.dart';
import '../../shared/section_header.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTag = ref.watch(examTagProvider);
    final highlightMode = ref.watch(highlightModeProvider);
    final knownCount = ref.watch(knownWordsProvider).length;
    final contentWordsAsync = ref.watch(contentWordsProvider);
    final favCount = ref.watch(favoriteWordSetProvider).length;

    return ListView(
      padding: EdgeInsets.only(
        top: AppOverlay.topInset(context),
        bottom: AppOverlay.bottomInset(context),
      ),
      children: [
        const SectionHeader('学习'),
        EntryCard(
          icon: Icons.filter_alt_outlined,
          title: '当前考纲',
          subtitle: currentTag == kAllTag
              ? '全部考纲'
              : (kExamTagNames[currentTag] ?? currentTag),
          onTap: () => _pickExamTag(context, ref, currentTag),
        ),
        EntryCard(
          icon: Icons.bar_chart_outlined,
          title: '统计',
          subtitle: '评级分布 / 掌握度曲线 / 成熟率 · 事件溯源驱动',
          onTap: () {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const StatsPage()));
          },
        ),
        EntryCard(
          icon: Icons.emoji_events_outlined,
          title: '里程碑',
          subtitle: '认识词数进度 / 庆祝回顾',
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MilestonesPage()));
          },
        ),
        Card(
          child: Padding(
            padding: AppInsets.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.seedSoft,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.palette_outlined, size: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '高亮样式',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: AppColors.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            highlightMode == HighlightMode.single
                                ? '单色 · 只标当前考纲'
                                : '多色 · 按考纲区分颜色',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<HighlightMode>(
                  segments: const [
                    ButtonSegment(
                      value: HighlightMode.single,
                      label: Text('单色'),
                      icon: Icon(Icons.circle, size: 14),
                    ),
                    ButtonSegment(
                      value: HighlightMode.multi,
                      label: Text('多色'),
                      icon: Icon(Icons.palette_outlined, size: 14),
                    ),
                  ],
                  selected: {highlightMode},
                  onSelectionChanged: (s) {
                    ref.read(highlightModeProvider.notifier).state = s.first;
                  },
                ),
                if (highlightMode == HighlightMode.multi) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final tag in kExamTags)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: HighlightPalette.forTag(tag)
                                .withValues(alpha: AppColors.alphaHighlightBg),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                            border: Border.all(
                              color: HighlightPalette.forTag(tag).withValues(
                                alpha: AppColors.alphaHighlightBorder,
                              ),
                            ),
                          ),
                          child: Text(
                            kExamTagNames[tag] ?? tag,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontSize: 10, color: AppColors.ink),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: AppInsets.card,
            child: Row(
              children: [
                _MiniStat(label: '已认识', value: '$knownCount'),
                Container(
                  width: 1,
                  height: 28,
                  color: AppColors.line,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                ),
                _MiniStat(label: '收藏', value: '$favCount'),
                Container(
                  width: 1,
                  height: 28,
                  color: AppColors.line,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                ),
                contentWordsAsync.when(
                  data: (w) => _MiniStat(label: '内容词', value: '${w.length}'),
                  loading: () => const _MiniStat(label: '内容词', value: '—'),
                  error: (_, _) => const _MiniStat(label: '内容词', value: '—'),
                ),
              ],
            ),
          ),
        ),
        const SectionHeader('关于'),
        const EntryCard(
          icon: Icons.backup_outlined,
          title: '数据备份',
          subtitle: '导出 / 导入 · M6 里程碑开放',
          enabled: false,
        ),
        const EntryCard(
          icon: Icons.info_outline,
          title: 'GoSlow',
          subtitle: '把考纲词汇镶嵌进真实的阅读、观影、听歌场景',
        ),
        Padding(
          padding: AppInsets.pageHorizontal.copyWith(top: AppSpacing.sm),
          child: Text(
            'M5 已就绪：内容词自动收集 · 点词三档自评 · epub/srt/lrc 阅读',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.inkMuted),
          ),
        ),
      ],
    );
  }

  Future<void> _pickExamTag(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: AppInsets.sectionHeader.copyWith(
                  bottom: AppSpacing.sm,
                ),
                child: Text(
                  '选择当前考纲',
                  style: Theme.of(ctx).textTheme.titleMedium
                      ?.copyWith(color: AppColors.ink),
                ),
              ),
              ListTile(
                title: const Text(
                  '全部考纲',
                  style: TextStyle(color: AppColors.ink),
                ),
                trailing: current == kAllTag
                    ? Icon(
                        Icons.check,
                        color: Theme.of(ctx).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.pop(ctx, kAllTag),
              ),
              for (final tag in kExamTags)
                ListTile(
                  title: Text(
                    kExamTagNames[tag] ?? tag,
                    style: const TextStyle(color: AppColors.ink),
                  ),
                  trailing: current == tag
                      ? Icon(
                          Icons.check,
                          color: Theme.of(ctx).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(ctx, tag),
                ),
            ],
          ),
        );
      },
    );
    if (picked != null) {
      ref.read(examTagProvider.notifier).state = picked;
    }
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.inkMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
