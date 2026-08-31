import '../srs/fsrs_calculator.dart';
import 'srs_card_state.dart';

/// 单词掌握状态（本地用户数据，与词库分离）。
///
/// 调度由 FSRS v4 驱动（见 `lib/data/srs/fsrs_calculator.dart`）：
/// `status` 是从 SRS 状态派生出的产品层掌握度标签，真正的"下次该何时复习"
/// 由 `stability / nextReviewAt` 决定。`correct/wrong/consecutive` 计数
/// 保留用于统计展示（掌握度曲线、认识次数），不再参与 known 判定。
class WordState {
  const WordState({
    required this.word,
    this.status = WordStatus.unknown,
    this.favorite = false,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.consecutiveCorrect = 0,
    this.lastSeenAt,
    this.stability = 0.0,
    this.difficulty = 0.0,
    this.retrievability = 0.0,
    this.nextReviewAt,
    this.lastReviewAt,
    this.failCount = 0,
  });

  final String word;
  final WordStatus status;
  final bool favorite;
  final int correctCount;
  final int wrongCount;

  /// 连续自评"认识"次数（仅统计展示，不参与调度）。
  final int consecutiveCorrect;
  final DateTime? lastSeenAt;

  // ---- FSRS 调度字段（与 word_states 表 V4 列一一对应）----
  final double stability;
  final double difficulty;
  final double retrievability;
  final int? nextReviewAt;
  final int? lastReviewAt;
  final int failCount;

  /// 该词此刻是否到期（无调度时间视为未排期 → 不 due）。
  bool isDue(int now) => nextReviewAt != null && nextReviewAt! <= now;

  WordState copyWith({
    WordStatus? status,
    bool? favorite,
    int? correctCount,
    int? wrongCount,
    int? consecutiveCorrect,
    DateTime? lastSeenAt,
    double? stability,
    double? difficulty,
    double? retrievability,
    int? nextReviewAt,
    int? lastReviewAt,
    int? failCount,
  }) {
    return WordState(
      word: word,
      status: status ?? this.status,
      favorite: favorite ?? this.favorite,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      consecutiveCorrect: consecutiveCorrect ?? this.consecutiveCorrect,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      retrievability: retrievability ?? this.retrievability,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      lastReviewAt: lastReviewAt ?? this.lastReviewAt,
      failCount: failCount ?? this.failCount,
    );
  }

  factory WordState.fromRow(Map<String, Object?> row) {
    return WordState(
      word: (row['word'] as String?) ?? '',
      status: WordStatusX.fromDb((row['status'] as String?) ?? 'unknown'),
      favorite: ((row['favorite'] as int?) ?? 0) == 1,
      correctCount: (row['correct_count'] as int?) ?? 0,
      wrongCount: (row['wrong_count'] as int?) ?? 0,
      consecutiveCorrect: (row['consecutive_correct'] as int?) ?? 0,
      lastSeenAt: (row['last_seen_at'] as int?) != null
          ? DateTime.fromMillisecondsSinceEpoch(row['last_seen_at'] as int)
          : null,
      stability: ((row['stability'] as num?) ?? 0).toDouble(),
      difficulty: ((row['difficulty'] as num?) ?? 0).toDouble(),
      retrievability: ((row['retrievability'] as num?) ?? 0).toDouble(),
      nextReviewAt: row['next_review_at'] as int?,
      lastReviewAt: row['last_review_at'] as int?,
      failCount: (row['fail_count'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toRow() {
    return {
      'word': word,
      'status': status.dbValue,
      'favorite': favorite ? 1 : 0,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'consecutive_correct': consecutiveCorrect,
      'last_seen_at': lastSeenAt?.millisecondsSinceEpoch,
      'stability': stability,
      'difficulty': difficulty,
      'retrievability': retrievability,
      'next_review_at': nextReviewAt,
      'last_review_at': lastReviewAt,
      'fail_count': failCount,
    };
  }

  /// 重建 FSRS 卡片状态（首次出现的词：稳定性为 0 时按新卡处理）。
  SrsCardState toSrs({required int now, required FsrsCalculator fsrs}) {
    if (status == WordStatus.unknown || (stability <= 0 && nextReviewAt == null)) {
      return fsrs.createNewCard(now: now);
    }
    return SrsCardState(
      status: _srsStatusFor(status),
      stability: stability,
      difficulty: difficulty,
      retrievability: retrievability,
      nextReviewAt: nextReviewAt ?? now,
      lastReviewAt: lastReviewAt ?? now,
      failCount: failCount,
    );
  }

  /// 闪卡自评 → FSRS 推进（纯函数，无 DB 依赖）。
  ///
  /// [now] 自评时间戳（毫秒）；[lastFailTime] 上次 Again 的时间戳，用于
  /// Relearning 12 小时宽容窗口（忘记后很快想起 → S×1.2，不重算）。
  WordState applyReview({
    required FsrsRating rating,
    required int now,
    required FsrsCalculator fsrs,
    int? lastFailTime,
  }) {
    final srs = toSrs(now: now, fsrs: fsrs);
    final next = fsrs.calculateNextState(
      card: srs,
      rating: rating,
      currentTime: now,
      lastFailTime: lastFailTime,
    );

    final known = rating == FsrsRating.good;
    final missed = rating == FsrsRating.again || rating == FsrsRating.hard;
    return WordState(
      word: word,
      status: next.status.toWordStatus,
      favorite: favorite,
      correctCount: correctCount + (known ? 1 : 0),
      wrongCount: wrongCount + (missed ? 1 : 0),
      consecutiveCorrect: known ? consecutiveCorrect + 1 : 0,
      lastSeenAt: DateTime.fromMillisecondsSinceEpoch(now),
      stability: next.stability,
      difficulty: next.difficulty,
      retrievability: next.retrievability,
      nextReviewAt: next.nextReviewAt,
      lastReviewAt: now,
      failCount: next.failCount,
    );
  }

  static SrsStatus _srsStatusFor(WordStatus status) {
    switch (status) {
      case WordStatus.unknown:
        return SrsStatus.newCard;
      case WordStatus.learning:
        return SrsStatus.learning;
      case WordStatus.familiar:
        return SrsStatus.relearning;
      case WordStatus.known:
        return SrsStatus.review;
    }
  }
}

enum WordStatus { unknown, learning, familiar, known }

extension SrsStatusToWordStatusX on SrsStatus {
  /// SRS 状态 → 产品层掌握度（保证 knownWords / 待复习语义不变）：
  ///   Review → known · Relearning → familiar · Learning → learning · New → unknown
  WordStatus get toWordStatus {
    switch (this) {
      case SrsStatus.newCard:
        return WordStatus.unknown;
      case SrsStatus.learning:
        return WordStatus.learning;
      case SrsStatus.relearning:
        return WordStatus.familiar;
      case SrsStatus.review:
        return WordStatus.known;
    }
  }
}

extension WordStatusX on WordStatus {
  String get dbValue {
    switch (this) {
      case WordStatus.unknown:
        return 'unknown';
      case WordStatus.learning:
        return 'learning';
      case WordStatus.familiar:
        return 'familiar';
      case WordStatus.known:
        return 'known';
    }
  }

  static WordStatus fromDb(String v) {
    switch (v) {
      case 'learning':
        return WordStatus.learning;
      case 'familiar':
        return WordStatus.familiar;
      case 'known':
        return WordStatus.known;
      default:
        return WordStatus.unknown;
    }
  }

  String get label {
    switch (this) {
      case WordStatus.unknown:
        return '未处理';
      case WordStatus.learning:
        return '学习中';
      case WordStatus.familiar:
        return '模糊';
      case WordStatus.known:
        return '已认识';
    }
  }
}
