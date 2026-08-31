import 'package:goslow/data/db/app_database.dart';
import 'package:goslow/data/models/milestone.dart';
import 'package:goslow/data/repositories/milestone_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late AppDatabase appDb;
  late MilestoneRepository repo;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await AppDatabase.createSchema(db);
    appDb = AppDatabase.testInstance(() async => db);
    repo = MilestoneRepository(appDb);
  });

  tearDown(() => db.close());

  group('newlyReachedKnownWordMilestones 纯函数', () {
    test('未达标不返回', () {
      expect(
        newlyReachedKnownWordMilestones(knownCount: 99, achieved: const {}),
        isEmpty,
      );
    });

    test('达标且未庆祝 → 返回该阈值', () {
      expect(
        newlyReachedKnownWordMilestones(knownCount: 100, achieved: const {}),
        [100],
      );
    });

    test('跨越多档 → 返回全部未庆祝档（升序）', () {
      expect(
        newlyReachedKnownWordMilestones(knownCount: 1200, achieved: const {}),
        [100, 500, 1000],
      );
    });

    test('已庆祝的档不再返回（每档只庆祝一次）', () {
      expect(
        newlyReachedKnownWordMilestones(
          knownCount: 1200,
          achieved: const {100, 500},
        ),
        [1000],
      );
    });

    test('全档达成后不返回', () {
      expect(
        newlyReachedKnownWordMilestones(
          knownCount: 6000,
          achieved: {100, 500, 1000, 2000, 3000, 5000},
        ),
        isEmpty,
      );
    });
  });

  group('MilestoneRepository', () {
    test('markAchieved 幂等 + achieved 返回正序', () async {
      final t1 = DateTime.now().millisecondsSinceEpoch;
      await repo.markAchieved(threshold: 100, at: t1);
      await repo.markAchieved(threshold: 100, at: t1); // 重复标记不报错、不重复
      await repo.markAchieved(threshold: 500, at: t1 + 1000);

      final achieved = await repo.achieved();
      expect(achieved.length, 2);
      expect(achieved[0].threshold, 100);
      expect(achieved[1].threshold, 500);
      expect(achieved[0].kind, Milestone.kindKnownWords);
    });

    test('pendingKnownWordMilestones 结合已庆祝记录', () async {
      await repo.markAchieved(threshold: 100);

      final pending = await repo.pendingKnownWordMilestones(1200);
      expect(pending, [500, 1000]); // 100 已庆祝，跳过
    });

    test('里程碑与 word_states 互不干扰（独立表）', () async {
      await repo.markAchieved(threshold: 100);
      // 空 word_states 也能正常查询里程碑。
      expect((await repo.achieved()).length, 1);
      expect(await repo.pendingKnownWordMilestones(0), isEmpty);
    });
  });
}
