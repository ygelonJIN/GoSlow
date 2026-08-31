import '../db/app_database.dart';
import '../models/review_event.dart';
import '../models/review_stats.dart';
import '../models/srs_card_state.dart';
import '../models/word_state.dart';

/// 统计仓储：全部指标从 `review_events` + `word_states` 聚合（事件溯源）。
class StatsRepository {
  StatsRepository(this._db);

  final AppDatabase _db;

  /// 计算统计总览。
  ///
  /// [now] 可注入（测试用）；默认取当前时间。
  Future<ReviewStats> compute({int? now}) async {
    final timestamp = now ?? DateTime.now().millisecondsSinceEpoch;
    final db = await _db.database;

    final eventRows = await db.query('review_events', orderBy: 'created_at ASC');
    final events = eventRows.map(ReviewEvent.fromRow).toList();

    final stateRows = await db.query('word_states');
    final states = stateRows.map(WordState.fromRow).toList();

    // ---- 评级分布 / 认识次数 ----
    final ratingDist = <FsrsRating, int>{};
    var knownReviews = 0;
    var missReviews = 0;
    var matureForgotten = 0;
    final distinctWords = <String>{};
    final perDay = <String, _DayBucket>{};
    final perMonth = <String, _DayBucket>{};
    final perYear = <String, _DayBucket>{};

    for (final e in events) {
      distinctWords.add(e.word);
      ratingDist[e.rating] = (ratingDist[e.rating] ?? 0) + 1;
      if (e.isKnown) {
        knownReviews++;
      } else {
        missReviews++;
      }
      // 成熟词失忆：处于 Review 且可提取性已跌破 50% 时仍被忘记。
      if (e.rating == FsrsRating.again &&
          e.preStatus == SrsStatus.review &&
          e.preRetrievability < 0.5) {
        matureForgotten++;
      }
      final d = DateTime.fromMillisecondsSinceEpoch(e.createdAt);
      _addBucket(perDay, _fmt(d), e.isKnown);
      _addBucket(perMonth, '${d.year}-${_two(d.month)}', e.isKnown);
      _addBucket(perYear, '${d.year}', e.isKnown);
    }

    final dailySeries = [
      for (final entry in perDay.entries)
        DailyReviewPoint(
          date: entry.key,
          reviews: entry.value.total,
          goodCount: entry.value.good,
        ),
    ]..sort((a, b) => a.date.compareTo(b.date));

    final monthlySeries = [
      for (final entry in perMonth.entries)
        PeriodReviewPoint(
          key: entry.key,
          reviews: entry.value.total,
          goodCount: entry.value.good,
        ),
    ]..sort((a, b) => a.key.compareTo(b.key));

    final yearlySeries = [
      for (final entry in perYear.entries)
        PeriodReviewPoint(
          key: entry.key,
          reviews: entry.value.total,
          goodCount: entry.value.good,
        ),
    ]..sort((a, b) => a.key.compareTo(b.key));

    // ---- 当前掌握度分布 / 成熟词 / 积压 ----
    final mastery = <WordStatus, int>{
      WordStatus.unknown: 0,
      WordStatus.learning: 0,
      WordStatus.familiar: 0,
      WordStatus.known: 0,
    };
    var matureCount = 0;
    var backlog = 0;
    for (final s in states) {
      mastery[s.status] = (mastery[s.status] ?? 0) + 1;
      if (s.status == WordStatus.known) matureCount++;
      if (s.isDue(timestamp)) backlog++;
    }

    return ReviewStats(
      totalReviews: events.length,
      ratingDistribution: ratingDist,
      knownReviews: knownReviews,
      missReviews: missReviews,
      distinctLearnedWords: distinctWords.length,
      matureCount: matureCount,
      matureForgottenEvents: matureForgotten,
      backlogCount: backlog,
      streakDays: _consecutiveDays(perDay.keys.toList(), timestamp),
      dailySeries: dailySeries,
      monthlySeries: monthlySeries,
      yearlySeries: yearlySeries,
      masteryDistribution: mastery,
    );
  }

  static void _addBucket(Map<String, _DayBucket> buckets, String key, bool isKnown) {
    final bucket = buckets.putIfAbsent(key, () => _DayBucket());
    bucket.total++;
    if (isKnown) bucket.good++;
  }

  /// 有自评记录的连续自然日数（以 [now] 所在日向前数；今天没学不打断）。
  int _consecutiveDays(List<String> dates, int now) {
    if (dates.isEmpty) return 0;
    final sorted = dates.toSet().toList()..sort();
    final d = DateTime.fromMillisecondsSinceEpoch(now);
    final today = DateTime(d.year, d.month, d.day);

    // 今天还没学不打断 streak（从昨天起算）。
    var anchor = sorted.contains(_fmt(today))
        ? today
        : today.subtract(const Duration(days: 1));

    var streak = 0;
    for (var i = sorted.length - 1; i >= 0; i--) {
      final day = sorted[i];
      if (day == _fmt(anchor)) {
        streak++;
        anchor = anchor.subtract(const Duration(days: 1));
      } else if (day.compareTo(_fmt(anchor)) < 0) {
        break; // 中间断档
      }
    }
    return streak;
  }
}

class _DayBucket {
  int total = 0;
  int good = 0;
}

String _fmt(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

String _two(int v) => v.toString().padLeft(2, '0');
