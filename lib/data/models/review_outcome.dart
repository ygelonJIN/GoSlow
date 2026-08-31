import 'srs_card_state.dart';
import 'word_state.dart';

/// 一次闪卡自评的结果：操作前/后状态对。
///
/// Result 结算页的会话级指标（平均 S/R 变化、新学/复习/重学分组）
/// 全部由 outcome 推导，与旧项目 ResultPage 的 SessionStats 对应。
class ReviewOutcome {
  const ReviewOutcome({required this.word, required this.pre, required this.post});

  final String word;
  final WordState pre;
  final WordState post;
}

/// 一轮闪卡中的一条自评记录：评级 + 前后状态。
class SessionEntry {
  const SessionEntry({required this.rating, required this.outcome});

  final SelfRating rating;
  final ReviewOutcome outcome;
}

/// 一个闪卡会话（一轮牌堆）的结算统计。
///
/// 公式沿用旧项目 `calculateSessionStats`：平均稳定性变化 =
/// 各卡 (post.S − pre.S) 的均值；平均可提取性变化同理；分组按操作前状态：
/// 新学（未处理） / 复习（成熟词到期回来） / 重学（learning/familiar 再复习）。
class SessionStats {
  const SessionStats({
    required this.totalCards,
    required this.newCards,
    required this.reviewCards,
    required this.relearnCards,
    required this.ratingDistribution,
    required this.avgStabilityChange,
    required this.avgRetrievabilityChange,
    required this.spellings,
  });

  final int totalCards;
  final int newCards;
  final int reviewCards;
  final int relearnCards;

  /// 本轮三档自评分布：{评级: 次数}。
  final Map<SelfRating, int> ratingDistribution;

  /// 平均稳定性变化（天）。正 = 本轮整体记忆强度提升。
  final double avgStabilityChange;

  /// 平均可提取性变化（0-1 的均值，显示时乘 100）。
  final double avgRetrievabilityChange;

  /// 本轮学习的词（按出现顺序，去重）。
  final List<String> spellings;

  double ratingPct(SelfRating rating) =>
      totalCards > 0 ? (ratingDistribution[rating] ?? 0) / totalCards * 100 : 0;
}

/// 从一轮自评记录计算会话统计（纯函数，无 DB 依赖）。
SessionStats computeSessionStats(List<SessionEntry> entries) {
  var newCards = 0;
  var reviewCards = 0;
  var relearnCards = 0;
  var totalS = 0.0;
  var totalR = 0.0;
  final dist = <SelfRating, int>{};
  final spellings = <String>[];

  for (final e in entries) {
    final o = e.outcome;
    dist[e.rating] = (dist[e.rating] ?? 0) + 1;
    totalS += o.post.stability - o.pre.stability;
    // 从未见过的词没有"先前的可提取性"：归一为 1.0，新卡不产生虚假衰减/增益。
    final preR = o.pre.status == WordStatus.unknown ? 1.0 : o.pre.retrievability;
    totalR += o.post.retrievability - preR;

    switch (o.pre.status) {
      case WordStatus.unknown:
        newCards++;
      case WordStatus.known:
        reviewCards++;
      case WordStatus.learning:
      case WordStatus.familiar:
        relearnCards++;
    }
    if (!spellings.contains(o.word)) {
      spellings.add(o.word);
    }
  }

  final n = entries.length;
  return SessionStats(
    totalCards: n,
    newCards: newCards,
    reviewCards: reviewCards,
    relearnCards: relearnCards,
    ratingDistribution: dist,
    avgStabilityChange: n > 0 ? totalS / n : 0,
    avgRetrievabilityChange: n > 0 ? totalR / n : 0,
    spellings: spellings,
  );
}
