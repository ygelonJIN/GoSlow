/// FSRS v4 记忆调度引擎
///   1. 难度 D 持久化在卡片上并随评级演化（旧实现不存 D，只在公式里
///      临时重算，导致 `pow(D, -w12)` 对负数取幂产生 NaN）。
///   2. 成功稳定性用 FSRS-4 标准公式
///      `S' = S·(1 + e^w8·(11-D)·S^(-w9)·(e^(w10·(1-R)) − 1))`
///      （旧实现把 w9 误写成 w8，对 Good 评级会算出负 S，全部被钳到 0.1）。
///
/// 纯 Dart、无 Flutter/数据库依赖，可独立单测。
library;

import 'dart:math';

import '../models/srs_card_state.dart';

/// FSRS v4 17 维默认权重（FSRS v4 官方参数）。
class FsrsWeights {
  FsrsWeights._();

  static const List<double> defaultW = [
    0.4, 0.6, 2.4, 5.8, 4.93, 0.94, 0.86, 0.01,
    1.49, 0.14, 0.94, 2.18, 0.05, 0.34, 1.26, 0.29, 2.61,
  ];

  static const int w4 = 4; // D 初始化系数
  static const int w5 = 5; // D 初始化指数系数
  static const int w6 = 6; // Hard 后 S 缩放系数（≈0.86）与 D 演化步长
  static const int w7 = 7;
  static const int w8 = 8; // 成功函数系数
  static const int w9 = 9; // S 幂次
  static const int w10 = 10; // R 幂次
  static const int w11 = 11; // S_forget 系数
  static const int w12 = 12; // D 幂次
  static const int w13 = 13; // S 幂次
  static const int w14 = 14; // R 幂次
  static const int w15 = 15;
  static const int w16 = 16;
}

/// FSRS 计算器。
class FsrsCalculator {
  FsrsCalculator({List<double>? weights})
      : w = List.unmodifiable(weights ?? FsrsWeights.defaultW);

  final List<double> w;

  /// 可提取性衰减：R(t, S) = 1 / (1 + t / (9·S))，t 为距上次复习的天数。
  double retrievability(double t, double s) {
    if (s <= 0) return 0.0;
    return 1.0 / (1.0 + t / (9.0 * s));
  }

  /// 难度初始化：D0(G) = w4 - e^(w5·(G-1)) + 1，夹紧到 [1, 10]。
  double initialDifficulty(FsrsRating rating) {
    final g = rating.index + 1;
    return clampDifficulty(w[FsrsWeights.w4] - exp(w[FsrsWeights.w5] * (g - 1)) + 1.0);
  }

  double clampDifficulty(double d) => d.clamp(1.0, 10.0);

  /// 难度演化：D' = D - w6·(G-3)（Again 变难、Easy 变易、Good 不变）。
  double evolveDifficulty(double currentD, FsrsRating rating) {
    final d = currentD > 0 ? currentD : initialDifficulty(rating);
    return clampDifficulty(d - w[FsrsWeights.w6] * (rating.index + 1 - 3));
  }

  /// 遗忘稳定性：S_forget = w11 · D^(-w12) · S^(w13) · e^(w14·(1-R))。
  /// 忘记后 S 不是归零而是衰减，保留"曾经学会过"的记忆。
  double forgetStability({
    required double difficulty,
    required double stability,
    required double retrievability,
  }) {
    final dPow = pow(difficulty, -w[FsrsWeights.w12]);
    final sPow = pow(stability, w[FsrsWeights.w13]);
    final rExp = exp(w[FsrsWeights.w14] * (1.0 - retrievability));
    return w[FsrsWeights.w11] * dPow * sPow * rExp;
  }

  /// S 下限约束：任何涉及 S 的衰减后必须 S = max(S, 0.1)。
  double clampStability(double s) => max(s, 0.1);

  /// 下次复习时间 = current + S 天（毫秒）。
  int nextReviewDate(int currentTime, double s) {
    return currentTime + (s * 86400000).floor();
  }

  /// 从卡片当前状态 + 评级 + 当前时间计算下一状态。
  SrsCardState calculateNextState({
    required SrsCardState card,
    required FsrsRating rating,
    required int currentTime,
    int? lastFailTime,
  }) {
    // 距上次排期的天数（未来排期钳到 0 → R=1.0）。
    final t = max(0.0, (currentTime - card.nextReviewAt) / 86400000.0);
    final currentR = retrievability(t, card.stability);

    switch (card.status) {
      case SrsStatus.newCard:
        // 所有评级（1-4）→ Learning；S 按评级初始化，D 按评级初始化。
        // R 直接置 1.0：新卡"刚刚见过"，可提取性为满（S=0 算不出衰减）。
        final s = clampStability(w[rating.index]);
        return SrsCardState(
          status: SrsStatus.learning,
          stability: s,
          difficulty: initialDifficulty(rating),
          retrievability: 1.0,
          nextReviewAt: nextReviewDate(currentTime, s),
          lastReviewAt: card.lastReviewAt,
          failCount: card.failCount,
        );

      case SrsStatus.learning:
        if (rating == FsrsRating.good) {
          // Good → Review，S 用成功函数重算。
          final s = clampStability(
              _calculateSuccessStability(rating, card.stability, card.difficulty, currentR));
          return card.copyWith(
            status: SrsStatus.review,
            stability: s,
            difficulty: evolveDifficulty(card.difficulty, rating),
            retrievability: currentR,
            nextReviewAt: nextReviewDate(currentTime, s),
          );
        }
        if (rating == FsrsRating.again) {
          // Again → 维持 Learning，延后 5 分钟。
          return card.copyWith(
            status: SrsStatus.learning,
            difficulty: evolveDifficulty(card.difficulty, rating),
            retrievability: currentR,
            nextReviewAt: currentTime + 300000,
          );
        }
        // Hard / Easy 在 Learning 阶段不绑定额外业务逻辑，保持原状。
        return card.copyWith(retrievability: currentR);

      case SrsStatus.review:
        if (rating == FsrsRating.again) {
          // Again → Relearning，Fail_Count +1，S 执行 S_forget 衰减。
          final s = clampStability(forgetStability(
            difficulty: card.difficulty,
            stability: card.stability,
            retrievability: currentR,
          ));
          return card.copyWith(
            status: SrsStatus.relearning,
            stability: s,
            difficulty: evolveDifficulty(card.difficulty, rating),
            retrievability: currentR,
            nextReviewAt: nextReviewDate(currentTime, s),
            failCount: card.failCount + 1,
          );
        }
        if (rating == FsrsRating.hard) {
          final s = clampStability(_calculateHardStability(card.stability));
          return card.copyWith(
            status: SrsStatus.review,
            stability: s,
            difficulty: evolveDifficulty(card.difficulty, rating),
            retrievability: currentR,
            nextReviewAt: nextReviewDate(currentTime, s),
          );
        }
        // Good / Easy → 维持 Review，Fail_Count 重置为 0。
        final s = clampStability(_calculateSuccessStability(
            rating, card.stability, card.difficulty, currentR));
        return card.copyWith(
          status: SrsStatus.review,
          stability: s,
          difficulty: evolveDifficulty(card.difficulty, rating),
          retrievability: currentR,
          nextReviewAt: nextReviewDate(currentTime, s),
          failCount: 0,
        );

      case SrsStatus.relearning:
        if (rating == FsrsRating.good) {
          // Good → Review。12 小时宽容窗口内（忘记后很快想起）直接 S×1.2，
          // 否则按成功函数重算——临门一脚想起比完全重背对记忆更友好。
          final inWindow = lastFailTime != null &&
              withinForgivenessWindow(lastFailTime, currentTime);
          final s = inWindow
              ? clampStability(min(card.stability * 1.2, 100.0))
              : clampStability(_calculateSuccessStability(
                  rating, card.stability, card.difficulty, currentR));
          return card.copyWith(
            status: SrsStatus.review,
            stability: s,
            difficulty: evolveDifficulty(card.difficulty, rating),
            retrievability: currentR,
            nextReviewAt: nextReviewDate(currentTime, s),
          );
        }
        if (rating == FsrsRating.again) {
          // Again → 维持 Relearning，延后 5 分钟，S 二次深度衰减。
          final s = clampStability(forgetStability(
            difficulty: card.difficulty,
            stability: forgetStability(
              difficulty: card.difficulty,
              stability: card.stability,
              retrievability: currentR,
            ),
            retrievability: currentR,
          ));
          return card.copyWith(
            status: SrsStatus.relearning,
            stability: s,
            difficulty: evolveDifficulty(card.difficulty, rating),
            retrievability: currentR,
            nextReviewAt: currentTime + 300000,
          );
        }
        // Hard / Easy 在 Relearning 阶段：维持现状，仅延后 5 分钟便于立即再见。
        return card.copyWith(
          status: SrsStatus.relearning,
          retrievability: currentR,
          nextReviewAt: currentTime + 300000,
        );
    }
  }

  /// Relearning 后 12 小时内成功视为"宽容窗口"。
  bool withinForgivenessWindow(int lastFailTime, int currentTime) {
    return (currentTime - lastFailTime) < 12 * 60 * 60 * 1000;
  }

  /// 成功评级（Good/Easy）的 S 更新（FSRS-4 标准公式）：
  ///
  /// S' = S·(1 + e^w8·(11-D)·S^(-w9)·(e^(w10·(1-R)) − 1))；Easy 再 ×1.3。
  /// 注意：R=1.0（刚复习完）时 S 不变，只有等 R 衰减后再答对 S 才增长。
  double _calculateSuccessStability(
      FsrsRating rating, double currentS, double currentD, double currentR) {
    if (rating == FsrsRating.easy) {
      return clampStability(currentS * 1.3);
    }
    final d = currentD > 0 ? currentD : initialDifficulty(rating);
    final sPow = pow(currentS, -w[FsrsWeights.w9]);
    final rGain = exp(w[FsrsWeights.w10] * (1.0 - currentR)) - 1.0;
    final grow = exp(w[FsrsWeights.w8]) * (11.0 - d) * sPow * rGain;
    return clampStability(currentS * (1.0 + grow));
  }

  /// Hard 评级：S × w6（≈0.86）。
  double _calculateHardStability(double currentS) {
    return clampStability(currentS * w[FsrsWeights.w6]);
  }

  /// 全新卡（首次进入闪卡）的初始 SRS 状态。
  SrsCardState createNewCard({required int now}) {
    return SrsCardState(
      status: SrsStatus.newCard,
      stability: 0.0,
      difficulty: 0.0,
      retrievability: 1.0,
      nextReviewAt: now,
      lastReviewAt: 0,
      failCount: 0,
    );
  }

  /// 下次复习时间的人类可读文案（中文）。
  String formatNextReview(int nextReviewAt, int now) {
    final diff = nextReviewAt - now;
    if (diff <= 0) return '立即复习';
    final days = diff ~/ (24 * 60 * 60 * 1000);
    final hours = (diff % (24 * 60 * 60 * 1000)) ~/ (60 * 60 * 1000);
    final minutes = (diff % (60 * 60 * 1000)) ~/ (60 * 1000);
    if (days > 0) return '$days天${hours > 0 ? '${hours}h' : ''}';
    if (hours > 0) return '${hours}h${minutes > 0 ? '${minutes}min' : ''}';
    return '${minutes}min';
  }
}
