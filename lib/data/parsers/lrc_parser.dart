import 'parsed_content.dart';

/// .lrc 歌词解析器（纯 Dart，无依赖）。
///
/// 行格式 `[mm:ss.xx][mm:ss.xx]歌词文本`（一个时间戳可带多歌词），
/// 元数据如 `[ti:歌名]` `[ar:歌手]` `[offset:123]`（毫秒整体平移）。
///
/// 输出按时间升序的 [ContentSection]（startMs 即该歌词行的起始，
/// endMs 用下一行起始近似，供阅读定位用）。
class LrcParser {
  LrcParser._();

  static ParsedContent parse(String raw) {
    var title = '';
    var artist = '';
    var offset = 0;
    final rawRows = <({int ms, String text})>[];

    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    for (final line in normalized.split('\n')) {
      final lineText = line.trim();
      if (lineText.isEmpty) continue;

      final meta = _meta.firstMatch(lineText);
      if (meta != null) {
        final key = meta.group(1)?.toLowerCase();
        final value = meta.group(2)?.trim() ?? '';
        switch (key) {
          case 'ti':
            title = value;
          case 'ar':
            artist = value;
          case 'offset':
            offset = int.tryParse(value) ?? 0;
        }
        continue;
      }

      final times = _times.allMatches(lineText).toList();
      if (times.isEmpty) continue; // 无时间戳的非歌词行忽略
      final text = lineText.replaceAll(_timeToken, '').trim();
      if (text.isEmpty) continue;
      for (final m in times) {
        final ms = _parseStamp(m.group(0) ?? '');
        if (ms != null) rawRows.add((ms: ms, text: text));
      }
    }

    rawRows.sort((a, b) => a.ms.compareTo(b.ms));
    final shift = offset;
    final sections = <ContentSection>[];
    for (var i = 0; i < rawRows.length; i++) {
      final r = rawRows[i];
      final end = i + 1 < rawRows.length ? rawRows[i + 1].ms : null;
      sections.add(ContentSection(
        text: r.text,
        startMs: (r.ms + shift).clamp(0, 1 << 62),
        endMs: end == null ? null : end + shift,
      ));
    }

    final plainText = sections.map((s) => s.text).join('\n');
    final fallbackTitle = title.isEmpty ? '歌词' : title;
    return ParsedContent(
      defaultTitle: fallbackTitle,
      plainText: plainText,
      sections: sections,
      artist: artist,
    );
  }

  static final RegExp _timeToken = RegExp(r'\[\d{1,2}:\d{1,2}(?:[.:]\d{1,3})?\]');
  static final RegExp _times =
      RegExp(r'\[(\d{1,2}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
  static final RegExp _meta = RegExp(
    r'^\s*\[([a-zA-Z]+):(.*)\]$',
    caseSensitive: false,
  );

  /// `[mm:ss.xx]`（含方括号）→ 毫秒。
  static int? _parseStamp(String token) {
    final m = _times.firstMatch(token);
    if (m == null) return null;
    final minute = m.group(1);
    final sec = m.group(2);
    if (minute == null || sec == null) return null;
    try {
      final mm = int.parse(minute);
      final ss = int.parse(sec);
      var frac = 0;
      if (m.group(3) != null) {
        final f = m.group(3)!;
        frac = int.parse(f.length == 1 ? '${f}00' : f.length == 2 ? '${f}0' : f);
      }
      return mm * 60000 + ss * 1000 + frac;
    } catch (_) {
      return null;
    }
  }
}