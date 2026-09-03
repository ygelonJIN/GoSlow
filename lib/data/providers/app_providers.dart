import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../dict/dict_database.dart';
import '../dict/dict_providers.dart';
import '../models/content_entry.dart';
import '../models/review_stats.dart';
import '../models/word_entry.dart';
import '../models/word_review_stats.dart';
import '../models/word_state.dart';
import '../repositories/content_repository.dart';
import '../repositories/stats_repository.dart';
import '../repositories/word_state_repository.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);

final contentRepoProvider = Provider<ContentRepository>((ref) {
  return ContentRepository(ref.watch(appDatabaseProvider));
});

final wordStateRepoProvider = Provider<WordStateRepository>((ref) {
  return WordStateRepository(ref.watch(appDatabaseProvider));
});

final statsRepoProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(ref.watch(appDatabaseProvider));
});

/// 自增版本号，任意写操作后递增以刷新依赖它的 FutureProvider。
final wordStateVersionProvider = StateProvider<int>((ref) => 0);
final contentVersionProvider = StateProvider<int>((ref) => 0);

final contentsProvider = FutureProvider<List<ContentEntry>>((ref) async {
  ref.watch(contentVersionProvider);
  final repo = ref.watch(contentRepoProvider);
  return repo.listAll();
});

final wordStatesProvider = FutureProvider<Map<String, WordState>>((ref) async {
  ref.watch(wordStateVersionProvider);
  final repo = ref.watch(wordStateRepoProvider);
  return repo.loadAll();
});

/// 统计总览（M4：从 review_events 事件表聚合）。
final reviewStatsProvider = FutureProvider<ReviewStats>((ref) async {
  ref.watch(wordStateVersionProvider);
  final repo = ref.watch(statsRepoProvider);
  return repo.compute();
});

final knownWordsProvider = Provider<Set<String>>((ref) {
  final async = ref.watch(wordStatesProvider);
  return async.when(
    data: (m) => {for (final e in m.entries) if (e.value.status == WordStatus.known) e.key},
    loading: () => const {},
    error: (_, _) => const {},
  );
});

final favoriteWordSetProvider = Provider<Set<String>>((ref) {
  final async = ref.watch(wordStatesProvider);
  return async.when(
    data: (m) => {for (final e in m.entries) if (e.value.favorite) e.key},
    loading: () => const {},
    error: (_, _) => const {},
  );
});

/// 待复习池（familiar / learning 且见过）。
final reviewQueueProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(wordStateVersionProvider);
  final repo = ref.watch(wordStateRepoProvider);
  return repo.reviewQueue();
});

/// 复习每轮张数的候选项（数据层统一，UI 禁止重复硬编码）。
const List<int> kReviewSessionSizes = [10, 20, 30, 50, 80, 100];

/// 复习每轮张数的展示文案。
String formatSessionSize(int size) => '$size 张';

/// 复习/阅读会话设置：每轮张数 / 自动朗读。
class FlashcardSettings {
  const FlashcardSettings({this.sessionSize = 10, this.autoSpeak = true});

  final int sessionSize;
  final bool autoSpeak;

  FlashcardSettings copyWith({int? sessionSize, bool? autoSpeak}) {
    return FlashcardSettings(
      sessionSize: sessionSize ?? this.sessionSize,
      autoSpeak: autoSpeak ?? this.autoSpeak,
    );
  }
}

final flashcardSettingsProvider = StateProvider<FlashcardSettings>((ref) {
  return const FlashcardSettings();
});

/// 考纲 → 自定义高亮颜色的覆盖表（未配置的考纲回落到 [HighlightPalette]）。
final highlightTagColorsProvider =
    StateProvider<Map<String, Color>>((ref) => const {});

/// 单个考纲的词数统计（总词数 / 已认识数，供考纲选择页展示）。
class ExamTagCounts {
  const ExamTagCounts({required this.total, required this.known});

  final int total;
  final int known;
}

/// 各考纲总词数与已认识词数：词库内存索引按考纲标签聚合（词 + 词组），
/// 已认识数取 word_states 中 status == known 的词。
final examTagCountsProvider =
    FutureProvider<Map<String, ExamTagCounts>>((ref) async {
  ref.watch(wordStateVersionProvider);
  final index = await ref.watch(memoryIndexProvider.future);
  final states = await ref.read(wordStatesProvider.future);

  final out = <String, ExamTagCounts>{};
  for (final tag in kExamTags) {
    var total = 0;
    var known = 0;
    for (final e in index.words.values) {
      if (!e.tags.contains(tag)) continue;
      total++;
      if (states[e.word.toLowerCase()]?.status == WordStatus.known) known++;
    }
    for (final e in index.phrases.values) {
      if (!e.tags.contains(tag)) continue;
      total++;
      if (states[e.word.toLowerCase()]?.status == WordStatus.known) known++;
    }
    out[tag] = ExamTagCounts(total: total, known: known);
  }
  return out;
});

/// 复习翻面时查词用（family 按 word 缓存）。
final flashcardEntryProvider = FutureProvider.family<LookupResult?, String>(
    (ref, word) {
  return ref.watch(lookupProvider).lookup(word);
});

/// 单个单词的自评历史统计（复习页 / 点词面板复用）。
final wordReviewStatsProvider = FutureProvider.family<WordReviewStats, String>((ref, word) async {
  ref.watch(wordStateVersionProvider);
  final repo = ref.watch(wordStateRepoProvider);
  return repo.reviewStatsOf(word);
});

/// 内容词：按当前考纲选择，导入的所有内容中出现过的考纲词（去重，按出现顺序稳定）。
///
/// 选中「全部」时不按考纲过滤；选中若干考纲时只收词条命中任一选中考纲的词。
final contentWordsProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(contentVersionProvider);
  final tags = ref.watch(examTagProvider);
  final engine = await ref.watch(highlightEngineProvider.future);
  final contents = await ref.watch(contentsProvider.future);

  final words = <String>{};
  for (final c in contents) {
    final spans = engine.highlight(
      c.body,
      examTags: tags.contains(kAllTag) ? null : tags,
    );
    for (final s in spans) {
      words.add(s.entry.word.toLowerCase());
    }
  }
  return words.toList();
});

/// 内容词入口统计（总词数 / 已认识 / 待复习 / 新词数）。
final contentWordsStatsProvider = Provider<ContentWordsStats>((ref) {
  final wordsAsync = ref.watch(contentWordsProvider);
  final statesAsync = ref.watch(wordStatesProvider);
  final words = wordsAsync.maybeWhen(data: (l) => l, orElse: () => const <String>[]);
  final states = statesAsync.maybeWhen(
    data: (m) => m,
    orElse: () => const <String, WordState>{},
  );

  var known = 0;
  var review = 0;
  for (final w in words) {
    final s = states[w];
    if (s == null) continue;
    if (s.status == WordStatus.known) {
      known++;
    } else if (s.status == WordStatus.familiar || s.status == WordStatus.learning) {
      review++;
    }
  }
  return ContentWordsStats(total: words.length, known: known, review: review);
});

class ContentWordsStats {
  const ContentWordsStats({required this.total, required this.known, required this.review});

  final int total;
  final int known;
  final int review;

  int get fresh => total - known - review;
}

/// 单篇内容的高亮词总结（内容总结页 / 庆祝页用）。
///
/// 统计口径与阅读器一致：单选考纲 → 只看该考纲；「全部」/多选 → 全范围高亮，
/// [unfamiliar] 为尚未认识的词（待复习 + 从未处理），chip 展示用。
class ContentWordSummary {
  const ContentWordSummary({
    required this.total,
    required this.known,
    required this.review,
    this.unfamiliar = const [],
  });

  final int total;
  final int known;
  final int review;

  /// 还需消化的词（超过 [ContentWordSummary.chipLimit] 截断）。
  final List<String> unfamiliar;

  int get fresh => total - known - review;

  int get unfamiliarCount => total - known;

  /// chip 列表上限，避免长文总结刷屏。
  static const int chipLimit = 40;
}

/// 单篇内容的高亮词统计（family 按内容 id）。
final contentWordSummaryProvider =
    FutureProvider.family<ContentWordSummary, int>((ref, id) async {
  ref.watch(wordStateVersionProvider);
  ref.watch(examTagProvider);
  ref.watch(highlightModeProvider);
  final engine = await ref.watch(highlightEngineProvider.future);
  final contents = await ref.watch(contentsProvider.future);
  final content = contents.where((c) => c.id == id).firstOrNull;
  if (content == null) {
    return const ContentWordSummary(total: 0, known: 0, review: 0);
  }

  final tags = ref.watch(examTagProvider);
  final highlightMode = ref.watch(highlightModeProvider);
  final spans = engine.highlight(
    content.body,
    examTags: highlightMode == HighlightMode.single ? tags : null,
  );

  final stats = await ref.read(wordStatesProvider.future);
  final seen = <String>{};
  var known = 0;
  var review = 0;
  final unfamiliar = <String>[];
  for (final s in spans) {
    final w = s.entry.word.toLowerCase();
    if (!seen.add(w)) continue;
    final st = stats[w];
    if (st?.status == WordStatus.known) {
      known++;
    } else if (st?.status == WordStatus.familiar ||
        st?.status == WordStatus.learning) {
      review++;
      if (unfamiliar.length < ContentWordSummary.chipLimit) unfamiliar.add(w);
    } else {
      if (unfamiliar.length < ContentWordSummary.chipLimit) unfamiliar.add(w);
    }
  }
  return ContentWordSummary(
    total: seen.length,
    known: known,
    review: review,
    unfamiliar: unfamiliar,
  );
});
