import 'dart:math';

import '../models/word_entry.dart';
import 'memory_index.dart';

/// 考纲词排序方式。
enum SyllabusOrder { frq, alpha, random }

/// 从内存索引中筛出当前考纲的词条。
///
/// [examTag] 为 `kAllTag`（全部）时返回所有带考纲标签的词条。
List<WordEntry> syllabusWordsFor(DictMemoryIndex index, String examTag) {
  return index.words.values
      .where((e) => examTag == kAllTag ? e.tags.isNotEmpty : e.tags.contains(examTag))
      .toList();
}

/// 按用户选择的顺序对新词排序（候选词池）。
List<WordEntry> sortSyllabus(List<WordEntry> words, SyllabusOrder order, {Random? random}) {
  switch (order) {
    case SyllabusOrder.frq:
      // ECDICT frq 为词频排名，数值越小越高频 → 升序即高频优先。
      return [...words]..sort((a, b) => a.frq.compareTo(b.frq));
    case SyllabusOrder.alpha:
      return [...words]..sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
    case SyllabusOrder.random:
      return [...words]..shuffle(random ?? Random());
  }
}

/// 组装一轮牌堆：先复习（familiar/learning 且见过），再补候选新词。
///
/// - [reviewQueue]：复习池，已按 last_seen 升序（调用方保证）。
/// - [candidateNew]：候选新词，已按用户偏好排序（调用方保证）。
/// - [knownWords]：已认识的词，跳过。
/// - 结果最多 [sessionSize] 个。
List<String> assembleDeck({
  required List<String> reviewQueue,
  required List<String> candidateNew,
  required Set<String> knownWords,
  required int sessionSize,
}) {
  final deck = <String>[];
  final seen = <String>{};

  for (final w in reviewQueue) {
    if (deck.length >= sessionSize) break;
    if (knownWords.contains(w) || seen.contains(w)) continue;
    deck.add(w);
    seen.add(w);
  }
  for (final w in candidateNew) {
    if (deck.length >= sessionSize) break;
    if (knownWords.contains(w) || seen.contains(w)) continue;
    deck.add(w);
    seen.add(w);
  }
  return deck;
}
