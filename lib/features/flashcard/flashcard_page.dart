import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design/design.dart';
import '../../data/dict/dict_database.dart';
import '../../data/dict/syllabus.dart';
import '../../data/models/review_outcome.dart';
import '../../data/models/srs_card_state.dart';
import '../../data/models/word_state.dart';
import '../../data/providers/app_providers.dart';
import '../../data/services/tts_service.dart';
import '../../features/celebration/celebration_page.dart';
import '../../shared/empty_state.dart';
import '../../shared/meaning_card.dart';

/// 识别式闪卡（M3）：正面单词 + 音标 → 自评三档 → 认识直接下一张，
/// 模糊/不认识翻面看释义（进入待复习池）。session 结束进结算页。
class FlashcardPage extends ConsumerStatefulWidget {
  const FlashcardPage({super.key});

  @override
  ConsumerState<FlashcardPage> createState() => _FlashcardPageState();
}

enum _Phase { intro, running, summary }

class _FlashcardPageState extends ConsumerState<FlashcardPage> {
  _Phase _phase = _Phase.intro;
  List<String> _deck = const [];
  int _index = 0;
  bool _flipped = false;
  final List<SessionEntry> _entries = [];
  int _newKnown = 0;
  bool _busy = false;
  Set<String> _knownSnapshot = const {};

  String get _word => _index < _deck.length ? _deck[_index] : '';

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _Phase.intro => _buildIntro(context),
      _Phase.running => _buildRunning(context),
      _Phase.summary => _buildSummary(context),
    };
  }

  // ---------------------------------------------------------------------
  // 开始页
  // ---------------------------------------------------------------------

  Widget _buildIntro(BuildContext context) {
    final source = ref.watch(flashcardSourceProvider);
    return ListView(
      padding: EdgeInsets.only(
        top: AppOverlay.topInset(context),
        bottom: AppOverlay.bottomInset(context),
      ),
      children: [
        Padding(
          padding: AppInsets.pageHorizontal.copyWith(bottom: AppSpacing.md),
          child: SegmentedButton<FlashcardSource>(
            segments: const [
              ButtonSegment(
                value: FlashcardSource.content,
                label: Text('内容词'),
                icon: Icon(Icons.article_outlined, size: 16),
              ),
              ButtonSegment(
                value: FlashcardSource.syllabus,
                label: Text('考纲词'),
                icon: Icon(Icons.menu_book_outlined, size: 16),
              ),
            ],
            selected: {source},
            onSelectionChanged: (s) {
              ref.read(flashcardSourceProvider.notifier).state = s.first;
            },
          ),
        ),
        if (source == FlashcardSource.content)
          ..._buildContentIntro(context)
        else
          ..._buildSyllabusIntro(context),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 内容词入口（自动收集：导入内容中出现过的考纲词）
  // ---------------------------------------------------------------------

  List<Widget> _buildContentIntro(BuildContext context) {
    final stats = ref.watch(contentWordsStatsProvider);
    final settings = ref.watch(flashcardSettingsProvider);
    final mode = ref.watch(flashcardModeProvider);
    final knownCount = ref.watch(knownWordsProvider).length;

    if (stats.total == 0) {
      return [
        EmptyState(
          icon: Icons.style_outlined,
          title: knownCount > 0 ? '已认识 $knownCount 词' : '识别式闪卡',
          subtitle: '导入 / 粘贴英文内容后，里面出现的考纲词会自动出现在这里；或切到「考纲词」直接学当前考纲',
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
              Text(
                '看到即秒认',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '你导入的内容里出现的考纲词会自动收进来，不用手动加。正面只有单词和音标，认识 ✅ 直接下一张；模糊 😐 / 不认识 ❌ 翻面看释义。',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.inkMuted, height: 1.6),
              ),
            ],
          ),
        ),
      ),
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
              _buildModeSelector(context),
              const Divider(),
              _buildSessionSettings(context, settings, divider: false),
            ],
          ),
        ),
      ),
      _buildStartButton(context, mode),
    ];
  }

  // ---------------------------------------------------------------------
  // 考纲词入口（当前考纲全部词汇）
  // ---------------------------------------------------------------------

  List<Widget> _buildSyllabusIntro(BuildContext context) {
    final stats = ref.watch(syllabusStatsProvider);
    final settings = ref.watch(flashcardSettingsProvider);
    final order = ref.watch(syllabusOrderProvider);
    final mode = ref.watch(flashcardModeProvider);

    return [
      Card(
        child: Padding(
          padding: AppInsets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前考纲直学',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '直接学当前考纲的全部词汇，已认识的自动跳过。同样先复习旧卡，再按所选顺序学新词。',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.inkMuted, height: 1.6),
              ),
            ],
          ),
        ),
      ),
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
              _buildModeSelector(context),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              Text(
                '新词顺序',
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<SyllabusOrder>(
                segments: const [
                  ButtonSegment(
                    value: SyllabusOrder.frq,
                    label: Text('词频'),
                    icon: Icon(Icons.trending_up, size: 14),
                  ),
                  ButtonSegment(
                    value: SyllabusOrder.alpha,
                    label: Text('字母'),
                    icon: Icon(Icons.sort_by_alpha, size: 14),
                  ),
                  ButtonSegment(
                    value: SyllabusOrder.random,
                    label: Text('随机'),
                    icon: Icon(Icons.shuffle, size: 14),
                  ),
                ],
                selected: {order},
                onSelectionChanged: (s) {
                  ref.read(syllabusOrderProvider.notifier).state = s.first;
                },
              ),
              _buildSessionSettings(context, settings, divider: false),
            ],
          ),
        ),
      ),
      _buildStartButton(context, mode),
    ];
  }

  /// 学习 / 复习 模式选择（§15.2）。
  Widget _buildModeSelector(BuildContext context) {
    final mode = ref.watch(flashcardModeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '本轮内容',
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<FlashcardMode>(
          segments: const [
            ButtonSegment(
              value: FlashcardMode.learn,
              label: Text('学习 · 复习+新词'),
              icon: Icon(Icons.auto_awesome_outlined, size: 14),
            ),
            ButtonSegment(
              value: FlashcardMode.review,
              label: Text('复习 · 只到期'),
              icon: Icon(Icons.replay_outlined, size: 14),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (s) {
            ref.read(flashcardModeProvider.notifier).state = s.first;
          },
        ),
      ],
    );
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
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 10, label: Text('10')),
            ButtonSegment(value: 20, label: Text('20')),
            ButtonSegment(value: 30, label: Text('30')),
          ],
          selected: {settings.sessionSize},
          onSelectionChanged: (s) {
            ref.read(flashcardSettingsProvider.notifier).state = settings
                .copyWith(sessionSize: s.first);
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

  Widget _buildStartButton(BuildContext context, FlashcardMode mode) {
    final isReview = mode == FlashcardMode.review;
    return Column(
      children: [
        Padding(
          padding: AppInsets.pageHorizontal.copyWith(top: AppSpacing.xl2),
          child: FilledButton.icon(
            onPressed: _busy ? null : _start,
            icon: Icon(
              isReview ? Icons.replay_rounded : Icons.play_arrow_rounded,
            ),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(isReview ? '开始复习' : '开始学习'),
            ),
          ),
        ),
        Padding(
          padding: AppInsets.pageHorizontal.copyWith(top: AppSpacing.lg),
          child: Text(
            isReview ? '只复习已到期旧卡 · 不学新词' : '先复习“模糊 / 不认识”的旧卡，再补新词',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.inkMuted),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 学习中
  // ---------------------------------------------------------------------

  Widget _buildRunning(BuildContext context) {
    final entryAsync = ref.watch(flashcardEntryProvider(_word));
    final settings = ref.watch(flashcardSettingsProvider);
    final progress = (_index + 1) / _deck.length;

    return Padding(
      padding: EdgeInsets.only(
        top: AppOverlay.topInset(context),
        bottom: AppOverlay.bottomInset(context),
      ),
      child: Column(
        children: [
          Padding(
            padding: AppInsets.pageHorizontal.copyWith(
              top: AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${_index + 1} / ${_deck.length}',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: AppColors.inkMuted),
                    ),
                    const Spacer(),
                    if (_flipped)
                      Text(
                        '待复习',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.accent,
                          letterSpacing: 0.08 * 11,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
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
          Expanded(
            child: Padding(
              padding: AppInsets.pageHorizontal.copyWith(top: AppSpacing.md),
              child: AnimatedSwitcher(
                duration: AppMotion.durationMedium,
                switchInCurve: AppMotion.curveStandard,
                switchOutCurve: AppMotion.curveStandard,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.98,
                      end: 1.0,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _flipped
                    ? _buildBack(context, entryAsync, settings)
                    : _buildFront(context, entryAsync, settings),
              ),
            ),
          ),
          Padding(
            padding: AppInsets.pageHorizontal.copyWith(
              top: AppSpacing.lg,
              bottom: AppSpacing.lg,
            ),
            child: _flipped ? const SizedBox.shrink() : _buildRating(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFront(
    BuildContext context,
    AsyncValue<LookupResult?> entryAsync,
    FlashcardSettings settings,
  ) {
    final entry = entryAsync.maybeWhen(
      data: (r) => r?.entry,
      orElse: () => null,
    );
    return Card(
      key: const ValueKey('front'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: AppInsets.card,
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
    FlashcardSettings settings,
  ) {
    return SingleChildScrollView(
      key: const ValueKey('back'),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: AppInsets.card,
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
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _busy ? null : () => _advance(settings),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Text('下一张'),
                ),
              ),
            ],
          ),
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

  // ---------------------------------------------------------------------
  // 结算页
  // ---------------------------------------------------------------------

  Widget _buildSummary(BuildContext context) {
    final knownCount = ref.watch(knownWordsProvider).length;
    final stats = computeSessionStats(_entries);
    final known = stats.ratingDistribution[SelfRating.known] ?? 0;
    final familiar = stats.ratingDistribution[SelfRating.familiar] ?? 0;
    final unknown = stats.ratingDistribution[SelfRating.unknown] ?? 0;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppOverlay.topInset(context),
          AppSpacing.xl,
          AppOverlay.bottomInset(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              size: AppSpacing.emptyIcon,
              color: AppColors.accent,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '本回合完成',
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
                  value: _fmtSigned(stats.avgStabilityChange, suffix: ' 天'),
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
                            borderRadius: BorderRadius.circular(AppRadius.xs),
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
            const SizedBox(height: AppSpacing.xl2),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _start,
                icon: const Icon(Icons.replay_rounded),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Text('再来一轮'),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _phase = _Phase.intro;
                        _deck = const [];
                        _index = 0;
                      }),
                child: const Text('返回'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 动作
  // ---------------------------------------------------------------------

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final settings = ref.read(flashcardSettingsProvider);
      final source = ref.read(flashcardSourceProvider);
      final mode = ref.read(flashcardModeProvider);
      final repo = ref.read(wordStateRepoProvider);
      final reviewOnly = mode == FlashcardMode.review;
      final deck = switch (source) {
        FlashcardSource.content =>
          reviewOnly
              ? await repo.flashcardDeck(
                  sessionSize: settings.sessionSize,
                  reviewOnly: true,
                )
              : await ref.read(contentDeckProvider.future),
        FlashcardSource.syllabus =>
          reviewOnly
              ? await repo.flashcardDeck(
                  sessionSize: settings.sessionSize,
                  reviewOnly: true,
                )
              : await ref.read(syllabusDeckProvider.future),
      };
      if (deck.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(reviewOnly ? '当前没有到期复习的卡' : '当前入口没有可学的词：待复习与新词都是空'),
            ),
          );
        }
        return;
      }

      final states = ref
          .read(wordStatesProvider)
          .maybeWhen(data: (m) => m, orElse: () => <String, WordState>{});
      final snapshot = {
        for (final e in states.entries)
          if (e.value.status == WordStatus.known) e.key,
      };

      setState(() {
        _deck = deck;
        _index = 0;
        _flipped = false;
        _entries.clear();
        _newKnown = 0;
        _knownSnapshot = snapshot;
        _phase = _Phase.running;
      });
      _maybeSpeak(deck.first, settings);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rate(SelfRating rating) async {
    if (_flipped) return;
    setState(() => _busy = true);
    try {
      final word = _word;
      final settings = ref.read(flashcardSettingsProvider);
      final repo = ref.read(wordStateRepoProvider);
      final outcome = await repo.recordFlashcardReview(word, rating);
      final next = outcome.post;

      if (!_knownSnapshot.contains(word) && next.status == WordStatus.known) {
        _newKnown++;
      }
      _entries.add(SessionEntry(rating: rating, outcome: outcome));
      ref.read(wordStateVersionProvider.notifier).state++;

      if (rating == SelfRating.known) {
        _advance(settings);
      } else {
        setState(() => _flipped = true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _advance(FlashcardSettings settings) {
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
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.inkMuted),
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
