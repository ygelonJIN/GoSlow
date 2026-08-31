import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:goslow/data/parsers/content_parser.dart';
import 'package:goslow/data/parsers/epub_parser.dart';
import 'package:goslow/data/parsers/lrc_parser.dart';
import 'package:goslow/data/parsers/srt_parser.dart';
import 'package:test/test.dart';

void main() {
  group('SrtParser', () {
    test('解析标准 SRT 块', () {
      const srt = '''
1
00:00:01,000 --> 00:00:04,000
Hello world

2
00:00:05,500 --> 00:00:08,250
How are you today?
''';
      final p = SrtParser.parse(srt);
      expect(p.sections.length, 2);
      expect(p.sections[0].text, 'Hello world');
      expect(p.sections[0].startMs, 1000);
      expect(p.sections[0].endMs, 4000);
      expect(p.sections[1].startMs, 5500);
      expect(p.sections[1].timeLabel, '00:05');
      expect(p.plainText.contains('How are you today?'), isTrue);
    });

    test('支持省略编号 + 点号毫秒 + 多行文本', () {
      const srt = '''
00:01:02.300 --> 00:01:05.900
First line
Second & third
''';
      final p = SrtParser.parse(srt);
      expect(p.sections.length, 1);
      expect(p.sections.first.text, 'First line\nSecond & third');
      expect(p.sections.first.startMs, 62300);
    });

    test('剥离 HTML 标签', () {
      const srt = '''
1
00:00:01,000 --> 00:00:02,000
<i>Italic</i> <b>bold</b>
''';
      expect(SrtParser.parse(srt).sections.first.text, 'Italic bold');
    });

    test('非法块被忽略', () {
      const srt = '''
garbage
not a time range

1
00:00:01,000 --> 00:00:02,000
ok

2
bad --> no
''';
      final p = SrtParser.parse(srt);
      expect(p.sections.length, 1);
      expect(p.sections.first.text, 'ok');
    });

    test('空输入返回空', () {
      expect(SrtParser.parse('').sections, isEmpty);
    });
  });

  group('LrcParser', () {
    test('解析带多时间戳与元数据的歌词', () {
      const lrc = '''
[ti:Test Song]
[ar:Someone]
[00:12.34]Hello
[00:15.60][00:20.00]World
''';
      final p = LrcParser.parse(lrc);
      expect(p.defaultTitle, 'Test Song');
      expect(p.sections.length, 3);
      expect(p.sections[0].text, 'Hello');
      expect(p.sections[0].startMs, 12340);
      expect(p.sections[1].text, 'World');
      expect(p.sections[1].startMs, 15600);
      expect(p.sections[2].startMs, 20000);
      expect(p.sections[0].endMs, 15600); // 下一行近似
    });

    test('按时间升序排序 + offset 平移', () {
      const lrc = '''
[ar:Artist]
[offset:1000]
[01:30.00]later
[00:10.00]earlier
''';
      final p = LrcParser.parse(lrc);
      expect(p.sections.length, 2);
      expect(p.sections[0].text, 'earlier');
      expect(p.sections[0].startMs, 10000 + 1000);
      expect(p.sections[1].text, 'later');
    });

    test('无时间戳的非歌词行忽略', () {
      const lrc = '[00:01.00]only';
      final p = LrcParser.parse(lrc);
      expect(p.sections.length, 1);
      expect(p.sections.first.text, 'only');
    });
  });

  group('ContentParser.parsePlainText', () {
    test('整段作单一 section + 首行作标题', () {
      final p = ContentParser.parsePlainText('A Title\n\nBody here');
      expect(p.sections.length, 1);
      expect(p.sections.first.text.length, greaterThan(0));
      expect(p.defaultTitle, 'A Title');
    });
  });

  group('EpubParser', () {
    Uint8List buildEpub() {
      final archive = Archive();
      void add(String name, String content) {
        final bytes = Uint8List.fromList(utf8.encode(content));
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }

      add('META-INF/container.xml', '''
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''');
      add('OEBPS/content.opf', '''
<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Little Book</dc:title>
    <dc:creator>Jane Doe</dc:creator>
  </metadata>
  <manifest>
    <item id="c1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
    <item id="c2" href="chap2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="c1"/>
    <itemref idref="c2"/>
  </spine>
</package>''');
      add('OEBPS/chap1.xhtml', '''
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>One</title></head><body>
<h1>One</h1><p>First para.</p><p>Second para.</p>
</body></html>''');
      add('OEBPS/chap2.xhtml', '''
<html xmlns="http://www.w3.org/1999/xhtml"><body>
<p>Chap two <b>bold</b> text.</p>
</body></html>''');

      final data = ZipEncoder().encode(archive);
      return Uint8List.fromList(data);
    }

    test('解析章节 + 元数据', () {
      final book = EpubParser.parse(buildEpub());
      expect(book.title, 'Little Book');
      expect(book.chapters.length, 2);
      expect(book.chapters[0].title, 'One');
      expect(book.chapters[0].text, contains('First para'));
      expect(book.chapters[1].title, isNull); // 无 <title> 则不加
      expect(book.chapters[1].text, contains('bold'));
    });

    test('空/损坏输入返回空书', () {
      expect(EpubParser.parse(const []).chapters, isEmpty);
      expect(EpubParser.parse([1, 2, 3]).chapters, isEmpty);
    });
  });

  group('ContentParser.parseFile', () {
    test('srt 分发', () {
      final p = ContentParser.parseFile('srt',
          Uint8List.fromList(utf8.encode('1\n00:00:01,000 --> 00:00:02,000\na')));
      expect(p, isNotNull);
      expect(p!.sections.length, 1);
      expect(p.defaultTitle, '字幕');
    });

    test('lrc 分发', () {
      final p =
          ContentParser.parseFile('lrc', Uint8List.fromList(utf8.encode('[00:01.00]hi')));
      expect(p, isNotNull);
      expect(p!.sections.first.startMs, 1000);
    });

    test('未知类型返回 null', () {
      expect(ContentParser.parseFile('exe', Uint8List.fromList([1])), isNull);
    });
  });
}