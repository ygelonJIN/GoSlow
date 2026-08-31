// 纯 Dart 高亮引擎验证脚本（沙箱内可直跑，无需 flutter 工具链）。
//
// 用法：dart run tool/check_engine.dart
//
// 与 test/highlight_engine_test.dart 断言一致；
// 后者在 Terminal 里用 `flutter test` 跑（需要 flutter 工具链）。

import 'package:goslow/data/dict/highlight_engine.dart';
import 'package:goslow/data/dict/memory_index.dart';
import 'package:goslow/data/models/word_entry.dart';

int _failures = 0;
int _checks = 0;

void check(String name, bool condition) {
  _checks++;
  if (condition) {
    print('  ok  $name');
  } else {
    _failures++;
    print('FAIL  $name');
  }
}

WordEntry entry(String word) => WordEntry(
      id: word.hashCode,
      word: word,
      translation: '释义',
      tags: const ['cet4'],
    );

DictMemoryIndex indexWith(
  Map<String, WordEntry> words, {
  Map<String, WordEntry> phrases = const {},
  Map<String, String> lemmaMap = const {},
}) {
  return DictMemoryIndex(words: words, phrases: phrases, lemmaMap: lemmaMap);
}

void main() {
  print('== 原型词直接高亮 ==');
  {
    final engine = HighlightEngine(indexWith({'get': entry('get')}));
    final spans = engine.highlight('I will get it done.');
    check('命中 1 个词', spans.length == 1);
    check('词形为 get', spans.first.word == 'get');
    check('偏移正确 (7-10)', spans.first.start == 7 && spans.first.end == 10);
  }

  print('== 变形词通过 lemma 高亮 ==');
  {
    final engine = HighlightEngine(indexWith(
      {'go': entry('go')},
      lemmaMap: {'going': 'go', 'went': 'go'},
    ));
    final spans = engine.highlight('I am going home, she went away.');
    print('      spans: ${spans.map((s) => '${s.word}(${s.start}-${s.end})').toList()}');
    check('命中 2 个词', spans.length == 2);
    check(
      'going 命中',
      spans.any((s) => s.word == 'going'),
    );
    check(
      'went 命中',
      spans.any((s) => s.word == 'went'),
    );
    check('还原到原型 go', spans.every((s) => s.entry.word == 'go'));
  }

  print('== 词组最长匹配优先于单词 ==');
  {
    final engine = HighlightEngine(
      indexWith(
        {'give': entry('give'), 'up': entry('up')},
        phrases: {'give up': entry('give up')},
      ),
    );
    final spans = engine.highlight('I will give up now.');
    check('只命中 1 个区间', spans.length == 1);
    check('命中词组 give up', spans.first.word == 'give up');
  }

  print('== 考纲过滤只高亮指定考纲 ==');
  {
    final cet4 = entry('apple')..tags = ['cet4'];
    final gre = entry('zenith')..tags = ['gre'];
    final engine = HighlightEngine(indexWith({'apple': cet4, 'zenith': gre}));
    final spans = engine.highlight('apple zenith', examTag: 'cet4');
    check('只命中 apple', spans.length == 1 && spans.first.word == 'apple');
  }

  print('== 非考纲词不高亮 ==');
  {
    final engine = HighlightEngine(indexWith({'the': entry('the')}));
    final spans = engine.highlight('a completely unknown word');
    check('无高亮', spans.isEmpty);
  }

  print('== 保持原文偏移可用于点词回定位 ==');
  {
    final engine = HighlightEngine(indexWith({'better': entry('better')}));
    const text = 'It is much better now, better than before.';
    final spans = engine.highlight(text);
    check('命中 2 处', spans.length == 2);
    check(
      '每处原文子串都是 better',
      spans.every((s) => text.substring(s.start, s.end) == 'better'),
    );
  }

  print('');
  print('$_checks 项检查，$_failures 项失败');
  if (_failures > 0) {
    throw StateError('高亮引擎验证未通过');
  }
  print('高亮引擎验证通过');
}
