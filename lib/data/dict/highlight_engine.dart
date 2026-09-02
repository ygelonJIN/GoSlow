import '../models/word_entry.dart';
import 'memory_index.dart';

/// 文本中的一个高亮区间。
class HighlightSpan {
  const HighlightSpan({
    required this.start,
    required this.end,
    required this.word,
    required this.entry,
  });

  /// 在原文中的起始偏移（字符数）。
  final int start;

  /// 在原文中的结束偏移（字符数，不包含）。
  final int end;

  /// 原文中实际高亮的词形（可能为变形，如 got）。
  final String word;

  /// 命中的词条（原型）。
  final WordEntry entry;
}

/// 分词结果片段。
class TokenSpan {
  const TokenSpan({
    required this.start,
    required this.end,
    required this.text,
  });

  final int start;
  final int end;
  final String text;
}

/// 高亮引擎：对英文文本进行考纲词高亮。
///
/// 流程：
/// 1. 预分词（按非字母数字切分，保留起止偏移）
/// 2. 规范化（小写）
/// 3. 匹配：先原型 → 再 lemma_map
/// 4. 词组最长匹配（2-3 词组合，优先命中词组词条）
/// 5. 输出高亮区间列表
class HighlightEngine {
  HighlightEngine(this.index);

  final DictMemoryIndex index;

  /// 对 [text] 执行高亮，返回高亮区间列表。
  ///
  /// [examTags] 可选：不为 null 时只高亮词条考纲标签命中任一 tag 的词；
  /// null 表示不按考纲过滤（全部）。空集合时不高亮任何词。
  List<HighlightSpan> highlight(String text, {Set<String>? examTags}) {
    final tokens = _tokenize(text);
    if (tokens.isEmpty) return [];

    final spans = <HighlightSpan>[];
    // 记录已占用的 token 起始偏移，避免词组与单词重复高亮
    final usedStarts = <int>{};

    // 词组最长匹配（3 词 → 2 词 → 1 词）
    for (var len = 3; len >= 1; len--) {
      for (var i = 0; i <= tokens.length - len; i++) {
        if (usedStarts.contains(tokens[i].start)) continue;

        final phrase = tokens
            .skip(i)
            .take(len)
            .map((t) => t.text.toLowerCase())
            .join(' ');

        // 匹配词组
        final phraseEntry = _matchPhrase(phrase, examTags);
        if (phraseEntry != null) {
          final start = tokens[i].start;
          final end = tokens[i + len - 1].end;
          spans.add(HighlightSpan(
            start: start,
            end: end,
            word: text.substring(start, end),
            entry: phraseEntry,
          ));
          for (var j = i; j < i + len; j++) {
            usedStarts.add(tokens[j].start);
          }
          continue;
        }

        // 单词匹配（只在 len == 1 时处理）
        if (len == 1) {
          final entry = _matchSingle(tokens[i], examTags);
          if (entry != null) {
            spans.add(HighlightSpan(
              start: tokens[i].start,
              end: tokens[i].end,
              word: tokens[i].text,
              entry: entry,
            ));
            usedStarts.add(tokens[i].start);
          }
        }
      }
    }

    // 按原文顺序排序
    spans.sort((a, b) => a.start.compareTo(b.start));
    return spans;
  }

  /// 匹配单词：先原型，再 lemma_map。
  WordEntry? _matchSingle(TokenSpan token, Set<String>? examTags) {
    final key = token.text.toLowerCase();
    // 原型命中
    final entry = index.words[key];
    if (entry != null) {
      if (_matchTags(entry, examTags)) return entry;
      return null;
    }
    // 词形还原
    final lemma = index.lemmaMap[key];
    if (lemma != null) {
      final lemmaEntry = index.words[lemma];
      if (lemmaEntry != null) {
        if (_matchTags(lemmaEntry, examTags)) return lemmaEntry;
      }
    }
    return null;
  }

  /// 匹配词组（含空格）。
  WordEntry? _matchPhrase(String phrase, Set<String>? examTags) {
    final entry = index.phrases[phrase];
    if (entry == null) return null;
    if (_matchTags(entry, examTags)) return entry;
    return null;
  }

  /// 考纲过滤：null = 不过滤；否则词条需命中任一选中的考纲标签。
  bool _matchTags(WordEntry entry, Set<String>? examTags) {
    if (examTags == null) return true;
    for (final t in entry.tags) {
      if (examTags.contains(t)) return true;
    }
    return false;
  }

  /// 分词：按非字母数字字符切分，保留每个 token 的起止偏移。
  static List<TokenSpan> _tokenize(String text) {
    final tokens = <TokenSpan>[];
    var start = -1;
    for (var i = 0; i < text.length; i++) {
      final ch = text.codeUnitAt(i);
      final isLetter = (ch >= 0x41 && ch <= 0x5A) || // A-Z
          (ch >= 0x61 && ch <= 0x7A) || // a-z
          ch == 0x27 || // apostrophe '
          ch == 0x2D; // hyphen -
      if (isLetter) {
        if (start == -1) start = i;
      } else {
        if (start != -1) {
          tokens.add(TokenSpan(
            start: start,
            end: i,
            text: text.substring(start, i),
          ));
          start = -1;
        }
      }
    }
    if (start != -1) {
      tokens.add(TokenSpan(
        start: start,
        end: text.length,
        text: text.substring(start),
      ));
    }
    return tokens;
  }
}