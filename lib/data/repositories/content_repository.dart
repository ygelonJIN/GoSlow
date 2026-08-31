import '../db/app_database.dart';
import '../models/content_entry.dart';
import '../parsers/parsed_content.dart';

/// 内容仓储：粘贴/导入的文本存取。
class ContentRepository {
  ContentRepository(this._db);

  final AppDatabase _db;

  Future<int> insert({
    required String title,
    required String body,
    required String sourceType,
    List<ContentSection> sections = const [],
  }) async {
    final db = await _db.database;
    final trimmed = body.trim();
    final resolvedTitle = title.trim().isEmpty
        ? (trimmed.isEmpty ? '空内容' : _deriveTitle(trimmed))
        : title.trim();
    return db.insert('contents', {
      'title': resolvedTitle,
      'body': body,
      'source_type': sourceType,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'sections': encodeSections(sections),
    });
  }

  Future<List<ContentEntry>> listAll() async {
    final db = await _db.database;
    // 最近阅读优先：有打开记录的按最近打开时间倒序，未打开的回退到导入时间；
    // 时间戳同毫秒时按 id 倒序兜底，保证顺序稳定。
    final rows = await db.query(
      'contents',
      orderBy: 'COALESCE(last_opened_at, created_at) DESC, created_at DESC, id DESC',
    );
    return rows.map(ContentEntry.fromRow).toList();
  }

  /// 记录一次打开（最近阅读排序用）。
  Future<void> touchOpened(int id) async {
    final db = await _db.database;
    await db.update(
      'contents',
      {'last_opened_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<ContentEntry?> byId(int id) async {
    final db = await _db.database;
    final rows = await db.query('contents', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return ContentEntry.fromRow(rows.first);
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete('contents', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> update(int id, {required String title, required String body}) async {
    final db = await _db.database;
    return db.update(
      'contents',
      {'title': title.trim(), 'body': body},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static String _deriveTitle(String body) {
    final firstLine = body.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => body);
    final t = firstLine.trim();
    if (t.length <= 28) return t;
    return '${t.substring(0, 28)}…';
  }
}
