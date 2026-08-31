import 'package:goslow/data/db/app_database.dart';
import 'package:goslow/data/models/srs_card_state.dart';
import 'package:goslow/data/models/word_state.dart';
import 'package:goslow/data/repositories/stats_repository.dart';
import 'package:goslow/data/repositories/word_state_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late AppDatabase appDb;
  late WordStateRepository repo;
  late StatsRepository stats;

  final base = DateTime.utc(2026, 8, 31, 12).millisecondsSinceEpoch;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await AppDatabase.createSchema(db);
    appDb = AppDatabase.testInstance(() async => db);
    repo = WordStateRepository(appDb);
    stats = StatsRepository(appDb);
  });

  tearDown(() => db.close());

  group('recordFlashcardReview 事件溯源', () {
    test('每次自评写一条 review_events + 更新 word_states', () async {
      final result = await repo.recordFlashcardReview('hello', SelfRating.known, now: base);
      final state = result.post;
      expect(state.status, WordStatus.learning);
      expect(state.nextReviewAt, isNotNull);
      expect(result.pre.status, WordStatus.unknown);

      final history = await repo.reviewHistoryOf('hello');
      expect(history.length, 1);
      final e = history.first;
      expect(e.word, 'hello');
      expect(e.rating, FsrsRating.good);
      expect(e.preStatus, SrsStatus.newCard);
      expect(e.postStatus, SrsStatus.learning);

      final persisted = await repo.byWord('hello');
      expect(persisted, isNotNull);
      expect(persisted!.stability, state.stability);
    });

    test('事件按词隔离', () async {
      await repo.recordFlashcardReview('hello', SelfRating.known, now: base);
      await repo.recordFlashcardReview('world', SelfRating.unknown, now: base);
      final helloHistory = await repo.reviewHistoryOf('hello');
      expect(helloHistory.length, 1);
      expect(helloHistory.first.word, 'hello');
    });
  });

  group('undoLatestReview 撤销', () {
    test('撤销恢复操作前快照并删除事件', () async {
      final before = await repo.recordFlashcardReview('undo_me', SelfRating.known, now: base);
      expect(before.post.status, WordStatus.learning);
      expect(before.post.stability, greaterThan(0));

      final restored = await repo.undoLatestReview();
      expect(restored, isNotNull);
      expect(restored!.word, 'undo_me');
      // 首次自评撤销 → 回到操作前状态（newCard → unknown，S=0）
      expect(restored.status, before.pre.status);
      expect(restored.status, WordStatus.unknown);
      expect(restored.stability, 0);

      expect(await repo.reviewHistoryOf('undo_me'), isEmpty);
    });

    test('无事件时返回 null', () async {
      final result = await repo.undoLatestReview();
      expect(result, isNull);
    });
  });

  group('StatsRepository 聚合（旧项目指标公式的 GoSlow 实现）', () {
    test('评级分布 / 认识率 / 去重词数', () async {
      await repo.recordFlashcardReview('alpha', SelfRating.known, now: base);
      await repo.recordFlashcardReview('alpha', SelfRating.known, now: base + 1000);
      await repo.recordFlashcardReview('beta', SelfRating.unknown, now: base + 2000);
      await repo.recordFlashcardReview('beta', SelfRating.familiar, now: base + 3000);

      final s = await stats.compute(now: base + 4000);
      expect(s.totalReviews, 4);
      expect(s.knownReviews, 2);
      expect(s.missReviews, 2);
      expect(s.distinctLearnedWords, 2);
      expect(s.ratingDistribution[FsrsRating.good], 2);
      expect(s.ratingDistribution[FsrsRating.again], 1);
      expect(s.ratingDistribution[FsrsRating.hard], 1);
      expect(s.goodRatePct, closeTo(50, 0.001));
    });

    test('成熟转化率 / 成熟词汇失忆率', () async {
      // alpha 连续认识 → 达到 Review（成熟）
      await repo.recordFlashcardReview('alpha', SelfRating.known, now: base);
      await repo.recordFlashcardReview('alpha', SelfRating.known, now: base + 1000);
      await repo.recordFlashcardReview('alpha', SelfRating.known, now: base + 2000);

      final s = await stats.compute(now: base + 3000);
      expect(s.matureCount, 1); // review 状态 = known
      expect(s.matureForgottenEvents, 0);
      expect(s.matureConversionRatePct, closeTo(1 / 3 * 100, 0.001));
      expect(s.forgetRatePct, 0);
    });

    test('积压量 = 此刻已到期未复习的词数', () async {
      await repo.recordFlashcardReview('due_word', SelfRating.unknown, now: base); // S=0.4d
      await repo.recordFlashcardReview('far_word', SelfRating.known, now: base); // S=2.4d

      final s = await stats.compute(now: base);
      expect(s.backlogCount, 0);

      final later = await stats.compute(now: base + (0.5 * 86400000).round());
      expect(later.backlogCount, 1); // 只有 due_word 到期
    });

    test('掌握度曲线：按天聚合认识率 + 连续天数', () async {
      // 第 1 天：2 认识 1 不认识
      await repo.recordFlashcardReview('a', SelfRating.known, now: base);
      await repo.recordFlashcardReview('b', SelfRating.known, now: base + 60000);
      await repo.recordFlashcardReview('c', SelfRating.unknown, now: base + 120000);
      // 第 2 天：1 认识
      final day2 = base + 86400000;
      await repo.recordFlashcardReview('a', SelfRating.known, now: day2);

      final s = await stats.compute(now: day2 + 60000);
      expect(s.dailySeries.length, 2);
      final first = s.dailySeries.first;
      expect(first.reviews, 3);
      expect(first.goodCount, 2);
      expect(first.goodRate, closeTo(2 / 3, 0.001));
      expect(s.streakDays, 2);
    });

    test('月度/年度汇总按周期聚合', () async {
      // base 本地日落在某月；+32 天必然跨到下一个月（时区无关）。
      await repo.recordFlashcardReview('a', SelfRating.known, now: base);
      await repo.recordFlashcardReview('b', SelfRating.known, now: base + 3600000);
      await repo.recordFlashcardReview('c', SelfRating.unknown, now: base + 32 * 86400000);

      final s = await stats.compute(now: base + 33 * 86400000);
      expect(s.monthlySeries.length, 2);
      final firstMonth = s.monthlySeries.first;
      expect(firstMonth.reviews, 2);
      expect(firstMonth.goodCount, 2);
      expect(firstMonth.goodRate, closeTo(1.0, 0.001));
      expect(s.monthlySeries.last.reviews, 1);
      expect(s.monthlySeries.last.goodRate, closeTo(0.0, 0.001));
      // 同一年内的两次自评 → 年度只有一条。
      expect(s.yearlySeries.length, 1);
      expect(s.yearlySeries.first.reviews, 3);
      expect(s.totalStudyDays, 2);
    });

    test('掌握分布：word_states 各状态计数', () async {
      await repo.recordFlashcardReview('alpha', SelfRating.known, now: base);
      await repo.recordFlashcardReview('alpha', SelfRating.known, now: base + 1000);
      await repo.recordFlashcardReview('beta', SelfRating.unknown, now: base + 2000);
      await repo.markKnown('gamma');

      final s = await stats.compute(now: base + 3000);
      expect(s.masteryDistribution[WordStatus.known], 2); // alpha(成熟) + gamma
      expect(s.masteryDistribution[WordStatus.learning], 1); // beta
      expect(s.masteryDistribution[WordStatus.familiar], 0);
      expect(s.masteryDistribution[WordStatus.unknown], 0);
    });
  });
}
