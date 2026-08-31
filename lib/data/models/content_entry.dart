import 'dart:convert';

import '../parsers/parsed_content.dart';

/// 内容条目：粘贴文本 / 导入的 txt / epub / srt / lrc 等。
class ContentEntry {
  const ContentEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.sourceType,
    required this.createdAt,
    this.sections = const [],
    this.lastOpenedAt,
  });

  final int id;
  final String title;
  final String body;
  final String sourceType;
  final DateTime createdAt;

  /// 最近打开（阅读）时间；从未打开过为 null。
  final DateTime? lastOpenedAt;

  /// 结构化分节（epub 章节 / srt/lrc 时间轴行），旧内容为空。
  final List<ContentSection> sections;

  /// 是否有结构化分节（阅读器按章节/时间轴渲染）。
  bool get hasSections => sections.isNotEmpty;

  int get wordCount => body.trim().isEmpty ? 0 : body.trim().split(RegExp(r'\s+')).length;

  String get displaySource {
    switch (sourceType) {
      case 'paste':
        return '粘贴';
      case 'txt':
        return '文本文件';
      case 'md':
        return 'Markdown';
      case 'srt':
        return '字幕';
      case 'lrc':
        return '歌词';
      case 'epub':
        return '电子书';
      default:
        return sourceType;
    }
  }

  factory ContentEntry.fromRow(Map<String, Object?> row) {
    final sectionsJson = row['sections'] as String?;
    final lastOpened = row['last_opened_at'] as int?;
    return ContentEntry(
      id: (row['id'] as int?) ?? 0,
      title: (row['title'] as String?) ?? '',
      body: (row['body'] as String?) ?? '',
      sourceType: (row['source_type'] as String?) ?? 'paste',
      createdAt: DateTime.fromMillisecondsSinceEpoch((row['created_at'] as int?) ?? 0),
      sections: decodeSections(sectionsJson),
      lastOpenedAt: lastOpened == null ? null : DateTime.fromMillisecondsSinceEpoch(lastOpened),
    );
  }

  Map<String, Object?> toRow() {
    return {
      'title': title,
      'body': body,
      'source_type': sourceType,
      'created_at': createdAt.millisecondsSinceEpoch,
      'sections': encodeSections(sections),
      'last_opened_at': lastOpenedAt?.millisecondsSinceEpoch,
    };
  }

  ContentEntry copyWith({
    int? id,
    String? title,
    String? body,
    String? sourceType,
    List<ContentSection>? sections,
  }) {
    return ContentEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      sourceType: sourceType ?? this.sourceType,
      createdAt: createdAt,
      sections: sections ?? this.sections,
    );
  }
}

String encodeSections(List<ContentSection> sections) {
  return jsonEncode([
    for (final s in sections)
      {
        'text': s.text,
        if (s.startMs != null) 'start_ms': s.startMs,
        if (s.endMs != null) 'end_ms': s.endMs,
        if (s.title != null) 'title': s.title,
      },
  ]);
}

List<ContentSection> decodeSections(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final list = jsonDecode(json) as List<dynamic>;
    return [
      for (final e in list)
        if (e is Map && (e['text'] as String?) != null)
          ContentSection(
            text: e['text'] as String,
            startMs: (e['start_ms'] as num?)?.toInt(),
            endMs: (e['end_ms'] as num?)?.toInt(),
            title: e['title'] as String?,
          ),
    ];
  } catch (_) {
    return const [];
  }
}