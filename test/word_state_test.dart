import 'package:goslow/data/models/srs_card_state.dart';
import 'package:goslow/data/models/word_state.dart';
import 'package:goslow/data/srs/fsrs_calculator.dart';
import 'package:test/test.dart';

void main() {
  final fsrs = FsrsCalculator();
  final t0 = DateTime.utc(2026, 8, 31, 12).millisecondsSinceEpoch;
  const day = 86400000;

  WordState state({WordStatus status = WordStatus.unknown, int correct = 0, int wrong = 0}) {
    return WordState(word: 'test', status: status, correctCount: correct, wrongCount: wrong);
  }

  WordState applyAt(WordState s, SelfRating rating, int now, {int? lastFail}) {
    return s.applyReview(rating: rating.toFsrs, now: now, fsrs: fsrs, lastFailTime: lastFail);
  }

  /// 通过"到期后答对"建立 S≈6.4 的长期记忆卡（known）。
  WordState longLivedKnown() {
    var s = applyAt(state(), SelfRating.known, t0);
    s = applyAt(s, SelfRating.known, t0 + 3 * day);
    return applyAt(s, SelfRating.known, t0 + 9 * day);
  }

  group('WordState.applyReview 三档自评（§6 掌握度模型升级版）', () {
    test('首次认识 → learning，S=2.4 天，nextReviewAt 排期', () {
      final next = applyAt(state(), SelfRating.known, t0);
      expect(next.status, WordStatus.learning);
      expect(next.correctCount, 1);
      expect(next.nextReviewAt, t0 + (2.4 * day).floor());
      expect(next.lastReviewAt, t0);
    });

    test('首次模糊 → learning，S=0.6 天（短间隔）', () {
      final next = applyAt(state(), SelfRating.familiar, t0);
      expect(next.status, WordStatus.learning);
      expect(next.wrongCount, 1);
      expect(next.stability, closeTo(0.6, 0.001));
    });

    test('首次不认识 → learning，S=0.4 天（短间隔）', () {
      final next = applyAt(state(), SelfRating.unknown, t0);
      expect(next.status, WordStatus.learning);
      expect(next.wrongCount, 1);
      expect(next.stability, closeTo(0.4, 0.001));
    });

    test('认识 → 模糊 → 认识 → known（连续两次答对即成熟）', () {
      final a = applyAt(state(), SelfRating.known, t0);
      final b = applyAt(a, SelfRating.familiar, t0);
      final c = applyAt(b, SelfRating.known, t0);
      expect(c.status, WordStatus.known);
      expect(c.correctCount, 2);
      expect(c.consecutiveCorrect, 1);
    });

    test('known 后模糊 → 保持 known，S×0.86', () {
      final known = longLivedKnown();
      expect(known.status, WordStatus.known);
      final next = applyAt(known, SelfRating.familiar, t0 + 20 * day);
      expect(next.status, WordStatus.known);
      expect(next.stability, closeTo(known.stability * 0.86, 0.001));
    });

    test('known 后不认识 → familiar（relearning），failCount=1，S 衰减', () {
      final known = longLivedKnown();
      final next = applyAt(known, SelfRating.unknown, t0 + 60 * day);
      expect(next.status, WordStatus.familiar);
      expect(next.failCount, 1);
      expect(next.stability, lessThan(known.stability));
    });

    test('relearning 12h 内认识 → known，S×1.2 宽容恢复', () {
      final relearned = applyAt(longLivedKnown(), SelfRating.unknown, t0 + 60 * day);
      final recovered = applyAt(
        relearned,
        SelfRating.known,
        t0 + 60 * day + 3600000, // 1 小时后想起
        lastFail: t0 + 60 * day,
      );
      expect(recovered.status, WordStatus.known);
      expect(recovered.stability, closeTo(relearned.stability * 1.2, 0.001));
    });

    test('连续认识清零：模糊后 consecutiveCorrect=0', () {
      final a = applyAt(state(), SelfRating.known, t0);
      final b = applyAt(a, SelfRating.familiar, t0);
      expect(b.consecutiveCorrect, 0);
    });

    test('isDue：排期时间 <= now 才到期', () {
      final fresh = state();
      expect(fresh.isDue(t0), isFalse);

      final later = applyAt(fresh, SelfRating.known, t0); // 2.4 天后
      expect(later.isDue(t0), isFalse);
      expect(later.isDue(t0 + 3 * day), isTrue);

      final learned = applyAt(fresh, SelfRating.unknown, t0); // S=0.4 天
      final reAgain = applyAt(learned, SelfRating.unknown, t0); // learning 再忘 → +5min
      expect(reAgain.nextReviewAt, t0 + 300000);
      expect(reAgain.isDue(t0 + 300001), isTrue);
    });
  });
}
