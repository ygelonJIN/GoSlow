import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/word_entry.dart';
import 'dict_database.dart';
import 'highlight_engine.dart';
import 'memory_index.dart';

/// 词典访问层单例。
final dictDatabaseProvider = Provider<DictDatabase>((ref) {
  return DictDatabase.instance;
});

/// 内存索引（高亮引擎用），启动后一次性载入。
final memoryIndexProvider = FutureProvider<DictMemoryIndex>((ref) async {
  final db = ref.watch(dictDatabaseProvider);
  return db.loadMemoryIndex();
});

/// 高亮引擎（依赖内存索引载入后构造）。
final highlightEngineProvider = FutureProvider<HighlightEngine>((ref) async {
  final index = await ref.watch(memoryIndexProvider.future);
  return HighlightEngine(index);
});

/// 离线查词：
/// - 词形还原（got → get）
/// - 前缀联想（搜词框）
/// - 模糊搜索（记不清拼写时）
final lookupProvider = Provider<LookupService>((ref) {
  final db = ref.watch(dictDatabaseProvider);
  return LookupService(db);
});

class LookupService {
  LookupService(this._db);

  final DictDatabase _db;

  /// 精确 + 词形还原查词。
  Future<LookupResult?> lookup(String word) {
    return _db.lookupWithLemmatization(word);
  }

  /// 前缀联想。
  Future<List<WordEntry>> prefix(String q, {int limit = 20}) {
    return _db.searchPrefix(q, limit: limit);
  }

  /// 模糊搜索。
  Future<List<WordEntry>> contains(String q, {int limit = 50}) {
    return _db.searchContains(q, limit: limit);
  }
}

/// 当前考纲（全局多选）：可同时选中多个考纲；[kAllTag]（全部）互斥独占，
/// 一旦选中「全部」就忽略其他选择。默认全部。
final examTagProvider = StateProvider<Set<String>>((ref) => {kAllTag});

/// 高亮样式：
/// - 只选一个考纲 → 单色（该考纲自己的颜色）；
/// - 选多个考纲、或选「全部」 → 自动多色（每个考纲各用自己的颜色）。
///
/// 由 [examTagProvider] 派生，不再手动切换。
enum HighlightMode { single, multi }

final highlightModeProvider = Provider<HighlightMode>((ref) {
  final tags = ref.watch(examTagProvider);
  return tags.contains(kAllTag) || tags.length > 1
      ? HighlightMode.multi
      : HighlightMode.single;
});
