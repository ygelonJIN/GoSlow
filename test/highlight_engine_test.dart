import 'package:goslow/data/dict/highlight_engine.dart';
import 'package:goslow/data/dict/memory_index.dart';
import 'package:goslow/data/models/word_entry.dart';
import 'package:test/test.dart';

void main() {
  group('HighlightEngine', () {
    WordEntry entry(String word) => WordEntry(
          id: word.hashCode,
          word: word,
          translation: '释义',
          tags: const ['cet4'],
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

    test('原型词直接高亮', () {
      final engine = HighlightEngine(indexWith({'get': entry('get')}));
      final spans = engine.highlight('I will get it done.');
      expect(spans, hasLength(1));
      expect(spans.first.word, 'get');
      expect(spans.first.start, 7);
      expect(spans.first.end, 10);
    });

    test('变形词通过 lemma 高亮', () {
      final engine = HighlightEngine(indexWith(
        {'go': entry('go')},
        lemmaMap: {'going': 'go', 'went': 'go'},
      ));
      final spans = engine.highlight('I am going home, she went away.');
      expect(spans, hasLength(2));
      expect(spans.any((s) => s.word == 'going'), isTrue);
      expect(spans.any((s) => s.word == 'went'), isTrue);
      expect(spans.every((s) => s.entry.word == 'go'), isTrue);
    });

    test('词组最长匹配优先于单词', () {
      final engine = HighlightEngine(
        indexWith(
          {'give': entry('give'), 'up': entry('up')},
          phrases: {'give up': entry('give up')},
        ),
      );
      final spans = engine.highlight('I will give up now.');
      expect(spans, hasLength(1));
      expect(spans.first.word, 'give up');
    });

    test('考纲过滤只高亮指定考纲', () {
      final cet4 = entry('apple')..tags = ['cet4'];
      final gre = entry('zenith')..tags = ['gre'];
      final engine = HighlightEngine(indexWith({'apple': cet4, 'zenith': gre}));
      final spans = engine.highlight('apple zenith', examTag: 'cet4');
      expect(spans, hasLength(1));
      expect(spans.first.word, 'apple');
    });

    test('非考纲词不高亮', () {
      final engine = HighlightEngine(indexWith({'the': entry('the')}));
      final spans = engine.highlight('a completely unknown word');
      expect(spans, isEmpty);
    });

    test('保持原文偏移可用于点词回定位', () {
      final engine = HighlightEngine(indexWith({'better': entry('better')}));
      const text = 'It is much better now, better than before.';
      final spans = engine.highlight(text);
      expect(spans, hasLength(2));
      for (final s in spans) {
        expect(text.substring(s.start, s.end), 'better');
      }
    });
  });
}
