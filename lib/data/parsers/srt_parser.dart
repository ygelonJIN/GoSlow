import 'parsed_content.dart';

/// .srt 字幕解析器（纯 Dart，无依赖）。
///
/// SRT 块结构：
/// ```
/// 1
/// 00:00:01,000 --> 00:00:04,000
/// Hello world
/// ...
/// ```
/// 支持 `,` / `.` 毫秒分隔、可选块编号、可选 HTML 标签剥离。
class SrtParser {
  SrtParser._();

  /// 解析 SRT 文本为目标行序列；不合法输入返回空系列。
  static ParsedContent parse(String raw) {
    final lines = _parseSubtitleBlocks(raw);
    final plainText = lines.map((l) => l.text).join('\n');
    return ParsedContent(
      defaultTitle: '字幕',
      plainText: plainText,
      sections: lines,
    );
  }

  static List<ContentSection> _parseSubtitleBlocks(String raw) {
    final out = <ContentSection>[];
    // 用空行切块；兼容 \r\n。
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = normalized.split(RegExp(r'\n\s*\n'));
    for (final block in blocks) {
      final section = _parseBlock(block);
      if (section != null) out.add(section);
    }
    return out;
  }

  static ContentSection? _parseBlock(String block) {
    final lines = block
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    var idx = 0;
    // 可选块编号（纯数字行）。
    if (_isPlainNumber(lines[idx])) {
      idx++;
    }
    // 时间轴行 `start --> end`。
    final timeMatch = _timeRange.firstMatch(idx < lines.length ? lines[idx] : '');
    if (timeMatch == null) return null;
    final start = _parseClock(timeMatch.group(1)!);
    final end = _parseClock(timeMatch.group(2)!);
    if (start == null || end == null) return null;
    idx++;

    final text = lines
        .skip(idx)
        .map(_stripTags)
        .where((l) => l.isNotEmpty)
        .join('\n');
    if (text.isEmpty) return null;
    return ContentSection(text: text, startMs: start, endMs: end);
  }

  static final RegExp _timeRange =
      RegExp(r'^\s*([0-9:.,]+)\s*-->\s*([0-9:.,]+)');
  static final RegExp _plainNumber = RegExp(r'^\d+$');
  static final RegExp _htmlTag = RegExp(
    r'<[^>]+>',
    caseSensitive: false,
  );

  static bool _isPlainNumber(String s) => _plainNumber.hasMatch(s);

  /// `HH:MM:SS,mmm` 或 `MM:SS.mmm` → 毫秒；不合法返回 null。
  static int? _parseClock(String s) {
    final norm = s.replaceAll(',', '.').replaceAll('，', '.');
    final parts = norm.split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    var ms = 0;
    try {
      if (parts.length == 3) {
        ms += int.parse(parts[0]) * 3600000;
        ms += int.parse(parts[1]) * 60000;
      } else {
        ms += int.parse(parts[0]) * 60000;
      }
      final last = parts.last.split('.');
      if (last.length != 2) return null;
      final sec = int.parse(last[0]);
      final milli = int.parse(last[1].padRight(3, '0').substring(0, 3));
      ms += sec * 1000 + milli;
    } catch (_) {
      return null;
    }
    return ms;
  }

  static String _stripTags(String s) => s.replaceAll(_htmlTag, '').trim();
}