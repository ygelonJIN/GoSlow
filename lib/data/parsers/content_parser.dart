import 'dart:convert';
import 'dart:typed_data';

import 'epub_parser.dart';
import 'lrc_parser.dart';
import 'parsed_content.dart';
import 'srt_parser.dart';

/// 内容解析门面（M5）：按 [sourceType] 分发到对应解析器。
///
/// - `txt` / `md` / `paste`：纯文本，整段为一个 section；
/// - `srt`：字幕 → 时间轴行；
/// - `lrc`：歌词 → 时间轴行；
/// - `epub`：电子书（zip）→ 章节。
class ContentParser {
  ContentParser._();

  /// 解析纯文本内容（txt/md/paste）。
  static ParsedContent parsePlainText(String text, {String defaultTitle = '文本'}) {
    final t = text.trim();
    String title = defaultTitle;
    if (t.isNotEmpty) {
      final firstLine = t.split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => t);
      if (firstLine.length <= 28) title = firstLine;
    }
    return ParsedContent(
      defaultTitle: title,
      plainText: t,
      sections: [ContentSection(text: t)],
    );
  }

  /// 解析文件字节内容：根据 [sourceType] 分发。
  /// 返回 null 表示解析失败（无法识别的格式 / 空内容）。
  static ParsedContent? parseFile(String sourceType, Uint8List bytes) {
    switch (sourceType) {
      case 'srt':
        return SrtParser.parse(_utf8(bytes));
      case 'lrc':
        return LrcParser.parse(_utf8(bytes));
      case 'epub':
        final book = EpubParser.parse(bytes);
        if (book.chapters.isEmpty) return null;
        return ParsedContent(
          defaultTitle: book.title,
          plainText: book.plainText,
          sections: book.chapters,
        );
      default:
        return null;
    }
  }

  static String _utf8(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }
}