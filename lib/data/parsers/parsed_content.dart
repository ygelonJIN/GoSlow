/// 内容解析结果（M5）— 供入库与阅读器下拉。
///
/// 统一表达 txt/md/srt/lrc/epub 解析后的产物：
/// [plainText] 为拼接的纯文本（用于字数统计 / 列表展示），
/// [sections] 为结构化分节（字幕/歌词按时间轴，epub 按章节）。
class ParsedContent {
  const ParsedContent({
    required this.defaultTitle,
    required this.plainText,
    this.sections = const [],
    this.artist = '',
  });

  final String defaultTitle;
  final String plainText;
  final List<ContentSection> sections;

  /// 作者/歌手（歌词 `[ar:]`、epub 作者），无则空字符串。
  final String artist;
}

/// 一条结构化内容分节。
///
/// - 字幕/歌词：用 [startMs]/[endMs]（毫秒）表达时间轴，[title] 为空；
/// - epub 章节：[title] 为章节标题，[text] 为正文，时间为空。
class ContentSection {
  const ContentSection({
    required this.text,
    this.startMs,
    this.endMs,
    this.title,
  });

  final String text;
  final int? startMs;
  final int? endMs;
  final String? title;

  /// 时间轴展示标签（如 `00:01:23` / `[01:23.45]`），无时间则空。
  String get timeLabel {
    if (startMs == null) return '';
    return _fmtClock(startMs!);
  }

  /// 是否时间轴分节（字幕/歌词）。
  bool get isTimed => startMs != null;

  static String _fmtClock(int ms) {
    final t = Duration(milliseconds: ms);
    final h = t.inHours;
    final m = (t.inMinutes % 60);
    final s = (t.inSeconds % 60);
    return h > 0 ? '${_two(h)}:${_two(m)}:${_two(s)}' : '${_two(m)}:${_two(s)}';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}