import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design/design.dart';
import '../../data/dict/dict_providers.dart';
import '../../data/models/srs_card_state.dart';
import '../../data/models/word_entry.dart';
import '../../data/providers/app_providers.dart';
import '../../data/services/tts_service.dart';
import '../../shared/empty_state.dart';
import '../../shared/meaning_card.dart';

class FavoritePage extends ConsumerWidget {
  const FavoritePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statesAsync = ref.watch(wordStatesProvider);
    final indexAsync = ref.watch(memoryIndexProvider);

    return statesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: AppInsets.card,
          child: Text('加载失败：$e', style: Theme.of(context).textTheme.bodySmall),
        ),
      ),
      data: (states) {
        final favKeys = [
          for (final e in states.entries)
            if (e.value.favorite) e.key,
        ]..sort();
        if (favKeys.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(
              top: AppOverlay.topInset(context),
              bottom: AppOverlay.bottomInset(context),
            ),
            child: const EmptyState(
              icon: Icons.star_outline,
              title: '还没有收藏',
              subtitle: '读内容时点高亮词，点“收藏”就来这里',
            ),
          );
        }
        return indexAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _FavListSimple(favKeys: favKeys),
          data: (index) => _FavList(index: index, favKeys: favKeys),
        );
      },
    );
  }
}

class _FavList extends ConsumerWidget {
  const _FavList({required this.favKeys, required this.index});

  final List<String> favKeys;
  final dynamic index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: EdgeInsets.only(
        top: AppOverlay.topInset(context),
        bottom: AppOverlay.bottomInset(context),
      ),
      children: [
        Padding(
          padding: AppInsets.sectionHeader,
          child: Text(
            '${favKeys.length} 个收藏',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: AppColors.inkMuted),
          ),
        ),
        for (final w in favKeys) _FavThumb(word: w, entry: index.words[w]),
      ],
    );
  }
}

class _FavListSimple extends ConsumerWidget {
  const _FavListSimple({required this.favKeys});

  final List<String> favKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: EdgeInsets.only(
        top: AppOverlay.topInset(context),
        bottom: AppOverlay.bottomInset(context),
      ),
      children: [
        Padding(
          padding: AppInsets.sectionHeader,
          child: Text(
            '${favKeys.length} 个收藏',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: AppColors.inkMuted),
          ),
        ),
        for (final w in favKeys) _FavThumb(word: w, entry: null),
      ],
    );
  }
}

/// 收藏缩略卡（§15.3）：单词 + 音标 + 首行释义单行省略；点击弹完整卡。
class _FavThumb extends ConsumerWidget {
  const _FavThumb({required this.word, required this.entry});

  final String word;
  final WordEntry? entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final firstLine = entry == null
        ? ''
        : (entry!.translation
              .split('\n')
              .firstWhere((l) => l.trim().isNotEmpty, orElse: () => ''));
    final subtitle = entry == null
        ? '词库未收录释义'
        : firstLine.isEmpty
        ? (entry!.definition.split('\n').firstOrNull ?? '')
        : firstLine;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxs,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: () => _openFull(context, ref, word, entry),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: AppInsets.card,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              entry?.word ?? word,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (entry?.phonetic.isNotEmpty ?? false) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(
                              child: Text(
                                entry!.phonetic,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.star, color: AppColors.seed, size: 20),
                  onPressed: () async {
                    final repo = ref.read(wordStateRepoProvider);
                    await repo.toggleFavorite(word);
                    ref.read(wordStateVersionProvider.notifier).state++;
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('已取消收藏')));
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openFull(
    BuildContext context,
    WidgetRef ref,
    String word,
    WordEntry? entry,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        side: BorderSide(color: AppColors.line),
      ),
      builder: (ctx) => _FavFullSheet(word: word, entry: entry),
    );
  }
}

/// 收藏完整卡浮窗：完整释义卡 + 朗读 + 三档自评 + 取消收藏。
class _FavFullSheet extends ConsumerStatefulWidget {
  const _FavFullSheet({required this.word, required this.entry});

  final String word;
  final WordEntry? entry;

  @override
  ConsumerState<_FavFullSheet> createState() => _FavFullSheetState();
}

class _FavFullSheetState extends ConsumerState<_FavFullSheet> {
  bool _busy = false;
  bool _rated = false;

  String get _wordKey => widget.word.toLowerCase();

  @override
  Widget build(BuildContext context) {
    final isFav = ref.watch(favoriteWordSetProvider).contains(_wordKey);

    return SafeArea(
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: SingleChildScrollView(
                child: widget.entry == null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xl3,
                        ),
                        child: Center(
                          child: Text(
                            '词库未收录释义',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      )
                    : MeaningCard(entry: widget.entry!, showTags: false),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                _Pill(
                  icon: Icons.volume_up_outlined,
                  label: '朗读',
                  onTap: () => TtsService.instance.speak(_wordKey),
                ),
                const SizedBox(width: AppSpacing.xs),
                _Pill(
                  icon: isFav ? Icons.star : Icons.star_outline,
                  label: isFav ? '已收藏' : '收藏',
                  filled: isFav,
                  onTap: _busy ? null : () => _toggleFavorite(),
                ),
                const Spacer(),
                Text(
                  '认识吗？',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _RateButton(
                    icon: Icons.check_circle_outline,
                    label: '认识',
                    fg: AppColors.card,
                    bg: Theme.of(context).colorScheme.primary,
                    border: Theme.of(context).colorScheme.primary,
                    onTap: (_busy || _rated)
                        ? null
                        : () => _rate(SelfRating.known),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _RateButton(
                    icon: Icons.sentiment_neutral_outlined,
                    label: '模糊',
                    fg: AppColors.ink,
                    bg: AppColors.accent.withValues(
                      alpha: AppColors.alphaHighlightBg,
                    ),
                    border: AppColors.accent.withValues(
                      alpha: AppColors.alphaHighlightBorder,
                    ),
                    onTap: (_busy || _rated)
                        ? null
                        : () => _rate(SelfRating.familiar),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _RateButton(
                    icon: Icons.cancel_outlined,
                    label: '不认识',
                    fg: AppColors.inkMuted,
                    bg: AppColors.card,
                    border: AppColors.line,
                    onTap: (_busy || _rated)
                        ? null
                        : () => _rate(SelfRating.unknown),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_rated)
              Center(
                child: Text(
                  '已记录本次自评 · 下次到期自动回来',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.inkMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(wordStateRepoProvider);
      await repo.toggleFavorite(_wordKey);
      ref.read(wordStateVersionProvider.notifier).state++;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rate(SelfRating rating) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(wordStateRepoProvider);
      await repo.recordFlashcardReview(_wordKey, rating);
      ref.read(wordStateVersionProvider.notifier).state++;
      if (mounted) setState(() => _rated = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    this.filled = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: filled
              ? scheme.primary.withValues(alpha: AppColors.alphaSubtle)
              : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: filled
                ? scheme.primary.withValues(alpha: 0.2)
                : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: filled ? scheme.primary : AppColors.inkMuted,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: filled ? scheme.primary : AppColors.ink,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RateButton extends StatelessWidget {
  const _RateButton({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
    required this.border,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;
  final Color border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: fg, letterSpacing: 0.04 * 13),
            ),
          ],
        ),
      ),
    );
  }
}
