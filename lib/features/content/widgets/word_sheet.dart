import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/design.dart';
import '../../../data/dict/highlight_engine.dart';
import '../../../data/models/srs_card_state.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/services/tts_service.dart';
import '../../../shared/meaning_card.dart';

/// 点词底部面板：释义卡（词性一行）+ 朗读/收藏 + 三档自评（直接落 FSRS）。
///
/// 点高亮词即学习：认识/模糊/不认识 三档等宽并排，点击直接写 review 事件，
/// 不翻面、不弹二次确认（见 docs/design-spec.md §15.2）。
Future<void> showWordSheet(
  BuildContext context,
  WidgetRef ref,
  HighlightSpan span,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      side: BorderSide(color: AppColors.line),
    ),
    builder: (ctx) => _WordSheet(
      span: span,
    ),
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
  bool _rated = false;

  String get _wordKey => widget.span.entry.word.toLowerCase();

  @override
  Widget build(BuildContext context) {
    final entry = widget.span.entry;
    final isFav = ref.watch(favoriteWordSetProvider).contains(_wordKey);

    return SafeArea(
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DragHandle(),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: SingleChildScrollView(
                child: MeaningCard(entry: entry, showTags: false),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                _ActionPill(
                  icon: Icons.volume_up_outlined,
                  label: '朗读',
                  onTap: () => TtsService.instance.speak(_wordKey),
                ),
                const SizedBox(width: AppSpacing.xs),
                _ActionPill(
                  icon: isFav ? Icons.star : Icons.star_outline,
                  label: isFav ? '已收藏' : '收藏',
                  filled: isFav,
                  onTap: _busy ? null : () => _toggleFavorite(),
                ),
                const Spacer(),
                Text(
                  '认识吗？',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
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
                    onTap: (_busy || _rated) ? null : () => _rate(SelfRating.known),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _RateButton(
                    icon: Icons.sentiment_neutral_outlined,
                    label: '模糊',
                    fg: AppColors.ink,
                    bg: AppColors.accent.withValues(alpha: AppColors.alphaHighlightBg),
                    border: AppColors.accent.withValues(alpha: AppColors.alphaHighlightBorder),
                    onTap: (_busy || _rated) ? null : () => _rate(SelfRating.familiar),
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
                    onTap: (_busy || _rated) ? null : () => _rate(SelfRating.unknown),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_rated)
              Center(
                child: Text(
                  '已记录本次自评 · 下次到期自动回来',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
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

/// 底部面板拖拽条（§13 底部释义面板同款）。
class DragHandle extends StatelessWidget {
  const DragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.line,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: filled ? scheme.primary.withValues(alpha: AppColors.alphaSubtle) : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: filled ? scheme.primary.withValues(alpha: 0.2) : AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: filled ? scheme.primary : AppColors.inkMuted),
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
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: fg,
                    letterSpacing: 0.04 * 13,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
