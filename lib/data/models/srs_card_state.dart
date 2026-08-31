/// FSRS 卡片状态（不可变）。
///
/// 存储的物理字段与 `word_states` 表一一对应，见
/// `AppDatabase._createV4`。`SrsStatus` 与产品层的 `WordStatus`
/// 映射关系见 [SrsStatus.toWordStatus]。
class SrsCardState {
  const SrsCardState({
    required this.status,
    required this.stability,
    required this.difficulty,
    required this.retrievability,
    required this.nextReviewAt,
    required this.lastReviewAt,
    required this.failCount,
  });

  final SrsStatus status;

  /// S：稳定性（天）。越大代表记忆越牢固，下次间隔越长。
  final double stability;

  /// D：难度（1-10 区间，越大越难）。
  final double difficulty;

  /// R：可提取性（0-1，当前记忆留存率）。
  final double retrievability;

  /// 下次复习时间（UTC 毫秒）。
  final int nextReviewAt;

  /// 上次自评时间（UTC 毫秒）。
  final int lastReviewAt;

  /// 累计忘记次数（Review 阶段 Again 的次数）。
  final int failCount;

  bool isDue(int now) => nextReviewAt <= now;

  SrsCardState copyWith({
    SrsStatus? status,
    double? stability,
    double? difficulty,
    double? retrievability,
    int? nextReviewAt,
    int? lastReviewAt,
    int? failCount,
  }) {
    return SrsCardState(
      status: status ?? this.status,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      retrievability: retrievability ?? this.retrievability,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      lastReviewAt: lastReviewAt ?? this.lastReviewAt,
      failCount: failCount ?? this.failCount,
    );
  }
}

/// FSRS 卡片四态（对应旧项目 CardStatus：New/Learning/Review/Relearning）。
enum SrsStatus { newCard, learning, review, relearning }

extension SrsStatusX on SrsStatus {
  /// 持久化值（word_states.status 列沿用产品层枚举，见 [toWordStatus]）。
  int get dbValue => index;

  static SrsStatus fromDb(int v) => SrsStatus.values[v.clamp(0, 3)];
}

/// FSRS 评级。
enum FsrsRating { again, hard, good, easy }

extension FsrsRatingX on FsrsRating {
  /// 数据库存储值（1-4，与旧项目 FSRSCardRating 一致）。
  int get dbValue => index + 1;

  static FsrsRating fromDb(int v) => FsrsRating.values[(v - 1).clamp(0, 3)];
}

/// 闪卡三档自评（产品层）。
enum SelfRating { known, familiar, unknown }

extension SelfRatingX on SelfRating {
  /// 三档自评 → FSRS 评级（认识→Good，模糊→Hard，不认识→Again）。
  FsrsRating get toFsrs {
    switch (this) {
      case SelfRating.known:
        return FsrsRating.good;
      case SelfRating.familiar:
        return FsrsRating.hard;
      case SelfRating.unknown:
        return FsrsRating.again;
    }
  }
}
