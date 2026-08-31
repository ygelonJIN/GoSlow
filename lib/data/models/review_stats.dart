import 'srs_card_state.dart';
import 'word_state.dart';

/// 按"逻辑日"聚合的单日掌握度采样（掌握度曲线数据点）。
class DailyReviewPoint {
  const DailyReviewPoint({
    required this.date,
    required this.reviews,
    required this.goodCount,
  });

  /// yyyy-MM-dd（本地时区）。
  final String date;
  final int reviews;
  final int goodCount;

  /// 当日认识率（Good / 总自评）。
  double get goodRate => reviews > 0 ? goodCount / reviews : 0.0;
}

/// 按"逻辑月 / 年"聚合的周期采样（月度/年度汇总）。
class PeriodReviewPoint {
  const PeriodReviewPoint({
    required this.key,
    required this.reviews,
    required this.goodCount,
  });

  /// yyyy-MM（月）或 yyyy（年），本地时区。
  final String key;
  final int reviews;
  final int goodCount;

  /// 该周期认识率（Good / 总自评）。
  double get goodRate => reviews > 0 ? goodCount / reviews : 0.0;

  /// 展示标签：2026-08 → 「26年8月」；2026 → 「2026年」。
  String get label {
    final parts = key.split('-');
    if (parts.length == 2) {
      return '${parts[0].substring(2)}年${int.parse(parts[1])}月';
    }
    return '${parts.first}年';
  }
}

/// 统计总览（从 review_events 事件表 + word_states 推导，永不靠计数器）。
///
/// 指标公式沿用旧项目（成熟转化率 / 成熟词汇失忆率 / 积压量），
/// 但数据源从"日志聚合"改为事件聚合，可追溯、可撤销、可重放。
class ReviewStats {
  const ReviewStats({
    required this.totalReviews,
    required this.ratingDistribution,
    required this.knownReviews,
    required this.missReviews,
    required this.distinctLearnedWords,
    required this.matureCount,
    required this.matureForgottenEvents,
    required this.backlogCount,
    required this.streakDays,
    required this.dailySeries,
    required this.monthlySeries,
    required this.yearlySeries,
    required this.masteryDistribution,
  });

  final int totalReviews;

  /// 评级分布：{评级: 次数}。
  final Map<FsrsRating, int> ratingDistribution;

  /// 自评"认识"次数（Good）。
  final int knownReviews;

  /// 自评"模糊/不认识"次数（Hard/Again）。
  final int missReviews;

  /// 有自评记录的不同单词数。
  final int distinctLearnedWords;

  /// 成熟词数（当前处于 Review 状态 = WordStatus.known）。
  final int matureCount;

  /// "成熟词失忆"事件数（Review 状态下 R<0.5 时 Again）。
  final int matureForgottenEvents;

  /// 积压量：此刻已到期未复习的词数。
  final int backlogCount;

  /// 连续学习天数（有自评记录的连续自然日）。
  final int streakDays;

  /// 掌握度曲线：每天的自评量与认识率（按时间正序）。
  final List<DailyReviewPoint> dailySeries;

  /// 月度汇总：自评量与认识率（按时间正序）。
  final List<PeriodReviewPoint> monthlySeries;

  /// 年度汇总：自评量与认识率（按时间正序）。
  final List<PeriodReviewPoint> yearlySeries;

  /// 当前掌握度分布：认识 / 学习中 / 模糊 / 未处理。
  final Map<WordStatus, int> masteryDistribution;

  /// 共学习天数 = 有自评记录的不同自然日数。
  int get totalStudyDays => dailySeries.length;

  /// 认识率（Good 占比，0-100）。
  double get goodRatePct => totalReviews > 0 ? knownReviews / totalReviews * 100 : 0;

  /// 评级占比（0-100）。
  double ratingPct(FsrsRating rating) =>
      totalReviews > 0 ? ((ratingDistribution[rating] ?? 0) / totalReviews * 100) : 0;

  /// 成熟转化率 = 成熟词数 / 累计自评次数。
  /// 含义：一个"新词"平均需要经历多少次自评才能转化为"成熟"状态。
  double get matureConversionRatePct =>
      totalReviews > 0 ? matureCount / totalReviews * 100 : 0;

  /// 成熟词汇失忆率 = 成熟词失忆事件数 / 成熟词数。
  /// 含义：已进入长期记忆区（间隔 > 21 天，R ≥ 0.9）的词被遗忘的概率。
  double get forgetRatePct =>
      matureCount > 0 ? matureForgottenEvents / matureCount * 100 : 0;

  String get dateLabel => dailySeries.isEmpty ? '' : dailySeries.last.date;
}
