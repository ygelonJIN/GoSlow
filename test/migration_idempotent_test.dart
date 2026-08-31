import 'package:goslow/data/db/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  });

  tearDown(() => db.close());

  Future<List<String>> columnsOf(String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.map((r) => r['name'] as String).toList();
  }

  /// 建一份"老用户"库：用原始 SQL 精确构造到指定版本的 schema
  /// （不能复用 upgrade()，因为它的守卫是 `oldVersion < N`，一次会跑完全部迁移）。
  Future<void> createOldSchema({required int version}) async {
    await db.execute('''
      CREATE TABLE contents (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        title       TEXT NOT NULL,
        body        TEXT NOT NULL,
        source_type TEXT NOT NULL,
        created_at  INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE word_states (
        word          TEXT PRIMARY KEY,
        status        TEXT NOT NULL DEFAULT 'unknown',
        favorite      INTEGER NOT NULL DEFAULT 0,
        correct_count INTEGER NOT NULL DEFAULT 0,
        wrong_count   INTEGER NOT NULL DEFAULT 0,
        last_seen_at  INTEGER
      )
    ''');
    if (version >= 3) {
      await db.execute('ALTER TABLE word_states ADD COLUMN consecutive_correct INTEGER NOT NULL DEFAULT 0');
    }
    if (version >= 4) {
      await db.execute('ALTER TABLE word_states ADD COLUMN stability REAL NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE word_states ADD COLUMN difficulty REAL NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE word_states ADD COLUMN retrievability REAL NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE word_states ADD COLUMN next_review_at INTEGER');
      await db.execute('ALTER TABLE word_states ADD COLUMN last_review_at INTEGER');
      await db.execute('ALTER TABLE word_states ADD COLUMN fail_count INTEGER NOT NULL DEFAULT 0');
      await db.execute('''
        CREATE TABLE review_events (
          id                  INTEGER PRIMARY KEY AUTOINCREMENT,
          word                TEXT NOT NULL,
          rating              INTEGER NOT NULL,
          created_at          INTEGER NOT NULL,
          pre_status          INTEGER NOT NULL,
          pre_stability       REAL NOT NULL,
          pre_difficulty      REAL NOT NULL,
          pre_retrievability  REAL NOT NULL,
          pre_next_review_at  INTEGER NOT NULL,
          post_status         INTEGER NOT NULL,
          post_stability      REAL NOT NULL,
          post_difficulty     REAL NOT NULL,
          post_retrievability REAL NOT NULL,
          post_next_review_at INTEGER NOT NULL
        )
      ''');
    }
    if (version >= 5) {
      await db.execute('''
        CREATE TABLE milestones (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          kind        TEXT NOT NULL,
          threshold   INTEGER NOT NULL,
          achieved_at INTEGER NOT NULL,
          UNIQUE(kind, threshold)
        )
      ''');
    }
    if (version >= 6) {
      await db.execute('ALTER TABLE contents ADD COLUMN sections TEXT');
    }
  }

  group('迁移幂等性（duplicate column / missing column 回归）', () {
    test('createSchema 重复执行不报 duplicate column', () async {
      await AppDatabase.createSchema(db);
      // 模拟上次迁移在"加列成功、版本号提交前"崩溃后重跑：
      // V3/V4/V6/V7 的 ALTER 都必须可重入。
      await AppDatabase.createSchema(db);
      await AppDatabase.createSchema(db);
    });

    test('V4 半途中断（只加了部分列）后重跑安全', () async {
      await db.execute('''
        CREATE TABLE contents (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          title       TEXT NOT NULL,
          body        TEXT NOT NULL,
          source_type TEXT NOT NULL,
          created_at  INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE word_states (
          word          TEXT PRIMARY KEY,
          status        TEXT NOT NULL DEFAULT 'unknown',
          favorite      INTEGER NOT NULL DEFAULT 0,
          correct_count INTEGER NOT NULL DEFAULT 0,
          wrong_count   INTEGER NOT NULL DEFAULT 0,
          last_seen_at  INTEGER
        )
      ''');
      await db.execute('ALTER TABLE word_states ADD COLUMN stability REAL NOT NULL DEFAULT 0');

      // 重跑全量建表：缺的列补上，已有的列跳过。
      await AppDatabase.createSchema(db);

      expect(await columnsOf('word_states'), containsAll([
        'stability',
        'difficulty',
        'retrievability',
        'next_review_at',
        'last_review_at',
        'fail_count',
        'consecutive_correct',
      ]));
      expect(await columnsOf('contents'), contains('sections'));
      expect(await columnsOf('contents'), contains('last_opened_at'));
    });

    test('V5 存量库升级到 V7：sections 已存在、last_opened_at 缺失（no such column 回归）', () async {
      // 复现用户报错现场：库停在 V5，且因上次半途迁移 sections 列已存在，
      // 但 last_opened_at 没有（V7 从未执行）。
      await createOldSchema(version: 5);
      await db.execute('ALTER TABLE contents ADD COLUMN sections TEXT');
      expect(await columnsOf('contents'), contains('sections'));
      expect(await columnsOf('contents'), isNot(contains('last_opened_at')));

      // 模拟 AppDatabase._open 在 version: 7 下对 oldVersion=5 触发 onUpgrade。
      await AppDatabase.upgrade(db, 5);

      expect(await columnsOf('contents'), contains('last_opened_at'));
      expect(await columnsOf('contents'), contains('sections'));
      // 幂等：再跑一次不报 duplicate。
      await AppDatabase.upgrade(db, 5);
      expect(await columnsOf('contents'), contains('last_opened_at'));
    });

    test('V6 存量库升级到 V7：只补 last_opened_at', () async {
      await createOldSchema(version: 6);
      expect(await columnsOf('contents'), contains('sections'));
      expect(await columnsOf('contents'), isNot(contains('last_opened_at')));

      await AppDatabase.upgrade(db, 6);
      expect(await columnsOf('contents'), contains('last_opened_at'));
    });

    test('升级后 listAll 的排序 SQL 可直接执行（COALESCE last_opened_at）', () async {
      await createOldSchema(version: 5);
      await AppDatabase.upgrade(db, 5);

      await db.insert('contents', {
        'title': 'A',
        'body': 'a',
        'source_type': 'paste',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      final rows = await db.query(
        'contents',
        orderBy: 'COALESCE(last_opened_at, created_at) DESC, created_at DESC, id DESC',
      );
      expect(rows.length, 1);
    });
  });
}
