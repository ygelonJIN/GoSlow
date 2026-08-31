import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design/design.dart';
import '../../data/models/milestone.dart';
import '../../data/models/review_stats.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/section_header.dart';

/// 里程碑庆祝页（M4）— 见 docs/design-spec.md §13。
///
/// 整页纸感：accent 暖金徽章 + display 大标题 + 达成数据 + 收获总结 +
/// 分享卡。无撒花动效，靠大留白完成仪式感。触发点：
/// 1. 闪卡结算后检测到新里程碑（自动整页弹出）；
/// 2. 设置页「里程碑」入口回看历史。
class CelebrationPage extends ConsumerWidget {
  const CelebrationPage({super.key, required this.threshold});

  /// 本次庆祝的认识词数里程碑（100/500/1000/2000/3000/5000）。
  final int threshold;

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
              'MILESTONE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.accent,
                    letterSpacing: 0.12 * 11,
                  ),
            ),
            Text('庆祝', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: AppInsets.pageHorizontal,
            child: Text('数据加载失败：$e', style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        data: (stats) => _CelebrationView(threshold: threshold, stats: stats),
      ),
    );
  }
}

class _CelebrationView extends StatelessWidget {
  const _CelebrationView({required this.threshold, required this.stats});

  final int threshold;
  final ReviewStats stats;

  @override
  Widget build(BuildContext context) {
    final next = _nextThreshold(threshold);

    return ListView(
      padding: AppInsets.pageVertical,
      children: [
        const SizedBox(height: AppSpacing.xl),
        // 里程碑徽章（§13：accent 前景 + accent 0.13 底）。
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: AppColors.alphaHighlightBg),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events_outlined, size: 30, color: AppColors.accent),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Text(
            'MILESTONE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.accent,
                  letterSpacing: 0.16 * 11,
                ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // 庆祝大标题（§13：display 字阶，居中）。
        Center(
          child: Text(
            '认识 $threshold 个词',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.ink,
                ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Padding(
            padding: AppInsets.pageHorizontal,
            child: Text(
              '慢慢来，比较快 —— 这 $threshold 个词正在成为你阅读里的老朋友',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                    height: 1.6,
                  ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl2),
        // 达成数据（§11 迷你统计行）。
        Card(
          child: Padding(
            padding: AppInsets.card,
            child: Row(
              children: [
                _MiniStat(label: '累计认识', value: '${stats.matureCount}'),
                Container(width: 1, height: 32, color: AppColors.line, margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm)),
                _MiniStat(label: '累计自评', value: '${stats.totalReviews}'),
                Container(width: 1, height: 32, color: AppColors.line, margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm)),
                _MiniStat(label: '连续天数', value: '${stats.streakDays}'),
                Container(width: 1, height: 32, color: AppColors.line, margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm)),
                _MiniStat(label: '认识率', value: '${_fmt(stats.goodRatePct)}%'),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // 收获总结卡（§13：quote 前缀 + 斜体引语）。
        Card(
          child: Padding(
            padding: AppInsets.card,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.format_quote_outlined, size: 18, color: AppColors.accent),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '认识 $threshold 词里程碑达成',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.ink),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        next == null
                            ? '你已经走过了这张词表的全程。接下来，去内容里遇见它们。'
                            : '离下一个里程碑「认识 $next 个词」还差 ${(next - stats.matureCount).clamp(0, next)} 个。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.inkMuted,
                              fontStyle: FontStyle.italic,
                              height: 1.6,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // 分享卡（§13：大标题 + 数据 + 日期 + 分享按钮）。
        Card(
          child: Padding(
            padding: AppInsets.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SHARE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.inkMuted,
                        letterSpacing: 0.12 * 11,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '我在 GoSlow 认识了 $threshold 个词',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '累计自评 ${stats.totalReviews} 次 · 认识率 ${_fmt(stats.goodRatePct)}% · 连续学习 ${stats.streakDays} 天',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _share(context, next),
                    icon: const Icon(Icons.ios_share, size: 16),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                      child: Text('复制分享文案'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl2),
        Padding(
          padding: AppInsets.pageHorizontal,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text('继续'),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Future<void> _share(BuildContext context, int? next) async {
    final text = [
      '我在 GoSlow 认识了 $threshold 个词',
      '累计自评 ${stats.totalReviews} 次 · 认识率 ${_fmt(stats.goodRatePct)}% · 连续学习 ${stats.streakDays} 天',
      next == null ? '' : '下一个里程碑：认识 $next 个词',
      '—— 把考纲词汇镶嵌进真实的阅读、观影、听歌场景',
    ].where((l) => l.isNotEmpty).join('\n');

    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('分享文案已复制')),
      );
    }
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return '${v.round()}';
    return v.toStringAsFixed(1);
  }
}

int? _nextThreshold(int current) {
  for (var i = 0; i < kKnownWordMilestones.length - 1; i++) {
    if (kKnownWordMilestones[i] == current) return kKnownWordMilestones[i + 1];
  }
  return null;
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

/// 里程碑历史页（设置页「里程碑」入口）：已庆祝里程碑 + 下一个目标。
class MilestonesPage extends ConsumerWidget {
  const MilestonesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievedAsync = ref.watch(achievedMilestonesProvider);
    final known = ref.watch(knownWordsProvider).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'MILESTONE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.inkMuted,
                    letterSpacing: 0.12 * 11,
                  ),
            ),
            Text('里程碑', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
      body: achievedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: AppInsets.pageHorizontal,
            child: Text('加载失败：$e', style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        data: (achieved) {
          final next = _firstUpreached(known);
          return ListView(
            padding: AppInsets.pageVertical,
            children: [
              const SectionHeader('进行中'),
              _NextMilestoneCard(known: known, next: next),
              const SectionHeader('已庆祝'),
              if (achieved.isEmpty)
                const _EmptyMilestoneCard()
              else
                for (final m in achieved.reversed)
                  Card(
                    child: ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: AppColors.alphaHighlightBg),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emoji_events_outlined, size: 18, color: AppColors.accent),
                      ),
                      title: Text(
                        '认识 ${m.threshold} 个词',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
                      ),
                      subtitle: Text(
                        '${m.achievedAt.year}-${m.achievedAt.month.toString().padLeft(2, '0')}-${m.achievedAt.day.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.chevron_right, size: 18, color: AppColors.inkMuted),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CelebrationPage(threshold: m.threshold),
                            ),
                          );
                        },
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => CelebrationPage(threshold: m.threshold),
                          ),
                        );
                      },
                    ),
                  ),
              const SizedBox(height: AppSpacing.md),
            ],
          );
        },
      ),
    );
  }

  int? _firstUpreached(int known) {
    for (final t in kKnownWordMilestones) {
      if (known < t) return t;
    }
    return null;
  }
}

class _NextMilestoneCard extends StatelessWidget {
  const _NextMilestoneCard({required this.known, required this.next});

  final int known;
  final int? next;

  @override
  Widget build(BuildContext context) {
    final next = this.next; // 局部变量以支持空安全提升
    final progress = next == null ? 1.0 : (known / next).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    next == null ? '认识词表全部走完' : '认识 $next 个词',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.ink),
                  ),
                ),
                Text(
                  next == null ? '$known 词' : '$known / $next',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: AppColors.line,
              ),
            ),
            if (next != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '还差 ${next - known} 个 · 闪卡与阅读里多遇见几次就到了',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyMilestoneCard extends StatelessWidget {
  const _EmptyMilestoneCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppInsets.card,
        child: Center(
          child: Text(
            '还没有达成里程碑 · 第一个是「认识 100 个词」',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
        ),
      ),
    );
  }
}
