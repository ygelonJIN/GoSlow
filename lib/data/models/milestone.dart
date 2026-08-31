/// 里程碑（M4 庆祝）— 见 docs/开发文档.md §3.6。
///
/// 当前实现"认识词数里程碑"（累计认识词数达到 100/500/1000/2000/3000/5000）。
/// `kind` 预留扩展位：后续"内容完成结算 / 周目标达成"沿用同一模型。
class Milestone {
  const Milestone({
    required this.kind,
    required this.threshold,
    required this.achievedAt,
  });

  /// 里程碑类型：当前仅认识词数（`known_words`）。
  final String kind;

  /// 阈值（如认识词数达到 100）。
  final int threshold;

  /// 达成（被庆祝）时间。
  final DateTime achievedAt;

  static const String kindKnownWords = 'known_words';

  String get id => '$kind:$threshold';

  factory Milestone.fromRow(Map<String, Object?> row) {
    return Milestone(
      kind: (row['kind'] as String?) ?? kindKnownWords,
      threshold: (row['threshold'] as int?) ?? 0,
      achievedAt: DateTime.fromMillisecondsSinceEpoch((row['achieved_at'] as int?) ?? 0),
    );
  }

  Map<String, Object?> toRow() => {
        'kind': kind,
        'threshold': threshold,
        'achieved_at': achievedAt.millisecondsSinceEpoch,
      };
}

/// 认识词数里程碑阈值（§3.6：100 / 500 / 1000 / 2000 / 3000 / 5000）。
const List<int> kKnownWordMilestones = [100, 500, 1000, 2000, 3000, 5000];

/// 纯函数：给定当前认识词数 + 已庆祝阈值，返回新达成的里程碑阈值（升序）。
///
/// 达标且未庆祝过的才返回，保证每个里程碑只庆祝一次。
List<int> newlyReachedKnownWordMilestones({
  required int knownCount,
  required Set<int> achieved,
}) {
  return [
    for (final t in kKnownWordMilestones)
      if (knownCount >= t && !achieved.contains(t)) t,
  ];
}
