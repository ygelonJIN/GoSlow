import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/word_entry.dart';
import 'memory_index.dart';

/// 词典访问层：管理 assets/dict.db 的首次拷贝与 SQLite 查询。
///
/// - 词库是只读数据，首次启动从 assets 复制到应用文档目录后打开。
/// - 查询均走精确匹配 + 索引；词形还原见 [lemmatize]。
/// - 词库打开后同时构建内存索引（见 [loadMemoryIndex]），供高亮引擎使用。
class DictDatabase {
  DictDatabase._();

  static final DictDatabase instance = DictDatabase._();

  Database? _db;

  bool get isOpen => _db != null;

  /// 返回打开的数据库；首次调用会先确保词库文件已就位。
  Future<Database> get database async {
    if (_db case final db?) return db;
    final db = await _open();
    _db = db;
    return db;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'dict.db');

    if (!File(dbPath).existsSync()) {
      final data = await rootBundle.load('assets/dict.db');
      await File(dbPath).writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }

    final db = await openDatabase(
      dbPath,
      readOnly: true,
      options: OpenDatabaseOptions(version: 1),
    );
    return db;
  }

  /// 精确查词：直接命中 words 表。
  Future<WordEntry?> lookup(String word) async {
    final db = await database;
    final rows = await db.query(
      'words',
      where: 'word = ?',
      whereArgs: [word.toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WordEntry.fromRow(rows.first)..tags = await _tagsOf(db, rows.first['id'] as int);
  }

  /// 词形还原查词：got → get。
  ///
  /// 先尝试 lemma_map 精确映射，再尝试按大小写/去掉尾标点容错。
  Future<WordEntry?> lookupInflected(String inflected) async {
    final db = await database;
    final key = inflected.toLowerCase().trim();
    if (key.isEmpty) return null;

    final rows = await db.query(
      'lemma_map',
      columns: ['lemma'],
      where: 'inflected = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final lemma = rows.first['lemma'] as String;
    return lookup(lemma);
  }

  /// 通用查词：先精确，再词形还原。返回匹配的词条及命中方式。
  Future<LookupResult?> lookupWithLemmatization(String word) async {
    final direct = await lookup(word);
    if (direct != null) {
      return LookupResult(entry: direct, matched: word.toLowerCase());
    }
    final lemmatized = await lookupInflected(word);
    if (lemmatized != null) {
      return LookupResult(entry: lemmatized, matched: word.toLowerCase());
    }
    return null;
  }

  /// 前缀搜索（用于查词框联想）；[limit] 控制返回条数。
  Future<List<WordEntry>> searchPrefix(String prefix, {int limit = 20}) async {
    final db = await database;
    final rows = await db.query(
      'words',
      where: 'word LIKE ?',
      whereArgs: ['${prefix.toLowerCase()}%'],
      orderBy: 'frq DESC, word ASC',
      limit: limit,
    );
    final result = <WordEntry>[];
    for (final row in rows) {
      final entry = WordEntry.fromRow(row);
      if (!entry.hasMeaning) continue;
      entry.tags = await _tagsOf(db, row['id'] as int);
      result.add(entry);
    }
    return result;
  }

  /// 模糊搜索（词中包含关键字，用于"记不清完整拼写"）。
  Future<List<WordEntry>> searchContains(String keyword, {int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      'words',
      where: 'word LIKE ? AND word NOT LIKE ?',
      whereArgs: ['%${keyword.toLowerCase()}%', '${keyword.toLowerCase()}%'],
      orderBy: 'frq DESC, word ASC',
      limit: limit,
    );
    final result = <WordEntry>[];
    for (final row in rows) {
      final entry = WordEntry.fromRow(row);
      if (!entry.hasMeaning) continue;
      entry.tags = await _tagsOf(db, row['id'] as int);
      result.add(entry);
    }
    return result;
  }

  Future<List<String>> _tagsOf(Database db, int wordId) async {
    final rows = await db.query(
      'word_tags',
      columns: ['tag'],
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
    return rows.map((r) => r['tag'] as String).toList();
  }

  // ---------------------------------------------------------------------
  // 内存索引：高亮引擎用
  // ---------------------------------------------------------------------

  /// 载入内存索引：words（原型 → 词条）+ lemma_map（变形 → 原型）。
  ///
  /// 只保留有释义的词条；词组词条（含空格）单独归入 [phrases]，供最长匹配。
  Future<DictMemoryIndex> loadMemoryIndex() async {
    final db = await database;

    final wordRows = await db.query('words');
    final tagRows = await db.query('word_tags');
    final tagMap = <int, List<String>>{};
    for (final r in tagRows) {
      final wid = r['word_id'] as int;
      final tag = r['tag'] as String;
      (tagMap[wid] ??= []).add(tag);
    }

    final words = <String, WordEntry>{};
    final phrases = <String, WordEntry>{};
    for (final row in wordRows) {
      final entry = WordEntry.fromRow(row);
      if (!entry.hasMeaning) continue;
      entry.tags = tagMap[entry.id] ?? const [];
      if (entry.word.contains(' ')) {
        phrases[entry.word.toLowerCase()] = entry;
      } else {
        words[entry.word.toLowerCase()] = entry;
      }
    }

    final lemmaRows = await db.query('lemma_map');
    final lemmaMap = <String, String>{
      for (final r in lemmaRows)
        (r['inflected'] as String).toLowerCase(): (r['lemma'] as String).toLowerCase(),
    };

    return DictMemoryIndex(
      words: words,
      phrases: phrases,
      lemmaMap: lemmaMap,
    );
  }
}

/// 查词命中结果：词条 + 实际命中的拼写（可能是原形也可能是变形）。
class LookupResult {
  const LookupResult({required this.entry, required this.matched});

  final WordEntry entry;

  /// 输入中被命中的词形（如 got）。
  final String matched;
}
