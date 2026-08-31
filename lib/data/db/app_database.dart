import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// 用户数据库：contents / word_states / word_queue / review_events / milestones。
/// 与只读词库 `dict.db` 分离，读写都在应用文档目录的 `app.db`。
class AppDatabase {
  AppDatabase._({this.opener});

  static final AppDatabase instance = AppDatabase._();

  /// 测试用：注入自定义打开逻辑（如 sqflite_common_ffi 内存库），
  /// 复用的 schema 见 [createSchema]。
  static AppDatabase testInstance(Future<Database> Function() opener) =>
      AppDatabase._(opener: opener);

  final Future<Database> Function()? opener;

  Database? _db;

  Future<Database> get database async {
    if (_db case final db?) return db;
    final db = await _open();
    _db = db;
    return db;
  }

  /// 建表脚本（V1-V7，ALTER 型迁移均幂等可重入），测试与运行时共用。
  static Future<void> createSchema(Database db) async {
    await _createV1(db);
    await _createV2(db);
    await _createV3(db);
    await _createV4(db);
    await _createV5(db);
    await _createV6(db);
    await _createV7(db);
  }

  /// 按旧版本号执行增量迁移（onUpgrade 与测试共用）。
  static Future<void> upgrade(Database db, int oldVersion) async {
    if (oldVersion < 2) await _createV2(db);
    if (oldVersion < 3) await _createV3(db);
    if (oldVersion < 4) await _createV4(db);
    if (oldVersion < 5) await _createV5(db);
    if (oldVersion < 6) await _createV6(db);
    if (oldVersion < 7) await _createV7(db);
  }

  Future<Database> _open() async {
    if (opener case final opener?) return opener();
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'app.db');
    final db = await openDatabase(
      dbPath,
      version: 7,
      onCreate: (db, _) => createSchema(db),
      onUpgrade: (db, oldVersion, _) => upgrade(db, oldVersion),
    );
    return db;
  }

  static Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contents (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        title      TEXT NOT NULL,
        body       TEXT NOT NULL,
        source_type TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_states (
        word          TEXT PRIMARY KEY,
        status        TEXT NOT NULL DEFAULT 'unknown',
        favorite      INTEGER NOT NULL DEFAULT 0,
        correct_count INTEGER NOT NULL DEFAULT 0,
        wrong_count   INTEGER NOT NULL DEFAULT 0,
        last_seen_at  INTEGER
      )
    ''');
  }

  static Future<void> _createV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_queue (
        word       TEXT PRIMARY KEY,
        added_at   INTEGER NOT NULL
      )
    ''');
  }

  /// M3：word_states 增加连续认识计数（闪卡掌握度状态机用）。
  static Future<void> _createV3(Database db) async {
    if (!await _hasColumn(db, 'word_states', 'consecutive_correct')) {
      await db.execute('''
        ALTER TABLE word_states
          ADD COLUMN consecutive_correct INTEGER NOT NULL DEFAULT 0
      ''');
    }
  }

  /// M3.5：FSRS 调度 + 事件溯源。
  ///
  /// 1. `word_states` 增加 SRS 字段（stability/difficulty/retrievability/
  ///    next_review_at/last_review_at/fail_count），调度从"连续计数"升级为
  ///    FSRS v4 间隔调度（见 `lib/data/srs/fsrs_calculator.dart`）。
  /// 2. 新增 `review_events` 事件表：每次自评落一条"操作前快照 + 操作后结果"，
  ///    供统计聚合（评级分布/掌握度曲线）与撤销（undo）使用，保证可追溯。
  /// 3. 存量数据回填：旧库里的 learning/familiar/known 卡无 SRS 字段，
  ///    统一按"立即到期"排期，让其在下一次闪卡中进入新调度。
  static Future<void> _createV4(Database db) async {
    if (!await _hasColumn(db, 'word_states', 'stability')) {
      await db.execute('''
        ALTER TABLE word_states
          ADD COLUMN stability       REAL NOT NULL DEFAULT 0
      ''');
    }
    if (!await _hasColumn(db, 'word_states', 'difficulty')) {
      await db.execute('''
        ALTER TABLE word_states
          ADD COLUMN difficulty      REAL NOT NULL DEFAULT 0
      ''');
    }
    if (!await _hasColumn(db, 'word_states', 'retrievability')) {
      await db.execute('''
        ALTER TABLE word_states
          ADD COLUMN retrievability  REAL NOT NULL DEFAULT 0
      ''');
    }
    if (!await _hasColumn(db, 'word_states', 'next_review_at')) {
      await db.execute('''
        ALTER TABLE word_states
          ADD COLUMN next_review_at  INTEGER
      ''');
    }
    if (!await _hasColumn(db, 'word_states', 'last_review_at')) {
      await db.execute('''
        ALTER TABLE word_states
          ADD COLUMN last_review_at  INTEGER
      ''');
    }
    if (!await _hasColumn(db, 'word_states', 'fail_count')) {
      await db.execute('''
        ALTER TABLE word_states
          ADD COLUMN fail_count      INTEGER NOT NULL DEFAULT 0
      ''');
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS review_events (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        word                TEXT NOT NULL,
        rating              INTEGER NOT NULL,   -- 1 again / 2 hard / 3 good / 4 easy
        created_at          INTEGER NOT NULL,   -- 自评时间（UTC 毫秒）

        pre_status          INTEGER NOT NULL,   -- 操作前 SRS 状态快照（撤销用）
        pre_stability       REAL NOT NULL,
        pre_difficulty      REAL NOT NULL,
        pre_retrievability  REAL NOT NULL,
        pre_next_review_at  INTEGER NOT NULL,

        post_status         INTEGER NOT NULL,   -- 操作后 SRS 状态
        post_stability      REAL NOT NULL,
        post_difficulty     REAL NOT NULL,
        post_retrievability REAL NOT NULL,
        post_next_review_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_review_events_word
        ON review_events(word, id)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_review_events_created
        ON review_events(created_at)
    ''');

    // 存量回填：已处理但无 SRS 字段的词按当前时间立即到期，
    // 保持旧掌握度标签（status 不变），并给 SRS 基线（S=1、D=5），
    // 避免旧数据以 stability=0 进入调度导致间隔异常。
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.execute('''
      UPDATE word_states
      SET next_review_at = COALESCE(next_review_at, COALESCE(last_seen_at, ?)),
          retrievability = 1.0,
          stability = CASE WHEN stability = 0 THEN 1.0 ELSE stability END,
          difficulty = CASE WHEN difficulty = 0 THEN 5.0 ELSE difficulty END
      WHERE status != 'unknown' AND next_review_at IS NULL
    ''', [now]);
  }

  /// M4：里程碑表（庆祝页用，记录已庆祝的里程碑，避免重复庆祝）。
  static Future<void> _createV5(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS milestones (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        kind        TEXT NOT NULL,
        threshold   INTEGER NOT NULL,
        achieved_at INTEGER NOT NULL,
        UNIQUE(kind, threshold)
      )
    ''');
  }

  /// M5：contents 增加结构化分节（JSON 字符串）。
  ///
  /// 旧内容（paste/txt/md）无分节；epub 分章节、srt/lrc 分时间轴行。
  /// 正文仍保留在 `body`（列表字数/阅读兜底用），分节用于阅读器的
  /// 章节导航 / 时间轴浏览。
  static Future<void> _createV6(Database db) async {
    if (!await _hasColumn(db, 'contents', 'sections')) {
      await db.execute('''
        ALTER TABLE contents
          ADD COLUMN sections TEXT
      ''');
    }
  }

  /// SQLite 无 `ADD COLUMN IF NOT EXISTS`，查 `PRAGMA table_info` 判断列是否已存在，
  /// 保证 ALTER 型迁移可重入（上次迁移中断后重跑不会报 duplicate column）。
  static Future<bool> _hasColumn(Database db, String table, String column) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.any((r) => r['name'] == column);
  }

  /// M6 预留 / 本次 M5 交互改版：contents 记录最近打开时间（最近阅读排序用）。
  static Future<void> _createV7(Database db) async {
    if (!await _hasColumn(db, 'contents', 'last_opened_at')) {
      await db.execute('''
        ALTER TABLE contents
          ADD COLUMN last_opened_at INTEGER
      ''');
    }
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
