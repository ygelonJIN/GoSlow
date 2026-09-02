import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design/design.dart';
import '../../app/theme/fold_decoration.dart';
import '../../app/theme/mode_theme.dart';
import '../../data/dict/dict_database.dart';
import '../../data/models/review_outcome.dart';
import '../../data/models/srs_card_state.dart';
import '../../data/models/word_state.dart';
import '../../data/providers/app_providers.dart';
import '../../data/services/tts_service.dart';
import '../../shared/action_pill.dart';
import '../../shared/feedback_dialog.dart';
import '../../shared/meaning_card.dart';
import '../../shared/pill_button.dart';
import '../../shared/rating_button.dart';
import '../../shared/word_history_stats.dart';

/// 内容词复习会话：把“内容里出现过的词”按 FSRS 到期队列 + 新词组牌，
/// 以识别式闪卡形式逐张自评（认识直接过；模糊/不认识翻面看释义）。
///
/// 进入方式：内容页顶部「复习」入口。整张闪卡 = 全屏纸色背景 + 上下渐隐 +
/// 顶部进度 + 底部三档自评；无开始配置页，每轮张数在首页顶部学习入口卡
/// 设置，自动朗读在设置页「复习」区设置。
Future<void> pushContentReviewSession(
  BuildContext context,
  WidgetRef ref,
) async {
  final deck = await buildContentReviewDeck(ref);
  if (deck.isEmpty) {
    if (context.mounted) {
      FeedbackDialog.show(
        context,
        message: '暂时没有到期复习的词，也没有内容里未认识的新词',
      );
    }
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ReviewSessionPage(
        deck: deck,
        knownSnapshot: readKnownSnapshot(ref),
      ),
    ),
  );
}

/// 组一轮内容词复习牌堆：先复习 FSRS 到期卡，再补内容里未认识的新词。
Future<List<String>> buildContentReviewDeck(WidgetRef ref) async {
  final settings = ref.read(flashcardSettingsProvider);
  final repo = ref.read(wordStateRepoProvider);
  return repo.flashcardDeck(
    sessionSize: settings.sessionSize,
    candidateNew: await ref.read(contentWordsProvider.future),
  );
}

/// 快照当前已认识集合（结算「本轮新认识」计数用）。
Set<String> readKnownSnapshot(WidgetRef ref) {
  final states = ref
      .read(wordStatesProvider)
      .maybeWhen(data: (m) => m, orElse: () => <String, WordState>{});
  return {
    for (final e in states.entries)
      if (e.value.status == WordStatus.known) e.key,
  };
}

/// 单张闪卡的学习会话：全屏内容，与 OverlayPage 同构的浮层骨架。
class ReviewSessionPage extends ConsumerStatefulWidget {
  const ReviewSessionPage({
    super.key,
    required this.deck,
    required this.knownSnapshot,
  });

  final List<String> deck;
  final Set<String> knownSnapshot;

  @override
  ConsumerState<ReviewSessionPage> createState() => _ReviewSessionPageState();
}

enum _Phase { running, summary }

class _ReviewSessionPageState extends ConsumerState<ReviewSessionPage> {
  _Phase _phase = _Phase.running;
  late List<String> _deck = widget.deck;
  Set<String> _knownSnapshot = const {};
  int _index = 0;
  bool _flipped = false;
  final List<SessionEntry> _entries = [];
  int _newKnown = 0;
  bool _busy = false;

  String get _word => _index < _deck.length ? _deck[_index] : '';

  @override
  void initState() {
    super.initState();
    _knownSnapshot = widget.knownSnapshot;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeSpeak(_word, ref.read(flashcardSettingsProvider));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: switch (_phase) {
        _Phase.running => _buildRunning(context),
        _Phase.summary => _buildSummary(context),
      },
    );
  }

  // ---------------------------------------------------------------------
  // 学习中：全屏背景卡 + 上下渐隐 + 顶部进度 / 底部悬浮按钮
  // ---------------------------------------------------------------------

  Widget _buildRunning(BuildContext context) {
    final entryAsync = ref.watch(flashcardEntryProvider(_word));
    final progress = (_index + 1) / _deck.length;

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: AppMotion.durationMedium,
            switchInCurve: AppMotion.curveStandard,
            switchOutCurve: AppMotion.curveStandard,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.985, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            child: _flipped
                ? _buildBack(context, entryAsync)
                : _buildFront(context, entryAsync),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: AppOverlay.topFadeHeight,
          child: IgnorePointer(
            child: DecoratedBox(decoration: AppOverlay.topFade()),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: AppOverlay.bottomScrimHeight(context),
          child: IgnorePointer(
            child: DecoratedBox(decoration: AppOverlay.bottomFade()),
          ),
        ),
        // 顶部浮层：退出 + 进度计数 / 状态 + 进度条。
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 16, 6),
              child: Column(
                children: [
                  Row(
                    children: [
                      PillButton(
                        icon: Icons.arrow_back_rounded,
                        label: '',
                        highlight: true,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                      if (_flipped) ...[
                        Text(
                          '待复习',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.accent,
                                letterSpacing: 0.08 * 11,
                              ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Text(
                        '${_index + 1} / ${_deck.length}',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: AppColors.inkMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      color: Theme.of(context).colorScheme.primary,
                      backgroundColor: AppColors.line,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: _flipped ? _buildNextButton(context) : _buildRating(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFront(
    BuildContext context,
    AsyncValue<LookupResult?> entryAsync,
  ) {
    final entry = entryAsync.maybeWhen(
      data: (r) => r?.entry,
      orElse: () => null,
    );
    return ColoredBox(
      key: const ValueKey('front'),
      color: AppColors.paper,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppOverlay.topInset(context) - AppSpacing.xl2,
          AppSpacing.lg,
          AppOverlay.bottomInset(context) + AppSpacing.xl3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '看到即秒认',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.inkMuted,
                    letterSpacing: 0.08 * 11,
                  ),
                ),
                const Spacer(),
                ActionPill(
                  icon: Icons.volume_up_outlined,
                  label: '朗读',
                  onTap: () => TtsService.instance.speak(_word),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _word,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: AppColors.ink),
                    ),
                    if (entry?.phonetic != null &&
                        entry!.phonetic.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        entry.phonetic,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    WordHistoryStats(word: _word),
                  ],
                ),
              ),
            ),
            Center(
              child: Text(
                '这个单词认识吗？',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBack(
    BuildContext context,
    AsyncValue<LookupResult?> entryAsync,
  ) {
    return ColoredBox(
      key: const ValueKey('back'),
      color: AppColors.paper,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppOverlay.topInset(context) - AppSpacing.xl2,
          AppSpacing.lg,
          AppOverlay.bottomInset(context) + AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '释义回顾',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.inkMuted,
                letterSpacing: 0.08 * 11,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            entryAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl3),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl3),
                child: Center(
                  child: Text(
                    '释义加载失败：$e',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              data: (r) {
                if (r == null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xl3,
                    ),
                    child: Center(
                      child: Text(
                        '词库中暂无释义',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  );
                }
                return MeaningCard(
                  entry: r.entry,
                  leadingWord: r.matched != r.entry.word ? r.matched : null,
                  showTags: false,
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl3),
          ],
        ),
      ),
    );
  }

  Widget _buildRating(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: RatingButton(
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
            icon: Icons.sentiment_neutral_outlined,
            label: '模糊',
            fg: AppColors.ink,
            bg: AppColors.accent.withValues(alpha: AppColors.alphaHighlightBg),
            border: AppColors.accent.withValues(
              alpha: AppColors.alphaHighlightBorder,
            ),
            onTap: _busy ? null : () => _rate(SelfRating.familiar),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: RatingButton(
            icon: Icons.cancel_outlined,
            label: '不认识',
            fg: AppColors.inkMuted,
            bg: AppColors.card,
            border: AppColors.line,
            onTap: _busy ? null : () => _rate(SelfRating.unknown),
          ),
        ),
      ],
    );
  }

  Widget _buildNextButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _busy ? null : _advance,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Text('下一张'),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 结算页
  // ---------------------------------------------------------------------

  Widget _buildSummary(BuildContext context) {
    final knownCount = ref.watch(knownWordsProvider).length;
    final stats = computeSessionStats(_entries);
    final known = stats.ratingDistribution[SelfRating.known] ?? 0;
    final familiar = stats.ratingDistribution[SelfRating.familiar] ?? 0;
    final unknown = stats.ratingDistribution[SelfRating.unknown] ?? 0;

    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.paper)),
        Positioned.fill(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppOverlay.topInset(context),
              AppSpacing.xl,
              AppOverlay.bottomInset(context) + AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  size: AppSpacing.emptyIcon,
                  color: AppColors.accent,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '本回合完成',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '共 ${stats.totalCards} 张 · 认识 $known · 模糊 $familiar · 不认识 $unknown',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.xl2),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: AppInsets.card,
                    child: Column(
                      children: [
                        _SummaryRow(
                          icon: Icons.auto_awesome_outlined,
                          label: '本轮新认识',
                          value: '$_newKnown',
                          emphasize: true,
                        ),
                        const Divider(),
                        _SummaryRow(
                          icon: Icons.style_outlined,
                          label: '累计认识',
                          value: '$knownCount',
                        ),
                        const Divider(),
                        _SummaryRow(
                          icon: Icons.replay_outlined,
                          label: '待复习',
                          value: '$familiar',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _SummaryCard(
                  title: '本回合评级',
                  children: [
                    _RatingLine(
                      label: '认识',
                      count: known,
                      total: stats.totalCards,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _RatingLine(
                      label: '模糊',
                      count: familiar,
                      total: stats.totalCards,
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _RatingLine(
                      label: '不认识',
                      count: unknown,
                      total: stats.totalCards,
                      color: AppColors.inkMuted,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SummaryCard(
                  title: '记忆变化（FSRS）',
                  children: [
                    _StatLine(
                      label: '平均稳定性变化',
                      value: _fmtSigned(
                        stats.avgStabilityChange,
                        suffix: ' 天',
                      ),
                      note: 'S = 下次复习间隔的底数。正 = 本轮整体记得更牢',
                    ),
                    const Divider(),
                    _StatLine(
                      label: '平均可提取性变化',
                      value: _fmtSigned(
                        stats.avgRetrievabilityChange * 100,
                        suffix: '%',
                      ),
                      note: 'R = 本轮自评时的记忆可提取性变化',
                    ),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: _InlineStat(
                            label: '新学',
                            value: '${stats.newCards}',
                          ),
                        ),
                        Expanded(
                          child: _InlineStat(
                            label: '复习',
                            value: '${stats.reviewCards}',
                          ),
                        ),
                        Expanded(
                          child: _InlineStat(
                            label: '重学',
                            value: '${stats.relearnCards}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (stats.spellings.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _SummaryCard(
                    title: '本轮词汇',
                    children: [
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final w in stats.spellings)
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
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: AppOverlay.topFadeHeight,
          child: IgnorePointer(
            child: DecoratedBox(decoration: AppOverlay.topFade()),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: AppOverlay.bottomScrimHeight(context),
          child: IgnorePointer(
            child: DecoratedBox(decoration: AppOverlay.bottomFade()),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _restart,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                        ),
                        child: Text('再来一轮'),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: ModeThemes.theme1.chipBackground,
                        foregroundColor: ModeThemes.theme1.chipForeground,
                        side: BorderSide(
                          color: ModeThemes.theme1.chipBorder.withValues(
                            alpha: 0.55,
                          ),
                        ),
                        shape: FoldShape(
                          borderRadius: ModeThemes.theme1.chipRadius,
                          fold: ModeThemes.theme1.cornerFold,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.primaryButtonHorizontal,
                          vertical: AppSpacing.primaryButtonVertical,
                        ),
                      ),
                      child: const Text('返回'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 动作
  // ---------------------------------------------------------------------

  Future<void> _restart() async {
    setState(() => _busy = true);
    try {
      final deck = await buildContentReviewDeck(ref);
      final snapshot = readKnownSnapshot(ref);
      if (deck.isEmpty) {
        if (mounted) {
          FeedbackDialog.show(
            context,
            message: '暂时没有到期复习的词，也没有内容里未认识的新词',
            actionLabel: '返回',
            onAction: () => Navigator.of(context).pop(),
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _deck = deck;
        _knownSnapshot = snapshot;
        _index = 0;
        _flipped = false;
        _entries.clear();
        _newKnown = 0;
        _phase = _Phase.running;
      });
      _maybeSpeak(deck.first, ref.read(flashcardSettingsProvider));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rate(SelfRating rating) async {
    if (_flipped) return;
    setState(() => _busy = true);
    try {
      final word = _word;
      final repo = ref.read(wordStateRepoProvider);
      final outcome = await repo.recordFlashcardReview(word, rating);
      final next = outcome.post;

      if (!_knownSnapshot.contains(word) && next.status == WordStatus.known) {
        _newKnown++;
      }
      _entries.add(SessionEntry(rating: rating, outcome: outcome));
      ref.read(wordStateVersionProvider.notifier).state++;

      if (rating == SelfRating.known) {
        _advance();
      } else {
        setState(() => _flipped = true);
      }
      if (!mounted) return;
      if (_flipped) _maybeSpeakReview();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _advance() {
    final settings = ref.read(flashcardSettingsProvider);
    final nextIndex = _index + 1;
    if (nextIndex >= _deck.length) {
      setState(() {
        _flipped = false;
        _phase = _Phase.summary;
      });
      return;
    }
    setState(() {
      _flipped = false;
      _index = nextIndex;
    });
    _maybeSpeak(_deck[nextIndex], settings);
  }

  void _maybeSpeakReview() {
    final settings = ref.read(flashcardSettingsProvider);
    if (settings.autoSpeak) {
      TtsService.instance.speak(_word);
    }
  }

  void _maybeSpeak(String word, FlashcardSettings settings) {
    if (settings.autoSpeak) {
      TtsService.instance.speak(word);
    }
  }
}

// ---------------------------------------------------------------------------
// 小组件与纯函数
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _RatingLine extends StatelessWidget {
  const _RatingLine({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  final String label;
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.ink),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: pct,
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
            '${(pct * 100).round()}%',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.inkMuted),
          ),
        ),
      ],
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({
    required this.label,
    required this.value,
    required this.note,
  });

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
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.ink),
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.ink,
                fontSize: AppSpacing.statFontSize,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          note,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.ink,
            fontSize: AppSpacing.statFontSize,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

String _fmtSigned(double v, {String suffix = ''}) {
  if (v == v.roundToDouble()) {
    return '${v >= 0 ? '+' : ''}${v.round()}$suffix';
  }
  final sign = v >= 0 ? '+' : '-';
  return '$sign${v.abs().toStringAsFixed(1)}$suffix';
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: emphasize ? AppColors.accent : AppColors.inkMuted,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.ink),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: emphasize ? AppColors.accent : AppColors.ink,
            fontSize: AppSpacing.statFontSize,
          ),
        ),
      ],
    );
  }
}
