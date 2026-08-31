import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design/design.dart';
import '../../data/models/review_stats.dart';
import '../../data/models/srs_card_state.dart';
import '../../data/models/word_state.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/section_header.dart';

/// 统计页（M4）：全部指标从 review_events 事件表聚合。
///
/// 版面遵循 Paper Editorial：纸底 + 纯白卡片 + 1px 线框 + 单色表达，
/// 无游戏化动效。曲线用等宽竖条表达"认识率"趋势（不引入图表依赖）。
class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(reviewStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'STATS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.inkMuted,
                    letterSpacing: 0.12 * 11,
                  ),
            ),
            Text('统计', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: AppInsets.pageHorizontal,
            child: Text('统计加载失败：$e', style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        data: (stats) => _StatsView(stats: stats),
      ),
    );
  }
}

class _StatsView extends StatelessWidget {
  const _StatsView({required this.stats});

  final ReviewStats stats;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppInsets.pageVertical,
      children: [
        const SectionHeader('总览'),
        Card(
          child: Padding(
            padding: AppInsets.card,
            child: Row(
              children: [
                _MiniStat(label: '累计自评', value: '${stats.totalReviews}'),
                Container(width: 1, height: 32, color: AppColors.line, margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm)),
                _MiniStat(label: '已认识', value: '${stats.matureCount}'),
                Container(width: 1, height: 32, color: AppColors.line, margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm)),
                _MiniStat(label: '待复习', value: '${stats.backlogCount}'),
                Container(width: 1, height: 32, color: AppColors.line, margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm)),
                _MiniStat(label: '共学习天', value: '${stats.totalStudyDays}'),
                Container(width: 1, height: 32, color: AppColors.line, margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm)),
                _MiniStat(label: '连续天数', value: '${stats.streakDays}'),
              ],
            ),
          ),
        ),
        if (stats.dailySeries.isNotEmpty) ...[
          const SectionHeader('掌握度曲线'),
          Card(
            child: Padding(
              padding: AppInsets.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '每天认识率（认识 / 全部自评）· 最近 ${stats.dailySeries.length} 天',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _TrendBars(series: stats.dailySeries),
                ],
              ),
            ),
          ),
        ],
        if (stats.monthlySeries.isNotEmpty) ...[
          const SectionHeader('月度汇总'),
          Card(
            child: Padding(
              padding: AppInsets.card,
              child: Column(
                children: [
                  for (final (i, m) in stats.monthlySeries.reversed.indexed) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    _PeriodRow(point: m),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (stats.yearlySeries.isNotEmpty) ...[
          const SectionHeader('年度汇总'),
          Card(
            child: Padding(
              padding: AppInsets.card,
              child: Column(
                children: [
                  for (final (i, y) in stats.yearlySeries.reversed.indexed) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    _PeriodRow(point: y),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SectionHeader('评级分布'),
        Card(
          child: Padding(
            padding: AppInsets.card,
            child: Column(
              children: [
                _RatingBar(
                  label: '认识',
                  pct: stats.ratingPct(FsrsRating.good),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                _RatingBar(
                  label: '模糊',
                  pct: stats.ratingPct(FsrsRating.hard),
                  color: AppColors.accent,
                ),
                const SizedBox(height: AppSpacing.md),
                _RatingBar(
                  label: '不认识',
                  pct: stats.ratingPct(FsrsRating.again),
                  color: AppColors.inkMuted,
                ),
              ],
            ),
          ),
        ),
        const SectionHeader('高阶数据'),
        Card(
          child: Padding(
            padding: AppInsets.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatLine(
                  label: '成熟转化率',
                  value: '${_fmt1(stats.matureConversionRatePct)}%',
                  note: '一个新词平均需经历 ${stats.totalReviews > 0 ? (stats.totalReviews / (stats.matureCount > 0 ? stats.matureCount : 1)).toStringAsFixed(1) : '--'} 次自评才能成熟',
                ),
                const Divider(),
                _StatLine(
                  label: '成熟词汇失忆率',
                  value: '${_fmt1(stats.forgetRatePct)}%',
                  note: '已进入长期记忆区的词（R≥0.9）被遗忘的概率',
                ),
                const Divider(),
                _StatLine(
                  label: '累计处理词汇',
                  value: '${stats.distinctLearnedWords}',
                  note: '有过自评记录的不同单词数',
                ),
              ],
            ),
          ),
        ),
        const SectionHeader('掌握分布'),
        Card(
          child: Padding(
            padding: AppInsets.card,
            child: Column(
              children: [
                _MasteryRow(
                  label: '已认识',
                  count: stats.masteryDistribution[WordStatus.known] ?? 0,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                _MasteryRow(
                  label: '学习中',
                  count: stats.masteryDistribution[WordStatus.learning] ?? 0,
                  color: AppColors.accent,
                ),
                const SizedBox(height: AppSpacing.md),
                _MasteryRow(
                  label: '模糊',
                  count: stats.masteryDistribution[WordStatus.familiar] ?? 0,
                  color: AppColors.inkMuted,
                ),
                const SizedBox(height: AppSpacing.md),
                _MasteryRow(
                  label: '未处理',
                  count: stats.masteryDistribution[WordStatus.unknown] ?? 0,
                  color: AppColors.line,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  static String _fmt1(double v) {
    if (v == v.roundToDouble()) return '${v.round()}';
    return v.toStringAsFixed(1);
  }
}

/// 月度/年度汇总行：周期名 + 认识率条 + 自评次数与百分比。
class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.point});

  final PeriodReviewPoint point;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(point.label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: point.goodRate.clamp(0.0, 1.0),
              minHeight: 6,
              color: Theme.of(context).colorScheme.primary,
              backgroundColor: AppColors.line,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 96,
          child: Text(
            '${point.reviews}次 · ${(point.goodRate * 100).round()}%',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
        ),
      ],
    );
  }
}

/// 评级占比条。
class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.label, required this.pct, required this.color});

  final String label;
  final double pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 6,
              color: color,
              backgroundColor: AppColors.line,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 52,
          child: Text(
            '${_fmt(pct)}%',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
        ),
      ],
    );
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return '${v.round()}';
    return v.toStringAsFixed(1);
  }
}

/// 高阶数据行：指标 + 说明。
class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value, required this.note});

  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink)),
            ),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.ink)),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(note, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted)),
      ],
    );
  }
}

/// 掌握分布行。
class _MasteryRow extends StatelessWidget {
  const _MasteryRow({required this.label, required this.count, required this.color});

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink)),
        ),
        Text('$count', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.ink)),
      ],
    );
  }
}

/// 掌握度曲线：等宽竖条，高度 = 当天认识率。
class _TrendBars extends StatelessWidget {
  const _TrendBars({required this.series});

  final List<DailyReviewPoint> series;

  @override
  Widget build(BuildContext context) {
    final visible = series.length > 14 ? series.sublist(series.length - 14) : series;
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final day in visible)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${(day.goodRate * 100).round()}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            color: AppColors.inkMuted,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      height: 8 + day.goodRate * 76,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(
                              alpha: day.goodRate >= 0.8
                                  ? AppColors.alphaHighlightBorder
                                  : AppColors.alphaHighlightBg,
                            ),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
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
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.ink)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted, fontSize: 11)),
        ],
      ),
    );
  }
}
