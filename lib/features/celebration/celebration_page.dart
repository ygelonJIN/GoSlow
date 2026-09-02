import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design/design.dart';
import '../../data/models/content_entry.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/empty_state.dart';
import '../../shared/feedback_dialog.dart';
import '../../shared/overlay_page.dart';

/// 内容完成总结页（原里程碑庆祝页，逻辑改为「读完成一篇内容」）。
///
/// 触发方式：阅读页底部「标记已学完」手动点击后进入；或「已学完回顾」里
/// 回看历史。不再按照“认识多少个词”自动弹出。
class CelebrationPage extends ConsumerWidget {
  const CelebrationPage({super.key, required this.content});

  /// 已学完的内容。
  final ContentEntry content;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OverlayPage(
      title: '内容总结',
      kicker: 'MILESTONE',
      child: ContentCelebrationView(content: content),
    );
  }
}

/// 内容总结视图（庆祝页 / 回顾页共用）。
class ContentCelebrationView extends ConsumerWidget {
  const ContentCelebrationView({super.key, required this.content});

  final ContentEntry content;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(contentWordSummaryProvider(content.id));
    final completedAt = content.completedAt;

    return ListView(
      padding: EdgeInsets.only(
        top: AppOverlay.topInset(context),
        bottom: AppOverlay.bottomInset(context) + AppSpacing.xl,
      ),
      children: [
        // 完成徽章（accent 前景 + accent 0.13 底）。
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
            'FINISHED',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.accent,
                  letterSpacing: 0.16 * 11,
                ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // 总结标题：内容标题。
        Padding(
          padding: AppInsets.pageHorizontal,
          child: Text(
            '“${content.title}” 读完了',
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
              completedAt == null
                  ? '给自己一个小小的完成仪式 —— 这篇内容读完啦'
                  : '${_fmtDate(completedAt)} 完成 · ${content.displaySource} · ${content.wordCount} 词',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkMuted,
                    height: 1.6,
                  ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl2),
        // 本篇高亮词统计（内容级，替代旧的全局词数里程碑）。
        summaryAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xl3),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Card(
            margin: AppInsets.pageHorizontal,
            child: Padding(
              padding: AppInsets.card,
              child: Text(
                '统计加载失败：$e',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          data: (summary) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                margin: AppInsets.pageHorizontal,
                child: Padding(
                  padding: AppInsets.card,
                  child: Row(
                    children: [
                      _MiniStat(label: '内容词', value: '${summary.total}'),
                      Container(
                        width: 1,
                        height: 32,
                        color: AppColors.line,
                        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      ),
                      _MiniStat(label: '已认识', value: '${summary.known}'),
                      Container(
                        width: 1,
                        height: 32,
                        color: AppColors.line,
                        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      ),
                      _MiniStat(label: '待复习', value: '${summary.review}'),
                      Container(
                        width: 1,
                        height: 32,
                        color: AppColors.line,
                        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      ),
                      _MiniStat(label: '还没消化', value: '${summary.unfamiliarCount}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // 收获总结：还有哪些词要消化。
              Card(
                margin: AppInsets.pageHorizontal,
                child: Padding(
                  padding: AppInsets.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.format_quote_outlined,
                            size: 18,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              '慢慢来，比较快',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (summary.unfamiliarCount == 0)
                        Text(
                          '这篇里的考纲词你已经全部认识了，去内容页复习里再巩固几轮吧。',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.inkMuted,
                                fontStyle: FontStyle.italic,
                                height: 1.6,
                              ),
                        )
                      else
                        Text(
                          '这篇还有 ${summary.unfamiliarCount} 个词没完全消化，它们会出现在内容页「复习」里，直到变成老熟人。',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.inkMuted,
                                fontStyle: FontStyle.italic,
                                height: 1.6,
                              ),
                        ),
                    ],
                  ),
                ),
              ),
              if (summary.unfamiliar.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Card(
                  margin: AppInsets.pageHorizontal,
                  child: Padding(
                    padding: AppInsets.card,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '本篇还待消化的词',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: AppColors.inkMuted),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final w in summary.unfamiliar)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.seedSoft.withValues(
                                    alpha: AppColors.alphaSubtle,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.xs,
                                  ),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: Text(
                                  w,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: AppColors.ink),
                                ),
                              ),
                            if (summary.unfamiliarCount > summary.unfamiliar.length)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 4,
                                ),
                                child: Text(
                                  '+${summary.unfamiliarCount - summary.unfamiliar.length}',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(color: AppColors.inkMuted),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // 分享卡。
        Card(
          margin: AppInsets.pageHorizontal,
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
                  '我在 GoSlow 读完了《${content.title}》',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${content.wordCount} 词 · ${content.displaySource} · ${summaryAsync.maybeWhen(data: (s) => '${s.total} 个考纲词', orElse: () => '')}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _share(context, ref),
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
            onPressed: () => Navigator.of(context).maybePop(),
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

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final summaryAsync = ref.watch(contentWordSummaryProvider(content.id));
    final statsLine = summaryAsync
        .maybeWhen(data: (s) => '内容词 ${s.total} · 已认识 ${s.known} · 待复习 ${s.review}', orElse: () => '');
    final text = [
      '我在 GoSlow 读完了《${content.title}》',
      '${content.wordCount} 词 · ${content.displaySource} · $statsLine',
      '—— 把考纲词汇镶嵌进真实的阅读、观影、听歌场景',
    ].where((l) => l.isNotEmpty).join('\n');

    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      FeedbackDialog.show(
        context,
        message: '分享文案已复制',
        icon: Icons.check_circle_rounded,
        title: '已复制',
      );
    }
  }

  static String _fmtDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
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
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontSize: AppSpacing.statFontSize,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                ),
          ),
        ],
      ),
    );
  }
}

/// 掌握内容回顾页（设置页「掌握内容」入口，替代旧的词数里程碑历史）。
///
/// 列出所有标记过「已学完」的内容与完成时间，点开可回看内容总结。
class ContentDonePage extends ConsumerWidget {
  const ContentDonePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentsAsync = ref.watch(contentsProvider);

    return OverlayPage(
      title: '掌握内容',
      kicker: 'MILESTONE',
      child: contentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: AppInsets.pageHorizontal,
            child: Text('加载失败：$e', style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        data: (contents) {
          final done = contents.where((c) => c.isCompleted).toList()
            ..sort((a, b) {
              final at = (a.completedAt ?? a.createdAt).millisecondsSinceEpoch;
              final bt = (b.completedAt ?? b.createdAt).millisecondsSinceEpoch;
              return bt.compareTo(at);
            });
          if (done.isEmpty) {
            return Padding(
              padding: EdgeInsets.only(
                top: AppOverlay.topInset(context),
                bottom: AppOverlay.bottomInset(context) + AppSpacing.xl,
              ),
              child: const EmptyState(
                icon: Icons.emoji_events_outlined,
                title: '还没有读完的内容',
                subtitle: '读一篇内容，读完后在阅读页点「标记已学完」',
              ),
            );
          }
          return ListView(
            padding: EdgeInsets.only(
              top: AppOverlay.topInset(context),
              bottom: AppOverlay.bottomInset(context) + AppSpacing.xl,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  0,
                  AppSpacing.xl,
                  AppSpacing.sm,
                ),
                child: Text(
                  '${done.length} 篇已读完',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: AppColors.inkMuted),
                ),
              ),
              for (final c in done)
                Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xxs,
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: AppColors.alphaHighlightBg),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: AppColors.accent,
                      ),
                    ),
                    title: Text(
                      c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.ink),
                    ),
                    subtitle: Text(
                      '${_fmtDate(c.completedAt ?? c.createdAt)} · ${c.displaySource} · ${c.wordCount} 词',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.inkMuted,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CelebrationPage(content: c),
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

  static String _fmtDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}