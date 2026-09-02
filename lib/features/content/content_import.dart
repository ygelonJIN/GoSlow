import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/parsers/content_parser.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/feedback_dialog.dart';

/// 导入 .txt / .md / .epub / .srt / .lrc 内容文件（主页底部「导入文件」与
/// 添加内容页共用）。成功 / 失败统一走主题化 [FeedbackDialog]。
Future<void> pickContentFile(BuildContext context, WidgetRef ref) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['txt', 'md', 'epub', 'srt', 'lrc'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return;
  final file = result.files.first;
  final name = file.name;
  final ext = name.toLowerCase().split('.').last;

  try {
    if (ext == 'epub') {
      final bytes = file.bytes;
      if (bytes == null) {
        if (context.mounted) {
          FeedbackDialog.show(context, message: 'epub 需要以字节方式读取，请重试');
        }
        return;
      }
      await importParsed(ref, ext, bytes);
    } else if (ext == 'srt' || ext == 'lrc') {
      final text = await _decodeText(file);
      if (text == null) {
        if (context.mounted) {
          FeedbackDialog.show(context, message: '文件读取失败');
        }
        return;
      }
      await importParsed(ref, ext, _encode(text));
    } else {
      final text = await _decodeText(file);
      if (text == null || text.trim().isEmpty) {
        if (context.mounted) {
          FeedbackDialog.show(context, message: '文件为空或读取失败');
        }
        return;
      }
      final title = name.replaceAll(
        RegExp(r'\.(txt|md)$', caseSensitive: false),
        '',
      );
      final parsed = ContentParser.parsePlainText(text, defaultTitle: title);
      await importParsed(
        ref,
        ext,
        _encode(parsed.plainText),
        title: parsed.defaultTitle,
      );
    }
    if (context.mounted) {
      FeedbackDialog.show(context, message: '已导入：$name', icon: Icons.check_rounded, title: '已导入');
    }
  } catch (e) {
    if (context.mounted) {
      FeedbackDialog.show(context, message: '导入失败：$e', title: '出错了');
    }
  }
}

/// 解析文件字节并入库（epub/srt/lrc 用结构化解析，其余按纯文本）。
Future<bool> importParsed(
  WidgetRef ref,
  String sourceType,
  List<int> bytes, {
  String? title,
}) async {
  final data = Uint8List.fromList(bytes);
  final parsed =
      sourceType == 'epub' || sourceType == 'srt' || sourceType == 'lrc'
      ? ContentParser.parseFile(sourceType, data)
      : ContentParser.parsePlainText(utf8.decode(data, allowMalformed: true));
  if (parsed == null || parsed.plainText.trim().isEmpty) {
    return false;
  }
  final repo = ref.read(contentRepoProvider);
  await repo.insert(
    title: title ?? parsed.defaultTitle,
    body: parsed.plainText,
    sourceType: sourceType,
    sections: parsed.sections,
  );
  ref.read(contentVersionProvider.notifier).state++;
  return true;
}

Future<String?> _decodeText(PlatformFile file) async {
  if (file.bytes != null) {
    return utf8.decode(file.bytes!, allowMalformed: true);
  }
  if (file.path != null) {
    try {
      return await File(file.path!).readAsString();
    } catch (_) {
      return null;
    }
  }
  return null;
}

Uint8List _encode(String s) => Uint8List.fromList(utf8.encode(s));
