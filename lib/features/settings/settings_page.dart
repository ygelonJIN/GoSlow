import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design/design.dart';
import '../../data/dict/dict_providers.dart';
import '../../data/models/word_entry.dart';
import '../../features/celebration/celebration_page.dart';
import '../../features/stats/stats_page.dart';
import '../../shared/entry_card.dart';
import '../../shared/section_header.dart';
import '../../shared/segmented_pills.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightMode = ref.watch(highlightModeProvider);

    return ListView(
      padding: EdgeInsets.only(
        top: AppOverlay.topInset(context),
        bottom: AppOverlay.bottomInset(context) + AppSpacing.xl,
      ),
      children: [
        const SectionHeader('学习', padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.sm,
        )),
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
                SegmentedPills<HighlightMode>(
                  items: const [
                    SegmentedPillItem(
                      value: HighlightMode.single,
                      label: '单色',
                      icon: Icons.circle,
                    ),
                    SegmentedPillItem(
                      value: HighlightMode.multi,
                      label: '多色',
                      icon: Icons.palette_outlined,
                    ),
                  ],
                  selected: highlightMode,
                  onChanged: (v) {
                    ref.read(highlightModeProvider.notifier).state = v;
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
}
