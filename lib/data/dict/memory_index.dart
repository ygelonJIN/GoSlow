import '../models/word_entry.dart';

/// 高亮引擎所需的内存索引（纯 Dart，不依赖数据库/Flutter）。
class DictMemoryIndex {
  const DictMemoryIndex({
    required this.words,
    required this.phrases,
    required this.lemmaMap,
  });

  /// 原型 → 词条（不含词组）。
  final Map<String, WordEntry> words;

  /// 词组（含空格）→ 词条，用于最长匹配优先。
  final Map<String, WordEntry> phrases;

  /// 变形 → 原型。
  final Map<String, String> lemmaMap;
}
