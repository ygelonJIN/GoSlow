import 'srs_card_state.dart';

/// 一条闪卡自评事件（事件溯源：所有统计与撤销都从这张表推导）。
///
/// 每次自评写入"操作前快照 + 操作后结果"，与 `word_states` 当前值一起
/// 保证：统计永远可回溯、误操作可撤销、未来可换算法重放。
class ReviewEvent {
  const ReviewEvent({
    this.id,
    required this.word,
    required this.rating,
    required this.createdAt,
    required this.preStatus,
    required this.preStability,
    required this.preDifficulty,
    required this.preRetrievability,
    required this.preNextReviewAt,
    required this.postStatus,
    required this.postStability,
    required this.postDifficulty,
    required this.postRetrievability,
    required this.postNextReviewAt,
  });

  final int? id;
  final String word;

  /// 本次评级（FSRS 1-4）。
  final FsrsRating rating;
  final int createdAt;

  final SrsStatus preStatus;
  final double preStability;
  final double preDifficulty;
  final double preRetrievability;
  final int preNextReviewAt;

  final SrsStatus postStatus;
  final double postStability;
  final double postDifficulty;
  final double postRetrievability;
  final int postNextReviewAt;

  /// 自评是否为"认识"（Good）。
  bool get isKnown => rating == FsrsRating.good;

  /// 自评是否为"模糊/不认识"（Hard/Again）。
  bool get isMissed => rating == FsrsRating.again || rating == FsrsRating.hard;

  factory ReviewEvent.fromRow(Map<String, Object?> row) {
    return ReviewEvent(
      id: row['id'] as int?,
      word: (row['word'] as String?) ?? '',
      rating: FsrsRatingX.fromDb(row['rating'] as int),
      createdAt: (row['created_at'] as int?) ?? 0,
      preStatus: SrsStatusX.fromDb(row['pre_status'] as int),
      preStability: ((row['pre_stability'] as num?) ?? 0).toDouble(),
      preDifficulty: ((row['pre_difficulty'] as num?) ?? 0).toDouble(),
      preRetrievability: ((row['pre_retrievability'] as num?) ?? 0).toDouble(),
      preNextReviewAt: (row['pre_next_review_at'] as int?) ?? 0,
      postStatus: SrsStatusX.fromDb(row['post_status'] as int),
      postStability: ((row['post_stability'] as num?) ?? 0).toDouble(),
      postDifficulty: ((row['post_difficulty'] as num?) ?? 0).toDouble(),
      postRetrievability: ((row['post_retrievability'] as num?) ?? 0).toDouble(),
      postNextReviewAt: (row['post_next_review_at'] as int?) ?? 0,
    );
  }

  Map<String, Object?> toRow() {
    return {
      if (id != null) 'id': id,
      'word': word,
      'rating': rating.dbValue,
      'created_at': createdAt,
      'pre_status': preStatus.dbValue,
      'pre_stability': preStability,
      'pre_difficulty': preDifficulty,
      'pre_retrievability': preRetrievability,
      'pre_next_review_at': preNextReviewAt,
      'post_status': postStatus.dbValue,
      'post_stability': postStability,
      'post_difficulty': postDifficulty,
      'post_retrievability': postRetrievability,
      'post_next_review_at': postNextReviewAt,
    };
  }
}
