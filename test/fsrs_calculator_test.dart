import 'package:goslow/data/models/srs_card_state.dart';
import 'package:goslow/data/srs/fsrs_calculator.dart';
import 'package:test/test.dart';

void main() {
  final fsrs = FsrsCalculator();
  final now = DateTime.utc(2026, 8, 31, 12).millisecondsSinceEpoch;
  const day = 86400000;

  SrsCardState newCard() => fsrs.createNewCard(now: now);

  group('可提取性 R(t, S)', () {
    test('t=0 时 R=1.0', () {
      expect(fsrs.retrievability(0, 10), 1.0);
    });

    test('S 越大衰减越慢', () {
      final r10 = fsrs.retrievability(10, 10);
      final r100 = fsrs.retrievability(10, 100);
      expect(r10, lessThan(r100));
    });

    test('S<=0 时 R=0', () {
      expect(fsrs.retrievability(5, 0), 0.0);
    });
  });

  group('新卡评级 → Learning（S 按评级初始化）', () {
    test('认识(Good) → S=w2=2.4 天', () {
      final next = fsrs.calculateNextState(card: newCard(), rating: FsrsRating.good, currentTime: now);
      expect(next.status, SrsStatus.learning);
      expect(next.stability, closeTo(2.4, 0.001));
      expect(next.nextReviewAt, now + (2.4 * day).floor());
    });

    test('模糊(Hard) → S=w1=0.6 天', () {
      final next = fsrs.calculateNextState(card: newCard(), rating: FsrsRating.hard, currentTime: now);
      expect(next.stability, closeTo(0.6, 0.001));
    });

    test('不认识(Again) → S=w0=0.4 天', () {
      final next = fsrs.calculateNextState(card: newCard(), rating: FsrsRating.again, currentTime: now);
      expect(next.stability, closeTo(0.4, 0.001));
    });
  });

  group('Learning 状态流转', () {
    test('Learning + 认识 → Review，S 重算且大于 2.4（隔 3 天、R 衰减后）', () {
      final base = fsrs.calculateNextState(card: newCard(), rating: FsrsRating.good, currentTime: now);
      // 立即复习 R=1.0 时 S 不变；间隔 3 天后 R 衰减，S 才增长。
      final immediate = fsrs.calculateNextState(card: base, rating: FsrsRating.good, currentTime: now);
      expect(immediate.stability, closeTo(2.4, 0.001));

      final next = fsrs.calculateNextState(card: base, rating: FsrsRating.good, currentTime: now + 3 * day);
      expect(next.status, SrsStatus.review);
      expect(next.stability, greaterThan(2.4));
    });

    test('Learning + 不认识 → 维持 Learning，延后 5 分钟', () {
      final base = fsrs.calculateNextState(card: newCard(), rating: FsrsRating.good, currentTime: now);
      final next = fsrs.calculateNextState(card: base, rating: FsrsRating.again, currentTime: now);
      expect(next.status, SrsStatus.learning);
      expect(next.nextReviewAt, now + 300000);
    });

    test('Learning + 模糊 → 保持原状（不绑定额外业务）', () {
      final base = fsrs.calculateNextState(card: newCard(), rating: FsrsRating.good, currentTime: now);
      final next = fsrs.calculateNextState(card: base, rating: FsrsRating.hard, currentTime: now);
      expect(next.status, SrsStatus.learning);
      expect(next.stability, base.stability);
      expect(next.nextReviewAt, base.nextReviewAt);
    });
  });

  group('Review 状态流转', () {
    // 通过多次"到期后答对"建立 S≈6.4 的长期记忆卡。
    SrsCardState longLivedCard() {
      var c = fsrs.createNewCard(now: now);
      c = fsrs.calculateNextState(card: c, rating: FsrsRating.good, currentTime: now);
      c = fsrs.calculateNextState(card: c, rating: FsrsRating.good, currentTime: now + 3 * day);
      return fsrs.calculateNextState(card: c, rating: FsrsRating.good, currentTime: now + 9 * day);
    }

    test('Review + 认识 → 维持 Review，S 增长', () {
      final base = longLivedCard();
      final next = fsrs.calculateNextState(card: base, rating: FsrsRating.good, currentTime: now + 20 * day);
      expect(next.status, SrsStatus.review);
      expect(next.stability, greaterThan(base.stability));
      expect(next.failCount, 0);
    });

    test('Review + 模糊 → 维持 Review，S×0.86', () {
      final base = longLivedCard();
      final next = fsrs.calculateNextState(card: base, rating: FsrsRating.hard, currentTime: now + 20 * day);
      expect(next.status, SrsStatus.review);
      expect(next.stability, closeTo(base.stability * 0.86, 0.001));
    });

    test('Review + 不认识 → Relearning，failCount+1，S 衰减', () {
      final base = longLivedCard();
      // 隔 60 天（R 已跌破 60%）仍遗忘，才发生真正的 S 衰减。
      final next = fsrs.calculateNextState(card: base, rating: FsrsRating.again, currentTime: now + 60 * day);
      expect(next.status, SrsStatus.relearning);
      expect(next.failCount, 1);
      expect(next.stability, lessThan(base.stability));
    });
  });

  group('Relearning 状态流转', () {
    // 长期卡在 R 低点遗忘，得到 Relearning 卡。
    SrsCardState relearningCard() {
      var c = fsrs.createNewCard(now: now);
      c = fsrs.calculateNextState(card: c, rating: FsrsRating.good, currentTime: now);
      c = fsrs.calculateNextState(card: c, rating: FsrsRating.good, currentTime: now + 3 * day);
      c = fsrs.calculateNextState(card: c, rating: FsrsRating.good, currentTime: now + 9 * day);
      return fsrs.calculateNextState(card: c, rating: FsrsRating.again, currentTime: now + 60 * day);
    }

    test('12h 宽容窗口内 + 认识 → S×1.2 回到 Review', () {
      final base = relearningCard();
      final next = fsrs.calculateNextState(
        card: base,
        rating: FsrsRating.good,
        currentTime: now + 60 * day + 3600000, // 遗忘 1 小时后想起
        lastFailTime: now + 60 * day,
      );
      expect(next.status, SrsStatus.review);
      expect(next.stability, closeTo(base.stability * 1.2, 0.001));
    });

    test('窗口外 + 认识 → 按成功函数重算（非 1.2）', () {
      final base = relearningCard();
      final next = fsrs.calculateNextState(
        card: base,
        rating: FsrsRating.good,
        currentTime: now + 60 * day + 13 * 3600000, // 13 小时后
        lastFailTime: now + 60 * day,
      );
      expect(next.status, SrsStatus.review);
      expect(next.stability, isNot(closeTo(base.stability * 1.2, 0.001)));
    });

    test('Relearning + 不认识 → 维持，延后 5 分钟，S 二次衰减', () {
      final base = relearningCard();
      final next = fsrs.calculateNextState(card: base, rating: FsrsRating.again, currentTime: now + 60 * day);
      expect(next.status, SrsStatus.relearning);
      expect(next.nextReviewAt, now + 60 * day + 300000);
      expect(next.stability, lessThan(base.stability));
    });
  });

  group('间隔文案', () {
    test('formatNextReview', () {
      expect(fsrs.formatNextReview(now + 2 * day, now), '2天');
      expect(fsrs.formatNextReview(now + 5 * 3600000, now), '5h');
      expect(fsrs.formatNextReview(now + 10 * 60000, now), '10min');
      expect(fsrs.formatNextReview(now - 1000, now), '立即复习');
    });
  });

  group('S 下限钳制', () {
    test('衰减后 S 不为负', () {
      final base = newCard();
      final next = fsrs.calculateNextState(card: base, rating: FsrsRating.again, currentTime: now);
      expect(next.stability, greaterThanOrEqualTo(0.1));
    });
  });
}
