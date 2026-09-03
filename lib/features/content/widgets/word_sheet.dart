import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/design.dart';
import '../../../data/dict/highlight_engine.dart';
import '../../../data/models/srs_card_state.dart';
import '../../../data/models/word_entry.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/services/tts_service.dart';
import '../../../shared/action_pill.dart';
import '../../../shared/app_sheet.dart';
import '../../../shared/meaning_card.dart';
import '../../../shared/rating_button.dart';
import '../../../shared/word_history_stats.dart';

/// 点词底部面板：与闪卡一致的「认 / 不认」流。
///
/// 正面：词 + 音标 + 朗读 / 收藏 + 三档自评 → 认识直接过（记录后关闭）；
/// 模糊 / 不认识 → 翻面进入「释义回顾」，看完点「完成」关闭。不再出现
/// 旧的「已记录本次自评」纯提示态。
Future<void> showWordSheet(
  BuildContext context,
  WidgetRef ref,
  HighlightSpan span,
) {
  return showAppSheet<void>(
    context,
    heightFactor: null,
    maxHeightFactor: 0.70,
    builder: (_) => _WordSheet(span: span),
  );
}

class _WordSheet extends ConsumerStatefulWidget {
  const _WordSheet({required this.span});

  final HighlightSpan span;

  @override
  ConsumerState<_WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends ConsumerState<_WordSheet> {
  bool _busy = false;

  /// 翻面到「释义回顾」后为 true（正面只出词 + 自评）。
  bool _flipped = false;

  String get _wordKey => widget.span.entry.word.toLowerCase();

  @override
  Widget build(BuildContext context) {
    final entry = widget.span.entry;
    final isFav = ref.watch(favoriteWordSetProvider).contains(_wordKey);

    return AppSheetFrame(
      title: _flipped ? '释义回顾' : null,
      scrollable: _flipped,
      showFades: _flipped,
      compact: !_flipped,
      scrollTopPadding: 80,
      scrollBottomPadding: 156,
      bottomFadeHeight: 120,
      child: _flipped
          ? _buildReview(context)
          : _buildFront(context, entry, isFav),
      bottomBar: _flipped
          ? FilledButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Text('完成'),
              ),
            )
          : null,
    );
  }

  /// 正面：词 + 音标 + 朗读 / 收藏 + 三档自评（与闪卡同款交互）。
  Widget _buildFront(BuildContext context, WordEntry entry, bool isFav) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          entry.word,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(color: AppColors.ink),
        ),
        if (entry.phonetic.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            entry.phonetic,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        WordHistoryStats(word: _wordKey),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            ActionPill(
              icon: Icons.volume_up_outlined,
              label: '朗读',
              onTap: () => TtsService.instance.speak(_wordKey),
            ),
            const SizedBox(width: AppSpacing.xs),
            ActionPill(
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
              child: RatingButton(
                dense: true,
                icon: Icons.check_circle_outline,
                label: '认识',
                fg: AppColors.card,
                bg: Theme.of(context).colorScheme.primary,
                border: Theme.of(context).colorScheme.primary,
                onTap: _busy ? null : () => _rate(SelfRating.known),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: RatingButton(
                dense: true,
                icon: Icons.sentiment_neutral_outlined,
                label: '模糊',
                fg: AppColors.ink,
                bg: AppColors.accent.withValues(
                  alpha: AppColors.alphaHighlightBg,
                ),
                border: AppColors.accent.withValues(
                  alpha: AppColors.alphaHighlightBorder,
                ),
                onTap: _busy ? null : () => _rate(SelfRating.familiar),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: RatingButton(
                dense: true,
                icon: Icons.cancel_outlined,
                label: '不认识',
                fg: AppColors.inkMuted,
                bg: AppColors.card,
                border: AppColors.line,
                onTap: _busy ? null : () => _rate(SelfRating.unknown),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(
            '认识 → 直接过；模糊 / 不认识 → 看释义回顾',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.inkMuted),
          ),
        ),
      ],
    );
  }

  /// 背面：释义回顾（与闪卡翻面一致）。
  Widget _buildReview(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MeaningCard(entry: widget.span.entry, showTags: false),
        const SizedBox(height: AppSpacing.lg),
      ],
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
      if (!mounted) return;
      if (rating == SelfRating.known) {
        // 认识 → 直接过：记录后关闭面板。
        Navigator.of(context).pop();
      } else {
        // 模糊 / 不认识 → 翻面看释义回顾。
        setState(() => _flipped = true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}