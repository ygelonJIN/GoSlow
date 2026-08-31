import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../dict/syllabus.dart';
import '../models/review_event.dart';
import '../models/review_outcome.dart';
import '../models/srs_card_state.dart';
import '../models/word_state.dart';
import '../srs/fsrs_calculator.dart';

/// 单词状态仓储：已认识 / 收藏 / 队列 / 闪卡掌握度（FSRS 调度 + 事件溯源）。
class WordStateRepository {
  WordStateRepository(this._db, {FsrsCalculator? fsrs})
      : _fsrs = fsrs ?? FsrsCalculator();

  final AppDatabase _db;
  final FsrsCalculator _fsrs;

  Future<Map<String, WordState>> loadAll() async {
    final db = await _db.database;
    final rows = await db.query('word_states');
    return {for (final r in rows) (r['word'] as String): WordState.fromRow(r)};
  }

  Future<WordState?> byWord(String word) async {
    final db = await _db.database;
    final key = word.toLowerCase();
    final rows = await db.query('word_states', where: 'word = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return WordState.fromRow(rows.first);
  }

  Future<void> upsert(WordState state) async {
    final db = await _db.database;
    await db.insert(
      'word_states',
      state.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markKnown(String word) async {
    final key = word.toLowerCase();
    final now = DateTime.now().millisecondsSinceEpoch;
    final prev = await byWord(key);
    // 标记已认识：给一个温和的 SRS 基线，7 天后做一次低频抽查
    //（对应文档"known 只做低频抽查"）。
    final next = (prev ?? WordState(word: key)).copyWith(
      status: WordStatus.known,
      stability: 1.0,
      difficulty: 0.0,
      retrievability: 1.0,
      nextReviewAt: now + 7 * 86400000,
      lastReviewAt: now,
      lastSeenAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
    await upsert(next);
  }

  /// 闪卡自评：三档 → FSRS 评级 → 状态推进 + 落一条 [ReviewEvent] 事件。
  ///
  /// 事件携带操作前快照，统计与撤销都以事件为唯一数据源。
  /// 返回 [ReviewOutcome]（操作前/后状态对），供 Result 结算页计算
  /// 会话级指标（平均 S/R 变化、新学/复习/重学分组）。
  Future<ReviewOutcome> recordFlashcardReview(
    String word,
    SelfRating rating, {
    int? now,
  }) async {
    final timestamp = now ?? DateTime.now().millisecondsSinceEpoch;
    final key = word.toLowerCase();
    final prev = await byWord(key);
    final base = prev ?? WordState(word: key);

    final lastFail = await lastFailTimeOf(key);
    final next = base.applyReview(
      rating: rating.toFsrs,
      now: timestamp,
      fsrs: _fsrs,
      lastFailTime: lastFail,
    );

    final pre = base.toSrs(now: timestamp, fsrs: _fsrs);
    final post = next.toSrs(now: timestamp, fsrs: _fsrs);

    final db = await _db.database;
    await db.insert(
      'review_events',
      ReviewEvent(
        word: key,
        rating: rating.toFsrs,
        createdAt: timestamp,
        preStatus: pre.status,
        preStability: pre.stability,
        preDifficulty: pre.difficulty,
        preRetrievability: pre.retrievability,
        preNextReviewAt: pre.nextReviewAt,
        postStatus: post.status,
        postStability: post.stability,
        postDifficulty: post.difficulty,
        postRetrievability: post.retrievability,
        postNextReviewAt: post.nextReviewAt,
      ).toRow(),
    );

    await upsert(next);
    return ReviewOutcome(word: key, pre: base, post: next);
  }

  /// 撤销最后一次自评：用事件里的操作前快照恢复该词状态并删除事件。
  ///
  /// 返回撤销后的状态；无事件可撤销时返回 null。
  Future<WordState?> undoLatestReview() async {
    final db = await _db.database;
    final rows = await db.query(
      'review_events',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final event = ReviewEvent.fromRow(rows.first);
    final prev = await byWord(event.word);
    final base = prev ?? WordState(word: event.word);

    final restored = base.copyWith(
      status: event.preStatus.toWordStatus,
      stability: event.preStability,
      difficulty: event.preDifficulty,
      retrievability: event.preRetrievability,
      nextReviewAt: event.preNextReviewAt,
      lastReviewAt: base.lastSeenAt?.millisecondsSinceEpoch ?? 0,
    );

    await db.delete('review_events', where: 'id = ?', whereArgs: [event.id]);
    await upsert(restored);
    return restored;
  }

  /// 最近一次"不认识"（Again）的时间戳，供 Relearning 宽容窗口判断。
  Future<int?> lastFailTimeOf(String word) async {
    final db = await _db.database;
    final rows = await db.query(
      'review_events',
      columns: ['created_at'],
      where: 'word = ? AND rating = ?',
      whereArgs: [word.toLowerCase(), FsrsRating.again.dbValue],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['created_at'] as int;
  }

  /// 该词的完整自评历史（按时间正序）。
  Future<List<ReviewEvent>> reviewHistoryOf(String word) async {
    final db = await _db.database;
    final rows = await db.query(
      'review_events',
      where: 'word = ?',
      whereArgs: [word.toLowerCase()],
      orderBy: 'id ASC',
    );
    return rows.map(ReviewEvent.fromRow).toList();
  }

  /// 组装一轮闪卡：先复习（FSRS 到期卡），再补新词。
  ///
  /// [candidateNew] 提供候选新词（按调用方偏好排序，如考纲词）；为空时
  /// 回退到 word_queue（内容模式）。
  ///
  /// known 词的语义随 FSRS 变化：已认识但**已到期**的词仍进入复习池
  ///（低频抽查），未到期的 known 才跳过。
  Future<List<String>> flashcardDeck({
    int sessionSize = 10,
    List<String>? candidateNew,
    int? now,
    bool reviewOnly = false,
  }) async {
    final db = await _db.database;
    final timestamp = now ?? DateTime.now().millisecondsSinceEpoch;
    final review = await reviewQueue(now: timestamp);
    final dueSet = review.toSet();
    final knownSet = (await _knownSet(db))..removeAll(dueSet);
    final fresh = candidateNew ?? await _queueWords(db);
    return assembleDeck(
      reviewQueue: review,
      candidateNew: reviewOnly ? const [] : fresh,
      knownWords: knownSet,
      sessionSize: sessionSize,
    );
  }

  Future<List<String>> _queueWords(Database db) async {
    final rows = await db.query('word_queue', orderBy: 'added_at ASC');
    return [for (final r in rows) r['word'] as String];
  }

  Future<Set<String>> _knownSet(Database db) async {
    final rows = await db.query(
      'word_states',
      columns: ['word'],
      where: 'status = ?',
      whereArgs: [WordStatus.known.dbValue],
    );
    return {for (final r in rows) r['word'] as String};
  }

  /// FSRS 到期复习池：已排期且 `next_review_at <= now` 的词，
  /// 按到期时间升序（逾期最久的最先复习）。
  Future<List<String>> reviewQueue({int? now}) async {
    final db = await _db.database;
    final timestamp = now ?? DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'word_states',
      where: 'next_review_at IS NOT NULL AND next_review_at <= ?',
      whereArgs: [timestamp],
      orderBy: 'next_review_at ASC, last_seen_at ASC',
    );
    return [for (final r in rows) r['word'] as String];
  }

  Future<void> toggleFavorite(String word) async {
    final key = word.toLowerCase();
    final prev = await byWord(key);
    final next = (prev ?? WordState(word: key)).copyWith(
      favorite: !(prev?.favorite ?? false),
      lastSeenAt: DateTime.now(),
    );
    await upsert(next);
  }

  Future<bool> isFavorite(String word) async {
    final s = await byWord(word);
    return s?.favorite ?? false;
  }

  /// 队列：加入学习。
  Future<void> enqueue(String word) async {
    final db = await _db.database;
    await db.insert(
      'word_queue',
      {'word': word.toLowerCase(), 'added_at': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<String>> queueAll() async {
    final db = await _db.database;
    final rows = await db.query('word_queue', orderBy: 'added_at ASC');
    return rows.map((r) => r['word'] as String).toList();
  }

  Future<bool> isQueued(String word) async {
    final db = await _db.database;
    final rows = await db.query('word_queue', where: 'word = ?', whereArgs: [word.toLowerCase()], limit: 1);
    return rows.isNotEmpty;
  }

  Future<int> queueCount() async {
    final db = await _db.database;
    final rows = await db.rawQuery('SELECT COUNT(*) as c FROM word_queue');
    return (rows.first['c'] as int?) ?? 0;
  }
}
