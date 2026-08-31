import 'package:goslow/data/models/review_outcome.dart';
import 'package:goslow/data/models/srs_card_state.dart';
import 'package:goslow/data/models/word_state.dart';
import 'package:goslow/data/srs/fsrs_calculator.dart';
import 'package:test/test.dart';

void main() {
  final fsrs = FsrsCalculator();
  final t0 = DateTime.utc(2026, 8, 31, 12).millisecondsSinceEpoch;
  const day = 86400000;

  /// 从一个全新词自评产生 outcome。
  ReviewOutcome freshOutcome(String word, SelfRating rating, {int now = 0}) {
    final pre = WordState(word: word);
    final post = pre.applyReview(rating: rating.toFsrs, now: now == 0 ? t0 : now, fsrs: fsrs);
    return ReviewOutcome(word: word, pre: pre, post: post);
  }

  SessionEntry entry(SelfRating rating, ReviewOutcome o) => SessionEntry(rating: rating, outcome: o);

  group('computeSessionStats 会话结算（对应旧项目 ResultPage SessionStats）', () {
    test('评级分布与百分比', () {
      final stats = computeSessionStats([
        entry(SelfRating.known, freshOutcome('a', SelfRating.known)),
        entry(SelfRating.familiar, freshOutcome('b', SelfRating.familiar)),
        entry(SelfRating.unknown, freshOutcome('c', SelfRating.unknown)),
        entry(SelfRating.known, freshOutcome('d', SelfRating.known)),
      ]);
      expect(stats.totalCards, 4);
      expect(stats.ratingDistribution[SelfRating.known], 2);
      expect(stats.ratingDistribution[SelfRating.familiar], 1);
      expect(stats.ratingDistribution[SelfRating.unknown], 1);
      expect(stats.ratingPct(SelfRating.known), closeTo(50, 0.001));
      expect(stats.ratingPct(SelfRating.unknown), closeTo(25, 0.001));
    });

    test('分组：新学（未处理）/ 复习（known 到期）/ 重学（learning/familiar）', () {
      final fresh = freshOutcome('new_word', SelfRating.known);
      final knownPre = WordState(word: 'mature', status: WordStatus.known, stability: 10, nextReviewAt: t0);
      final knownPost = knownPre.applyReview(rating: FsrsRating.good, now: t0, fsrs: fsrs);
      final relearnPre = WordState(word: 'weak', status: WordStatus.learning, stability: 2.4, nextReviewAt: t0);
      final relearnPost = relearnPre.applyReview(rating: FsrsRating.again, now: t0, fsrs: fsrs);

      final stats = computeSessionStats([
        entry(SelfRating.known, fresh),
        entry(SelfRating.known, ReviewOutcome(word: 'mature', pre: knownPre, post: knownPost)),
        entry(SelfRating.unknown, ReviewOutcome(word: 'weak', pre: relearnPre, post: relearnPost)),
      ]);
      expect(stats.newCards, 1);
      expect(stats.reviewCards, 1);
      expect(stats.relearnCards, 1);
    });

    test('平均稳定性变化 = (post.S − pre.S) 的均值', () {
      final stats = computeSessionStats([
        entry(SelfRating.known, freshOutcome('a', SelfRating.known)), // S: 0 → 2.4
        entry(SelfRating.familiar, freshOutcome('b', SelfRating.familiar)), // S: 0 → 0.6
      ]);
      expect(stats.avgStabilityChange, closeTo((2.4 + 0.6) / 2, 0.001));
    });

    test('平均可提取性变化：新卡无衰减（0），到期复习反映真实衰减', () {
      final fresh = freshOutcome('a', SelfRating.known);
      // 到期卡：上次存储 R=0.9，逾期 20 天后才复习 → 当前 R 明显低于 0.9。
      final latePre = WordState(word: 'late', status: WordStatus.known, stability: 10, retrievability: 0.9, nextReviewAt: t0);
      final latePost = latePre.applyReview(rating: FsrsRating.good, now: t0 + 20 * day, fsrs: fsrs);

      final stats = computeSessionStats([
        entry(SelfRating.known, fresh),
        entry(SelfRating.known, ReviewOutcome(word: 'late', pre: latePre, post: latePost)),
      ]);
      expect(stats.avgRetrievabilityChange, closeTo((0 + (latePost.retrievability - 0.9)) / 2, 0.001));
      expect(latePost.retrievability, lessThan(0.9));
    });

    test('词单按出现顺序去重', () {
      final stats = computeSessionStats([
        entry(SelfRating.known, freshOutcome('alpha', SelfRating.known)),
        entry(SelfRating.familiar, freshOutcome('beta', SelfRating.familiar)),
        entry(SelfRating.known, freshOutcome('alpha', SelfRating.known)),
      ]);
      expect(stats.spellings, ['alpha', 'beta']);
    });

    test('空会话', () {
      final stats = computeSessionStats(const []);
      expect(stats.totalCards, 0);
      expect(stats.avgStabilityChange, 0);
      expect(stats.avgRetrievabilityChange, 0);
      expect(stats.spellings, isEmpty);
    });
  });
}
