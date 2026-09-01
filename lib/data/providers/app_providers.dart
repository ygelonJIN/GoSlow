import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../dict/dict_database.dart';
import '../dict/dict_providers.dart';
import '../dict/syllabus.dart';
import '../models/milestone.dart';
import '../models/review_stats.dart';
import '../models/word_entry.dart';
import '../models/word_review_stats.dart';
import '../models/word_state.dart';
import '../repositories/content_repository.dart';
import '../repositories/milestone_repository.dart';
import '../repositories/stats_repository.dart';
import '../repositories/word_state_repository.dart';
import '../models/content_entry.dart';

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

final milestoneRepoProvider = Provider<MilestoneRepository>((ref) {
  return MilestoneRepository(ref.watch(appDatabaseProvider));
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

/// 已庆祝的里程碑（M4 庆祝页）。
final achievedMilestonesProvider = FutureProvider<List<Milestone>>((ref) async {
  ref.watch(wordStateVersionProvider);
  final repo = ref.watch(milestoneRepoProvider);
  return repo.achieved();
});

/// 新达成、尚未庆祝的认识词数里程碑（达成时触发庆祝页）。
final pendingMilestonesProvider = FutureProvider<List<int>>((ref) async {
  ref.watch(wordStateVersionProvider);
  final repo = ref.watch(milestoneRepoProvider);
  final known = ref.watch(knownWordsProvider).length;
  return repo.pendingKnownWordMilestones(known);
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

/// 闪卡设置：每轮张数 / 自动朗读。
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

/// 闪卡翻面时查词用（family 按 word 缓存）。
final flashcardEntryProvider = FutureProvider.family<LookupResult?, String>((ref, word) {
  return ref.watch(lookupProvider).lookup(word);
});

/// 单个单词的自评历史统计（闪卡学习页 / 点词面板复用）。
final wordReviewStatsProvider = FutureProvider.family<WordReviewStats, String>((ref, word) async {
  ref.watch(wordStateVersionProvider);
  final repo = ref.watch(wordStateRepoProvider);
  return repo.reviewStatsOf(word);
});

/// 闪卡入口：内容词（队列） / 考纲词（当前考纲）。
enum FlashcardSource { content, syllabus }

final flashcardSourceProvider = StateProvider<FlashcardSource>((ref) {
  return FlashcardSource.content;
});

/// 考纲词新词排序：词频 / 字母序 / 随机。
final syllabusOrderProvider = StateProvider<SyllabusOrder>((ref) {
  return SyllabusOrder.frq;
});

/// 当前考纲的全部候选词（已按 [syllabusOrderProvider] 排序）。
final syllabusWordsProvider = Provider<List<WordEntry>>((ref) {
  final indexAsync = ref.watch(memoryIndexProvider);
  final order = ref.watch(syllabusOrderProvider);
  final examTag = ref.watch(examTagProvider);
  return indexAsync.maybeWhen(
    data: (index) => sortSyllabus(syllabusWordsFor(index, examTag), order),
    orElse: () => const [],
  );
});

/// 考纲词入口的统计（总词数 / 已认识 / 待复习 / 新词数）。
final syllabusStatsProvider = Provider<SyllabusStats>((ref) {
  final words = ref.watch(syllabusWordsProvider);
  final statesAsync = ref.watch(wordStatesProvider);
  final states = statesAsync.maybeWhen(
    data: (m) => m,
    orElse: () => const <String, WordState>{},
  );

  var known = 0;
  var review = 0;
  for (final w in words) {
    final s = states[w.word.toLowerCase()];
    if (s == null) continue;
    if (s.status == WordStatus.known) {
      known++;
    } else if (s.status == WordStatus.familiar || s.status == WordStatus.learning) {
      review++;
    }
  }
  return SyllabusStats(
    total: words.length,
    known: known,
    review: review,
  );
});

class SyllabusStats {
  const SyllabusStats({required this.total, required this.known, required this.review});

  final int total;
  final int known;
  final int review;

  /// 从未处理过（连 word_states 都没有）的新词数。
  int get fresh => total - known - review;
}

/// 内容词：导入的所有内容中出现过的考纲词（去重，按出现顺序稳定）。
///
/// 不需要手动"加入学习"——只要内容里出现过、属于当前考纲，就会自动
/// 出现在闪卡「内容词」入口（见 docs/开发文档.md §3.4 卡片来源 2）。
final contentWordsProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(contentVersionProvider);
  ref.watch(examTagProvider);
  final engine = await ref.watch(highlightEngineProvider.future);
  final contents = await ref.watch(contentsProvider.future);

  final words = <String>{};
  for (final c in contents) {
    final spans = engine.highlight(c.body);
    for (final s in spans) {
      words.add(s.entry.word.toLowerCase());
    }
  }
  return words.toList();
});

/// 内容词入口统计（总词数 / 已认识 / 待复习 / 新词数）。
final contentWordsStatsProvider = Provider<SyllabusStats>((ref) {
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
  return SyllabusStats(total: words.length, known: known, review: review);
});

/// 闪卡模式：学习（只学新词）/ 复习（只复习到期旧卡）。
enum FlashcardMode { learn, review }

final flashcardModeProvider = StateProvider<FlashcardMode>((ref) {
  return FlashcardMode.learn;
});
