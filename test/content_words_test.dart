import 'package:goslow/data/dict/highlight_engine.dart';
import 'package:goslow/data/dict/memory_index.dart';
import 'package:goslow/data/models/word_entry.dart';
import 'package:test/test.dart';

void main() {
  group('内容词自动收集（M5 交互改版）', () {
    WordEntry entry(String word, {List<String> tags = const ['cet4']}) =>
        WordEntry(
          id: word.hashCode,
          word: word,
          translation: '释义',
          tags: tags,
        );

    DictMemoryIndex indexWith(Map<String, WordEntry> words,
        {Map<String, WordEntry> phrases = const {},
        Map<String, String> lemmaMap = const {}}) {
      return DictMemoryIndex(
        words: words,
        phrases: phrases,
        lemmaMap: lemmaMap,
      );
    }

    /// 从多篇内容正文里收集出现过的考纲词（模拟 contentWordsProvider 逻辑）。
    Set<String> collectWords(HighlightEngine engine, List<String> bodies) {
      final words = <String>{};
      for (final body in bodies) {
        for (final s in engine.highlight(body)) {
          words.add(s.entry.word.toLowerCase());
        }
      }
      return words;
    }

    test('多篇内容自动汇总去重', () {
      final engine = HighlightEngine(indexWith(
        {
          'apple': entry('apple'),
          'banana': entry('banana'),
          'cat': entry('cat'),
        },
      ));
      final words = collectWords(engine, [
        'I eat an apple.',
        'A banana and an apple.',
        'The cat sees the banana.',
      ]);
      expect(words, {'apple', 'banana', 'cat'});
    });

    test('内容里的变形词归到原型', () {
      final engine = HighlightEngine(indexWith(
        {'go': entry('go')},
        lemmaMap: {'going': 'go', 'went': 'go'},
      ));
      final words = collectWords(engine, [
        'I am going home.',
        'She went away.',
      ]);
      expect(words, {'go'});
    });

    test('内容里没有考纲词 → 空集', () {
      final engine = HighlightEngine(indexWith({'apple': entry('apple')}));
      expect(collectWords(engine, ['Hello there!']), isEmpty);
    });
  });
}
