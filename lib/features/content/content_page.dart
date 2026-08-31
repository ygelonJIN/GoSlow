import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design/design.dart';
import '../../data/parsers/content_parser.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/entry_card.dart';
import '../../shared/section_header.dart';
import 'dict_lookup_page.dart';
import 'paste_page.dart';
import 'reader_page.dart';

class ContentPage extends ConsumerWidget {
  const ContentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentsAsync = ref.watch(contentsProvider);

    return contentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: AppInsets.card,
          child: Text('加载失败：$e', style: Theme.of(context).textTheme.bodySmall),
        ),
      ),
      data: (contents) {
        return ListView(
          padding: EdgeInsets.only(
            top: AppOverlay.topInset(context),
            bottom: AppOverlay.bottomInset(context),
          ),
          children: [
            Padding(
              padding: AppInsets.search,
              child: _SearchField(onTap: () => _openLookup(context)),
            ),
            const SectionHeader('最近阅读'),
            if (contents.isEmpty)
              const EntryCard(
                icon: Icons.menu_book_outlined,
                title: '还没有内容',
                subtitle: '粘贴一段英文，或导入 .txt，立即看高亮',
                enabled: false,
              )
            else
              for (final c in contents)
                EntryCard(
                  icon: _sourceIcon(c.sourceType),
                  title: c.title,
                  subtitle:
                      '${c.displaySource} · ${c.wordCount} 词 · ${_formatDate(c.createdAt)}',
                  onTap: () => _openReader(context, ref, c),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.more_horiz,
                      size: 18,
                      color: AppColors.inkMuted,
                    ),
                    onPressed: () => _showContentActions(context, ref, c),
                  ),
                ),
            EntryCard(
              icon: Icons.search,
              title: '查单词',
              subtitle: '精确查询 + 词形还原（got → get），离线可用',
              onTap: () => _openLookup(context),
            ),
            const SectionHeader('内容导入'),
            EntryCard(
              icon: Icons.assignment_outlined,
              title: '粘贴文本',
              subtitle: '任意段落，一键高亮',
              onTap: () => _openPaste(context),
            ),
            EntryCard(
              icon: Icons.upload_file_outlined,
              title: '导入文件',
              subtitle: '.txt / .md / .epub / .srt / .lrc',
              onTap: () => _pickFile(context, ref),
            ),
            const SectionHeader('为你推荐'),
            Card(
              child: Padding(
                padding: AppInsets.card,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.seedSoft,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        size: 22,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '今日一段 · 粘贴即高亮',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontSize: 13, color: AppColors.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '任意英文段落，自动标出考纲词',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static IconData _sourceIcon(String sourceType) {
    switch (sourceType) {
      case 'epub':
        return Icons.menu_book_outlined;
      case 'srt':
        return Icons.closed_caption_outlined;
      case 'lrc':
        return Icons.music_note_outlined;
      case 'md':
        return Icons.description_outlined;
      case 'paste':
        return Icons.article_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  void _openLookup(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const DictLookupPage()));
  }

  void _openPaste(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const PastePage()));
  }

  void _openReader(BuildContext context, WidgetRef ref, dynamic content) {
    final id = content.id as int;
    // 记录最近打开（最近阅读排序），fire-and-forget。
    ref.read(contentRepoProvider).touchOpened(id).then((_) {
      ref.read(contentVersionProvider.notifier).state++;
    });
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ReaderPage(content: content)),
    );
  }

  static String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
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
      final bytes = file.bytes;
      if (ext == 'epub') {
        if (bytes == null) {
          if (context.mounted) _toast(context, 'epub 需要以字节方式读取，请重试');
          return;
        }
        await _importParsed(ref, ext, bytes);
      } else if (ext == 'srt' || ext == 'lrc') {
        final text = await _decodeText(file);
        if (text == null) {
          if (context.mounted) _toast(context, '文件读取失败');
          return;
        }
        await _importParsed(ref, ext, _encode(text));
      } else {
        final text = await _decodeText(file);
        if (text == null || text.trim().isEmpty) {
          if (context.mounted) _toast(context, '文件为空或读取失败');
          return;
        }
        final title = name.replaceAll(
          RegExp(r'\.(txt|md)$', caseSensitive: false),
          '',
        );
        final parsed = ContentParser.parsePlainText(text, defaultTitle: title);
        await _importParsed(
          ref,
          ext,
          _encode(parsed.plainText),
          title: parsed.defaultTitle,
        );
      }
      if (context.mounted) _toast(context, '已导入：$name');
    } catch (e) {
      if (context.mounted) _toast(context, '导入失败：$e');
    }
  }

  /// 解析 + 入库；失败返回 false（不弹二次提示）。
  Future<bool> _importParsed(
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

  static Uint8List _encode(String s) => Uint8List.fromList(utf8.encode(s));

  void _toast(BuildContext context, String msg) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _showContentActions(
    BuildContext context,
    WidgetRef ref,
    dynamic content,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.menu_book_outlined,
                  color: AppColors.inkMuted,
                ),
                title: const Text(
                  '打开阅读',
                  style: TextStyle(color: AppColors.ink),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openReader(context, ref, content);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.inkMuted,
                ),
                title: const Text('删除', style: TextStyle(color: AppColors.ink)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      title: const Text('删除这篇内容？'),
                      content: Text('“${content.title}” 将被移除'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dctx, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dctx, true),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    final repo = ref.read(contentRepoProvider);
                    await repo.delete(content.id as int);
                    ref.read(contentVersionProvider.notifier).state++;
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm2),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.sm2),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 18, color: AppColors.inkMuted),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '搜索标题 / 词 · 去查词',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
