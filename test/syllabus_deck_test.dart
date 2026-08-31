import 'dart:math';

import 'package:goslow/data/dict/memory_index.dart';
import 'package:goslow/data/dict/syllabus.dart';
import 'package:goslow/data/models/word_entry.dart';
import 'package:test/test.dart';

void main() {
  group('syllabusWordsFor 考纲过滤', () {
    WordEntry entry(String word, {List<String> tags = const [], int frq = 0}) {
      return WordEntry(id: word.hashCode, word: word, translation: '释义', tags: tags, frq: frq);
    }

    DictMemoryIndex indexWith(Map<String, WordEntry> words) {
      return DictMemoryIndex(words: words, phrases: const {}, lemmaMap: const {});
    }

    test('指定考纲只返回该 tag 的词', () {
      final index = indexWith({
        'apple': entry('apple', tags: ['cet4']),
        'zenith': entry('zenith', tags: ['gre']),
        'both': entry('both', tags: ['cet4', 'gre']),
      });
      final words = syllabusWordsFor(index, 'cet4');
      expect(words.map((e) => e.word), containsAll(['apple', 'both']));
      expect(words.map((e) => e.word), isNot(contains('zenith')));
    });

    test('全部 = 所有带考纲 tag 的词', () {
      final index = indexWith({
        'apple': entry('apple', tags: ['cet4']),
        'zenith': entry('zenith', tags: ['gre']),
        'plain': entry('plain', tags: const []), // 无 tag 不收
      });
      final words = syllabusWordsFor(index, kAllTag);
      expect(words, hasLength(2));
      expect(words.map((e) => e.word), containsAll(['apple', 'zenith']));
    });

    test('未命中考纲返回空', () {
      final index = indexWith({'apple': entry('apple', tags: ['cet4'])});
      expect(syllabusWordsFor(index, 'toefl'), isEmpty);
    });
  });

  group('sortSyllabus 排序', () {
    WordEntry entry(String word, {int frq = 0}) {
      return WordEntry(id: word.hashCode, word: word, translation: '释义', frq: frq);
    }

    test('词频：frq 越小越高频，排前面', () {
      final words = [entry('zebra', frq: 5000), entry('the', frq: 10), entry('apple', frq: 300)];
      final sorted = sortSyllabus(words, SyllabusOrder.frq);
      expect(sorted.map((e) => e.word).toList(), ['the', 'apple', 'zebra']);
    });

    test('字母序', () {
      final words = [entry('zebra'), entry('apple'), entry('The')];
      final sorted = sortSyllabus(words, SyllabusOrder.alpha);
      expect(sorted.map((e) => e.word).toList(), ['apple', 'The', 'zebra']);
    });

    test('随机：不修改原列表，顺序可不同', () {
      final words = [for (var i = 0; i < 20; i++) entry('w$i', frq: i)];
      final before = words.map((e) => e.word).toList();
      final sorted = sortSyllabus(words, SyllabusOrder.random, random: Random(42));
      expect(words.map((e) => e.word).toList(), before); // 原列表不变
      expect(sorted.map((e) => e.word).toSet(), before.toSet()); // 内容一致
      expect(sorted.map((e) => e.word).toList(), isNot(equals(before))); // 顺序被打乱
    });
  });

  group('assembleDeck 牌堆组装', () {
    test('复习优先于新词', () {
      final deck = assembleDeck(
        reviewQueue: ['old1', 'old2'],
        candidateNew: ['new1', 'new2', 'new3'],
        knownWords: const {},
        sessionSize: 3,
      );
      expect(deck, ['old1', 'old2', 'new1']);
    });

    test('跳过已认识的词', () {
      final deck = assembleDeck(
        reviewQueue: ['known1', 'old1'],
        candidateNew: ['known2', 'new1'],
        knownWords: const {'known1', 'known2'},
        sessionSize: 10,
      );
      expect(deck, ['old1', 'new1']);
    });

    test('去重：同词在复习池与新词都出现只取一次', () {
      final deck = assembleDeck(
        reviewQueue: ['word'],
        candidateNew: ['word', 'other'],
        knownWords: const {},
        sessionSize: 10,
      );
      expect(deck, ['word', 'other']);
    });

    test('按 sessionSize 截断', () {
      final deck = assembleDeck(
        reviewQueue: ['r1', 'r2', 'r3'],
        candidateNew: ['n1', 'n2', 'n3'],
        knownWords: const {},
        sessionSize: 4,
      );
      expect(deck, hasLength(4));
      expect(deck, ['r1', 'r2', 'r3', 'n1']);
    });

    test('都为空时返回空', () {
      final deck = assembleDeck(
        reviewQueue: const [],
        candidateNew: const [],
        knownWords: const {},
        sessionSize: 10,
      );
      expect(deck, isEmpty);
    });
  });
}
