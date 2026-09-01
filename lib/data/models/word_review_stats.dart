/// 单个单词的自评历史统计（从 review_events 事件表聚合）。
///
/// 供闪卡学习页 / 点词面板复用：展示「出现过几次」以及
/// 认识 / 模糊 / 不认识的占比（都是之前自评留下的记录）。
class WordReviewStats {
  const WordReviewStats({
    required this.total,
    required this.known,
    required this.familiar,
    required this.unknown,
  });

  /// 累计自评次数（这个词"出现过"几次）。
  final int total;

  /// 认识（Good）次数。
  final int known;

  /// 模糊（Hard）次数。
  final int familiar;

  /// 不认识（Again）次数。
  final int unknown;

  bool get isEmpty => total == 0;

  int get knownPct => total == 0 ? 0 : (known * 100 / total).round();
  int get familiarPct => total == 0 ? 0 : (familiar * 100 / total).round();
  int get unknownPct => total == 0 ? 0 : (unknown * 100 / total).round();
}
