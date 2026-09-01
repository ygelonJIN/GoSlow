import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design/design.dart';
import '../../app/theme/fold_decoration.dart';
import '../../app/theme/mode_theme.dart';
import '../../data/dict/dict_database.dart';
import '../../data/dict/dict_providers.dart';
import '../../data/dict/syllabus.dart';
import '../../data/models/review_outcome.dart';
import '../../data/models/srs_card_state.dart';
import '../../data/models/word_entry.dart';
import '../../data/models/word_state.dart';
import '../../data/providers/app_providers.dart';
import '../../data/services/tts_service.dart';
import '../../features/celebration/celebration_page.dart';
import '../../features/favorite/favorite_page.dart';
import '../../shared/empty_state.dart';
import '../../shared/exam_tag_picker.dart';
import '../../shared/feedback_dialog.dart';
import '../../shared/meaning_card.dart';
import '../../shared/overlay_page.dart';
import '../../shared/pill_button.dart';
import '../../shared/segmented_pills.dart';
import '../../shared/word_history_stats.dart';

/// 识别式闪卡（M3）：开始页（来源 / 模式 / 张数）→ 全屏学习态。
///
/// - 开始页：顶部「收藏 + 开始学习」通栏；来源（内容词 / 考纲词）、
///   本轮内容（复习+新词 / 只到期）、每轮张数全部用主题化 SegmentedPills。
/// - 学习态：整张闪卡铺满全屏，进度置顶 + 上下渐隐，底部三档自评悬浮。
///   认识直接下一张，模糊 / 不认识翻面看释义（进入待复习池）。
class FlashcardPage extends ConsumerStatefulWidget {
  const FlashcardPage({super.key});

  @override
  ConsumerState<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends ConsumerState<FlashcardPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final source = ref.watch(flashcardSourceProvider);
    final bottomBarSpace = AppOverlay.bottomInset(context) + 96 + AppSpacing.xl;
    return Stack(
      children: [
        Positioned.fill(
          child: ListView(
            padding: EdgeInsets.only(
              top: AppOverlay.topInset(context),
              bottom: bottomBarSpace,
            ),
            children: [
              Padding(
                padding: AppInsets.pageHorizontal
                    .copyWith(bottom: AppSpacing.md),
                child: _FavoriteBar(onTap: _openFavorite),
              ),
              Padding(
                padding: AppInsets.pageHorizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '闪卡来源',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: AppColors.inkMuted),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SegmentedPills<FlashcardSource>(
                      items: const [
                        SegmentedPillItem(
                          value: FlashcardSource.content,
                          label: '内容词',
                          icon: Icons.article_outlined,
                        ),
                        SegmentedPillItem(
                          value: FlashcardSource.syllabus,
                          label: '考纲词',
                          icon: Icons.menu_book_outlined,
                        ),
                      ],
                      selected: source,
                      onChanged: (s) {
                        ref.read(flashcardSourceProvider.notifier).state = s;
                      },
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '导入内容里出现的考纲词',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.inkMuted,
                                  fontSize: 10,
                                ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '当前考纲全部词汇',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.inkMuted,
                                  fontSize: 10,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ExamTagRow(
                      currentTag: ref.watch(examTagProvider),
                      onTap: _pickExamTag,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (source == FlashcardSource.content)
                ..._buildContentIntro(context)
              else
                ..._buildSyllabusIntro(context),
            ],
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
          height: AppOverlay.bottomFadeHeight,
          child: IgnorePointer(
            child: DecoratedBox(decoration: AppOverlay.bottomFade()),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: AppOverlay.bottomInset(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _PrimaryStartButton(
                    busy: _busy,
                    icon: Icons.auto_awesome_outlined,
                    label: '学习',
                    onTap: () => _startWith(FlashcardMode.learn),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _PrimaryStartButton(
                    busy: _busy,
                    icon: Icons.replay_outlined,
                    label: '复习',
                    onTap: () => _startWith(FlashcardMode.review),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _startWith(FlashcardMode mode) async {
    ref.read(flashcardModeProvider.notifier).state = mode;
    await _start();
  }

  void _openFavorite() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const OverlayPage(
          title: '收藏',
          kicker: 'FAVORITE',
          child: FavoritePage(),
        ),
      ),
    );
  }

  Future<void> _pickExamTag() async {
    final current = ref.read(examTagProvider);
    final picked = await showExamTagPicker(context, current);
    if (picked != null) {
      ref.read(examTagProvider.notifier).state = picked;
    }
  }

  // ---------------------------------------------------------------------
  // 内容词入口（自动收集：导入内容中出现过的考纲词）
  // ---------------------------------------------------------------------

  List<Widget> _buildContentIntro(BuildContext context) {
    final stats = ref.watch(contentWordsStatsProvider);
    final settings = ref.watch(flashcardSettingsProvider);
    final knownCount = ref.watch(knownWordsProvider).length;

    if (stats.total == 0) {
      return [
        EmptyState(
          icon: Icons.style_outlined,
          title: knownCount > 0 ? '已认识 $knownCount 词' : '识别式闪卡',
          subtitle: '导入 / 粘贴英文内容后，里面出现的考纲词会自动出现在这里',
        ),
      ];
    }

    return [
      Card(
        child: Padding(
          padding: AppInsets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IntroStat(label: '总词数', value: '${stats.total}'),
                  Container(
                    width: 1,
                    height: 28,
                    color: AppColors.line,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  ),
                  _IntroStat(label: '已认识', value: '${stats.known}'),
                  Container(
                    width: 1,
                    height: 28,
                    color: AppColors.line,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  ),
                  _IntroStat(label: '待复习', value: '${stats.review}'),
                  Container(
                    width: 1,
                    height: 28,
                    color: AppColors.line,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  ),
                  _IntroStat(label: '新词', value: '${stats.fresh}'),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              _buildSessionSettings(context, settings, divider: false),
            ],
          ),
        ),
      ),
    ];
  }

  // ---------------------------------------------------------------------
  // 考纲词入口（当前考纲全部词汇）
  // ---------------------------------------------------------------------

  List<Widget> _buildSyllabusIntro(BuildContext context) {
    final stats = ref.watch(syllabusStatsProvider);
    final settings = ref.watch(flashcardSettingsProvider);
    final order = ref.watch(syllabusOrderProvider);

    return [
      Card(
        child: Padding(
          padding: AppInsets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IntroStat(label: '总词数', value: '${stats.total}'),
                  Container(
                    width: 1,
                    height: 28,
                    color: AppColors.line,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  ),
                  _IntroStat(label: '已认识', value: '${stats.known}'),
                  Container(
                    width: 1,
                    height: 28,
                    color: AppColors.line,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  ),
                  _IntroStat(label: '待复习', value: '${stats.review}'),
                  Container(
                    width: 1,
                    height: 28,
                    color: AppColors.line,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                  ),
                  _IntroStat(label: '新词', value: '${stats.fresh}'),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              Text(
                '新词顺序',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedPills<SyllabusOrder>(
                items: const [
                  SegmentedPillItem(
                    value: SyllabusOrder.frq,
                    label: '词频',
                    icon: Icons.trending_up,
                  ),
                  SegmentedPillItem(
                    value: SyllabusOrder.alpha,
                    label: '字母',
                    icon: Icons.sort_by_alpha,
                  ),
                  SegmentedPillItem(
                    value: SyllabusOrder.random,
                    label: '随机',
                    icon: Icons.shuffle,
                  ),
                ],
                selected: order,
                onChanged: (s) {
                  ref.read(syllabusOrderProvider.notifier).state = s;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              _buildSessionSettings(context, settings, divider: false),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildSessionSettings(
    BuildContext context,
    FlashcardSettings settings, {
    bool divider = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (divider) ...[
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          '每轮张数',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedPills<int>(
          items: const [
            SegmentedPillItem(value: 10, label: '10'),
            SegmentedPillItem(value: 20, label: '20'),
            SegmentedPillItem(value: 30, label: '30'),
          ],
          selected: settings.sessionSize,
          onChanged: (s) {
            ref.read(flashcardSettingsProvider.notifier).state = settings
                .copyWith(sessionSize: s);
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '自动朗读',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '翻开新卡时自动读单词',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(
              value: settings.autoSpeak,
              onChanged: (v) {
                ref.read(flashcardSettingsProvider.notifier).state = settings
                    .copyWith(autoSpeak: v);
              },
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 动作：组词 → 推入全屏学习页
  // ---------------------------------------------------------------------

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final deck = await buildFlashcardDeck(ref);
      if (deck.isEmpty) {
        final reviewOnly =
            ref.read(flashcardModeProvider) == FlashcardMode.review;
        if (mounted) {
          FeedbackDialog.show(
            context,
            message: reviewOnly ? '当前没有到期复习的卡' : '当前没有可学的新词',
          );
        }
        return;
      }
      final snapshot = readKnownSnapshot(ref);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FlashcardSessionPage(
            deck: deck,
            knownSnapshot: snapshot,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// 按当前来源 / 模式 / 设置组一轮牌堆（开始页与「再来一轮」共用）。
///
/// - 学习：只学新词（不复习旧卡）。
/// - 复习：只复习已到期旧卡（不学新词）。
Future<List<String>> buildFlashcardDeck(WidgetRef ref) async {
  final settings = ref.read(flashcardSettingsProvider);
  final source = ref.read(flashcardSourceProvider);
  final mode = ref.read(flashcardModeProvider);
  final repo = ref.read(wordStateRepoProvider);
  return switch (source) {
    FlashcardSource.content =>
      mode == FlashcardMode.review
          ? await repo.flashcardDeck(
              sessionSize: settings.sessionSize,
              reviewOnly: true,
            )
          : await repo.flashcardDeck(
              sessionSize: settings.sessionSize,
              candidateNew: await ref.read(contentWordsProvider.future),
              newOnly: true,
            ),
    FlashcardSource.syllabus =>
      mode == FlashcardMode.review
          ? await repo.flashcardDeck(
              sessionSize: settings.sessionSize,
              reviewOnly: true,
            )
          : await repo.flashcardDeck(
              sessionSize: settings.sessionSize,
              candidateNew: [
                for (final w in ref.read(syllabusWordsProvider)) w.word.toLowerCase(),
              ],
              newOnly: true,
            ),
  };
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

// ---------------------------------------------------------------------------
// 全屏学习页：整张闪卡 = 全屏背景 + 顶部进度置顶 + 底部三档自评悬浮
// ---------------------------------------------------------------------------

class FlashcardSessionPage extends ConsumerStatefulWidget {
  const FlashcardSessionPage({
    super.key,
    required this.deck,
    required this.knownSnapshot,
  });

  final List<String> deck;
  final Set<String> knownSnapshot;

  @override
  ConsumerState<FlashcardSessionPage> createState() =>
      _FlashcardSessionPageState();
}

enum _Phase { running, summary }

class _FlashcardSessionPageState extends ConsumerState<FlashcardSessionPage> {
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
        // 1. 整张闪卡 = 全屏背景（正 / 反面动画切换）。
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
        // 2. 顶部渐隐：进度浮层之下的内容过渡淡出。
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: AppOverlay.topFadeHeight,
          child: IgnorePointer(
            child: DecoratedBox(decoration: AppOverlay.topFade()),
          ),
        ),
        // 3. 底部渐隐：内容滚入自评按钮下方时自然淡出。
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: AppOverlay.bottomFadeHeight,
          child: IgnorePointer(
            child: DecoratedBox(decoration: AppOverlay.bottomFade()),
          ),
        ),
        // 4. 顶部浮层：退出胶囊 + 进度计数 / 状态 + 进度条。
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
        // 5. 底部悬浮：正面 = 三档自评；背面 = 「下一张」。
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
              child: _flipped
                  ? _buildNextButton(context)
                  : _buildRating(context),
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
    // 整张闪卡 = 全屏纸色背景（无额外色块；渐隐只由上方遮罩负责）。
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
                _SpeakPill(onTap: () => TtsService.instance.speak(_word)),
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
    // 与正面一致：全屏纸色背景，释义滚动区由上下渐隐遮罩负责淡出。
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
          child: _RateButton(
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
          child: _RateButton(
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
          child: _RateButton(
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

    // 结算页同样走「全屏内容 + 上下渐隐 + 底部浮层」骨架（与学习态 / OverlayPage
    // 完全一致的层级）：内容铺满全屏，上下渐隐遮罩盖在内容之上，按钮悬浮在渐隐之上。
    return Stack(
      children: [
        // 1. 全屏纸色背景。
        const Positioned.fill(child: ColoredBox(color: AppColors.paper)),
        // 2. 内容滚动区：铺满全屏（避让用 inset，不用 SafeArea 包裹），
        //    内容滚入上下渐隐下方时柔和淡出。
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
        // 3. 顶部渐隐：盖在内容之上（内容滚入顶部时柔和淡出）。
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: AppOverlay.topFadeHeight,
          child: IgnorePointer(
            child: DecoratedBox(decoration: AppOverlay.topFade()),
          ),
        ),
        // 4. 底部渐隐：盖在内容之上（内容滚入底部时柔和淡出）。
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: AppOverlay.bottomFadeHeight,
          child: IgnorePointer(
            child: DecoratedBox(decoration: AppOverlay.bottomFade()),
          ),
        ),
        // 5. 底部悬浮：再来一轮 + 返回（压在底部渐隐之上，无底层背景）。
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
                        backgroundColor: ModeThemes.love.chipBackground,
                        foregroundColor: ModeThemes.love.chipForeground,
                        side: BorderSide(
                          color: ModeThemes.love.chipBorder.withValues(
                            alpha: 0.55,
                          ),
                        ),
                        shape: FoldShape(
                          borderRadius: ModeThemes.love.chipRadius,
                          fold: ModeThemes.love.cornerFold,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: 14,
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
      final deck = await buildFlashcardDeck(ref);
      final snapshot = readKnownSnapshot(ref);
      if (deck.isEmpty) {
        final reviewOnly =
            ref.read(flashcardModeProvider) == FlashcardMode.review;
        if (mounted) {
          FeedbackDialog.show(
            context,
            message: reviewOnly ? '当前没有到期复习的卡' : '当前没有可学的新词',
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
      // 结算页先渲染，随后若跨过里程碑则整页庆祝。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeCelebrate();
      });
      return;
    }
    setState(() {
      _flipped = false;
      _index = nextIndex;
    });
    _maybeSpeak(_deck[nextIndex], settings);
  }

  /// 模糊 / 不认识翻面后，若开启自动朗读则读一遍释义。
  void _maybeSpeakReview() {
    final settings = ref.read(flashcardSettingsProvider);
    if (settings.autoSpeak) {
      TtsService.instance.speak(_word);
    }
  }

  /// 检测并庆祝新达成的认识词数里程碑（达标且未庆祝过的）。
  Future<void> _maybeCelebrate() async {
    if (!mounted) return;
    final wordRepo = ref.read(wordStateRepoProvider);
    final states = await wordRepo.loadAll();
    final knownCount = states.values
        .where((s) => s.status == WordStatus.known)
        .length;
    if (!mounted) return;

    final milestoneRepo = ref.read(milestoneRepoProvider);
    final pending = await milestoneRepo.pendingKnownWordMilestones(knownCount);
    if (pending.isEmpty || !mounted) return;

    for (final t in pending) {
      await milestoneRepo.markAchieved(threshold: t);
    }
    ref.read(wordStateVersionProvider.notifier).state++;
    if (!mounted) return;

    // 一次庆祝最高档（pending 升序，取最后一档）。
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CelebrationPage(threshold: pending.last),
      ),
    );
  }

  void _maybeSpeak(String word, FlashcardSettings settings) {
    if (settings.autoSpeak) {
      TtsService.instance.speak(word);
    }
  }
}

// ---------------------------------------------------------------------------
// 小组件
// ---------------------------------------------------------------------------

/// 闪卡页顶部「收藏」通栏：整屏宽度，内置收藏数量。
class _FavoriteBar extends ConsumerWidget {
  const _FavoriteBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(favoriteWordSetProvider).length;
    const theme = ModeThemes.love;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      shape: FoldShape(
        borderRadius: theme.chipRadius,
        fold: theme.cornerFold,
        side: BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: 13,
          ),
          child: Row(
            children: [
              Icon(Icons.star_outline, size: 18, color: scheme.onPrimary),
              const SizedBox(width: AppSpacing.pillGap),
              Text(
                '收藏',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: scheme.onPrimary.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 当前考纲选择行（考纲词按钮下方）：显示当前考纲，点击弹出选择面板。
class _ExamTagRow extends ConsumerWidget {
  const _ExamTagRow({required this.currentTag, required this.onTap});

  final String currentTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const theme = ModeThemes.love;
    final scheme = Theme.of(context).colorScheme;
    final label = currentTag == kAllTag
        ? '全部考纲'
        : (kExamTagNames[currentTag] ?? currentTag);
    return Material(
      color: theme.chipBackground,
      shape: FoldShape(
        borderRadius: theme.chipRadius,
        side: BorderSide(
          color: theme.chipBorder.withValues(alpha: 0.55),
          width: 1,
        ),
        fold: theme.cornerFold,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.filter_alt_outlined,
                size: 15,
                color: theme.chipForeground,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '当前考纲',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: AppColors.inkMuted),
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 顶部「学习 / 复习」主按钮：实底 primary 选中态，无描边、无阴影，
/// 与 SegmentedPills 选中态完全一致，占满剩余宽度。
class _PrimaryStartButton extends StatelessWidget {
  const _PrimaryStartButton({
    required this.busy,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool busy;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const theme = ModeThemes.love;
    final scheme = Theme.of(context).colorScheme;
    final disabled = busy;
    return Material(
      color: disabled
          ? scheme.primary.withValues(alpha: 0.38)
          : scheme.primary,
      shape: FoldShape(
        borderRadius: theme.chipRadius,
        fold: theme.cornerFold,
        side: BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: disabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pillHorizontal,
            vertical: AppSpacing.pillVertical,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: scheme.onPrimary,
              ),
              const SizedBox(width: AppSpacing.pillGap),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppSpacing.pillFontSize,
                  fontWeight: FontWeight.w600,
                  color: scheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroStat extends StatelessWidget {
  const _IntroStat({required this.label, required this.value});

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
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeakPill extends StatelessWidget {
  const _SpeakPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.seedSoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.volume_up_outlined,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '朗读',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
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
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: fg),
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

/// 评级占比行（结算页 / 统计页共用样式）。
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

/// 高阶数据行：指标 + 说明。
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
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: AppColors.ink),
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

/// 会话分组小统计（新学 / 复习 / 重学）。
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
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: emphasize ? AppColors.accent : AppColors.ink),
        ),
      ],
    );
  }
}