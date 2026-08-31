import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/milestone.dart';

/// 里程碑仓储（M4 庆祝）：记录已庆祝的里程碑、检测新达成的里程碑。
class MilestoneRepository {
  MilestoneRepository(this._db);

  final AppDatabase _db;

  /// 全部已庆祝里程碑（按达成时间正序）。
  Future<List<Milestone>> achieved() async {
    final db = await _db.database;
    final rows = await db.query('milestones', orderBy: 'achieved_at ASC');
    return rows.map(Milestone.fromRow).toList();
  }

  /// 已庆祝的认识词数阈值集合。
  Future<Set<int>> achievedKnownWordThresholds() async {
    final db = await _db.database;
    final rows = await db.query(
      'milestones',
      columns: ['threshold'],
      where: 'kind = ?',
      whereArgs: [Milestone.kindKnownWords],
    );
    return {for (final r in rows) (r['threshold'] as int?) ?? 0};
  }

  /// 标记里程碑已庆祝（幂等：kind+threshold 唯一）。
  Future<void> markAchieved({
    String kind = Milestone.kindKnownWords,
    required int threshold,
    int? at,
  }) async {
    final db = await _db.database;
    await db.insert(
      'milestones',
      Milestone(
        kind: kind,
        threshold: threshold,
        achievedAt: DateTime.fromMillisecondsSinceEpoch(
          at ?? DateTime.now().millisecondsSinceEpoch,
        ),
      ).toRow(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 检测新达成的认识词数里程碑（达标且未庆祝，升序）。
  Future<List<int>> pendingKnownWordMilestones(int knownCount) async {
    final achieved = await achievedKnownWordThresholds();
    return newlyReachedKnownWordMilestones(
      knownCount: knownCount,
      achieved: achieved,
    );
  }
}
