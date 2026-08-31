import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'parsed_content.dart';

/// EPUB 解析结果（书名/作者 + 章节列表）。
class EpubBook {
  const EpubBook({this.title = '', this.author = '', this.chapters = const []});

  final String title;
  final String author;
  final List<ContentSection> chapters;

  String get plainText => chapters.map((c) => c.text).join('\n\n');
}

/// .epub 阅读器解析（M5）— 用 `archive` 解 zip、`xml` 读 OPF/章节。
///
/// 遵循开发文档 §10：复杂排版（CSS / 图片 / 样式）降级为纯文本，
/// 只抽取章节标题 + 正文文本。输入为 epub 文件字节。
class EpubParser {
  EpubParser._();

  static EpubBook parse(List<int> bytes) {
    return _parseBook(Uint8List.fromList(bytes));
  }

  static EpubBook _parseBook(Uint8List data) {
    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(data);
    } catch (_) {
      return const EpubBook();
    }

    final opfPath = _findOpfPath(archive);
    if (opfPath == null) return const EpubBook();
    final opfFile = _fileByName(archive, opfPath);
    if (opfFile == null) return const EpubBook();

    final opfDoc = _parseXml(opfFile);
    if (opfDoc == null) return const EpubBook();

    final title = _opfMetadata(opfDoc, 'title');
    final author = _opfMetadata(opfDoc, 'creator');

    // manifest: id → href
    final hrefById = <String, String>{};
    for (final item in _descendants(opfDoc).where((e) => e.name.local == 'item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id != null && href != null) hrefById[id] = href;
    }

    // spine: 按顺序的 idref → 章节文件。
    final chapters = <ContentSection>[];
    for (final itemref in _descendants(opfDoc).where((e) => e.name.local == 'itemref')) {
      final idref = itemref.getAttribute('idref');
      if (idref == null) continue;
      final href = hrefById[idref];
      if (href == null) continue;
      final relPath = _resolveRelative(opfPath, href);
      final file = _fileByName(archive, relPath);
      if (file == null) continue;
      final chapter = _parseChapterFile(file);
      chapters.add(chapter);
    }

    final resolved = title.isEmpty ? '电子书' : title;
    return EpubBook(
      title: resolved,
      author: author,
      chapters: chapters,
    );
  }

  static ContentSection _parseChapterFile(ArchiveFile file) {
    final bytes = file.content as List<int>;
    final doc = _parseXmlBytes(bytes);
    if (doc == null) return const ContentSection(text: '');

    final htmlTitle = _htmlTitle(doc);
    final text = _flattenText(doc);
    return ContentSection(text: text, title: htmlTitle.isEmpty ? null : htmlTitle);
  }

  static String? _findOpfPath(Archive archive) {
    final container = _fileByName(archive, 'META-INF/container.xml');
    if (container == null) return null;
    final doc = _parseXmlBytes(container.content as List<int>);
    if (doc == null) return null;
    final rootfile = _descendants(doc).where((e) => e.name.local == 'rootfile').toList();
    if (rootfile.isEmpty) return null;
    final f = rootfile.first.getAttribute('full-path');
    return f;
  }

  /// 在 [basePath] 所在目录下解析相对 [href]，返回归档内完整路径。
  static String _resolveRelative(String basePath, String href) {
    final base = basePath.contains('/')
        ? basePath.substring(0, basePath.lastIndexOf('/') + 1)
        : '';
    final h = href.replaceAll('\\', '/');
    if (h.startsWith('/')) return h.substring(1);
    final baseParts = base.isEmpty
        ? <String>[]
        : base.split('/').where((p) => p.isNotEmpty).toList();
    final parts = h.split('/');
    for (final p in parts) {
      if (p == '..') {
        if (baseParts.isNotEmpty) baseParts.removeLast();
      } else if (p != '.' && p.isNotEmpty) {
        baseParts.add(p);
      }
    }
    return baseParts.join('/');
  }

  static ArchiveFile? _fileByName(Archive archive, String name) {
    final n = name.replaceAll('\\', '/');
    for (final f in archive.files) {
      if (f.name == n || f.name == 'OEBPS/$n') return f;
    }
    return null;
  }

  static XmlDocument? _parseXmlBytes(List<int> bytes) {
    final str = _decodeQuiet(bytes);
    return _parseXmlString(str);
  }

  static XmlDocument? _parseXml(ArchiveFile file) {
    final str = _decodeQuiet(file.content as List<int>);
    return _parseXmlString(str);
  }

  static XmlDocument? _parseXmlString(String str) {
    try {
      return XmlDocument.parse(str);
    } catch (_) {
      return null;
    }
  }

  static String _decodeQuiet(List<int> bytes) {
    // 优先 UTF-8，带 BOM 则剥掉；失败退 ASCII。
    final start = bytes.isNotEmpty && bytes[0] == 0xEF ? 3 : 0;
    try {
      return utf8.decode(bytes.sublist(start, bytes.length));
    } catch (_) {
      return ascii.decode(bytes, allowInvalid: true);
    }
  }

  static Iterable<XmlElement> _descendants(XmlDocument doc) =>
      doc.rootElement.descendantElements;

  static String _opfMetadata(XmlDocument doc, String name) {
    final el = _descendants(doc).where((e) => e.name.local == name).toList();
    if (el.isEmpty) return '';
    final e = el.first;
    final value = e.innerText.trim();
    // 属性 dc:title 也可能内嵌，innerText 已覆盖文本节点。
    return value;
  }

  static String _htmlTitle(XmlDocument doc) {
    final title = _descendants(doc).where((e) => e.name.local == 'title').toList();
    return title.isEmpty ? '' : title.first.innerText.trim();
  }

  /// 抽取可见文本：跳过 head/script/style，按块元素换行。
  static String _flattenText(XmlDocument doc) {
    final buf = StringBuffer();
    final blockTags = {
      'p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
      'li', 'br', 'section', 'blockquote', 'tr', 'dt', 'dd',
    };
    void walk(XmlNode node) {
      if (node is XmlText) {
        buf.write(node.value);
      } else if (node is XmlCDATA) {
        buf.write(node.value);
      } else if (node is XmlElement) {
        final tag = node.name.local.toLowerCase();
        if (tag == 'head' || tag == 'script' || tag == 'style') return;
        for (final c in node.children) {
          walk(c);
        }
        if (blockTags.contains(tag)) buf.write('\n');
      }
    }

    walk(doc.rootElement);
    // 规整：合并空白行，去除多余空行。
    final text = buf.toString()
        .replaceAll(RegExp(r'[ \t\u00a0]+'), ' ')
        .replaceAll(RegExp(r'\n[ \t]*'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}