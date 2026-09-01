import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design/design.dart';
import '../../app/theme/fold_decoration.dart';
import '../../app/theme/mode_theme.dart';
import '../../data/parsers/content_parser.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/entry_card.dart';
import '../../shared/feedback_dialog.dart';
import '../../shared/overlay_page.dart';
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
            bottom: AppOverlay.bottomInset(context) + 96 + AppSpacing.xl,
          ),
          children: [
            Padding(
              padding: AppInsets.pageHorizontal.copyWith(bottom: AppSpacing.md),
              child: _SearchField(onTap: () => _openLookup(context)),
            ),
            if (contents.isEmpty) ...[
              const _ContentIntroCard(),
            ] else ...[
              const SectionHeader('最近阅读'),
              for (final c in contents)
                EntryCard(
                  title: c.title,
                  subtitle:
                      '${c.displaySource} · ${c.wordCount} 词 · ${_formatDate(c.createdAt)}',
                  onTap: () => _openReader(context, ref, c),
                  trailing: _MoreButton(
                    onTap: () => _showContentActions(context, ref, c),
                  ),
                ),
              const SectionHeader('添加内容'),
              _AddMethodCard(
                icon: Icons.search,
                title: '查单词',
                subtitle: '精确查询 + 词形还原（got → get），离线可用',
                onTap: () => _openLookup(context),
              ),
              _AddMethodCard(
                icon: Icons.assignment_outlined,
                title: '粘贴文本',
                subtitle: '任意段落，一键高亮',
                onTap: () => _openPaste(context),
              ),
              _AddMethodCard(
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
                      const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: AppColors.inkMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
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
    await _pickContentFile(context, ref);
  }

  Future<void> _showContentActions(
    BuildContext context,
    WidgetRef ref,
    dynamic content,
  ) async {
    const mode = ModeThemes.love;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CutBox(
        fold: mode.cornerFold,
        color: mode.cardBackground,
        borderRadius: BorderRadius.vertical(top: mode.cardRadius.topLeft),
        border: Border.all(color: mode.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
        child: SafeArea(
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
                  final ok = await confirmDialog(
                    context,
                    title: '删除这篇内容？',
                    message: '“${content.title}” 将被移除',
                    confirmLabel: '删除',
                    icon: Icons.delete_outline,
                  );
                  if (ok) {
                    final repo = ref.read(contentRepoProvider);
                    await repo.delete(content.id as int);
                    ref.read(contentVersionProvider.notifier).state++;
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class ContentImportPage extends ConsumerWidget {
  const ContentImportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OverlayPage(
      title: '添加内容',
      kicker: 'CONTENT',
      child: ListView(
        padding: EdgeInsets.only(
          top: AppOverlay.topInset(context),
          bottom: AppOverlay.bottomInset(context) + AppSpacing.xl,
        ),
        children: [
          Padding(
            padding: AppInsets.pageHorizontal.copyWith(bottom: AppSpacing.md),
            child: const _ImportIntroCard(),
          ),
          _AddMethodCard(
            icon: Icons.assignment_outlined,
            title: '粘贴文本',
            subtitle: '把英文段落粘贴进来，保存后自动进入阅读',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PastePage()),
              );
            },
          ),
          _AddMethodCard(
            icon: Icons.upload_file_outlined,
            title: '导入文件',
            subtitle: '.txt / .md / .epub / .srt / .lrc',
            onTap: () => _pickContentFile(context, ref),
          ),
        ],
      ),
    );
  }
}

/// 「选择一种添加方式」介绍卡：图标瓷片 + 标题 + 说明。
class _ImportIntroCard extends StatelessWidget {
  const _ImportIntroCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.seedSoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.add_circle_outline,
                    size: 21,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    '选择一种添加方式',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: AppColors.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '你可以先粘贴一段英文，也可以直接导入文件。导入后会自动识别并高亮里面的考纲词。',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.inkMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentIntroCard extends StatelessWidget {
  const _ContentIntroCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppInsets.pageHorizontal,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: AppInsets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '从这里开始',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '输入框可以直接查单词；也可以粘贴文本或导入文件，自动找出里面的考纲词，把它们变成可阅读、可复习的内容。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkMuted,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const _IntroBullet(
                icon: Icons.search,
                title: '查单词',
                subtitle: '支持变形词，离线可用',
              ),
              const SizedBox(height: AppSpacing.sm),
              const _IntroBullet(
                icon: Icons.assignment_outlined,
                title: '粘贴文本',
                subtitle: '把一段英文直接贴进来',
              ),
              const SizedBox(height: AppSpacing.sm),
              const _IntroBullet(
                icon: Icons.upload_file_outlined,
                title: '导入文件',
                subtitle: '支持 txt / md / epub / srt / lrc',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 添加方式卡片（内容页 / 添加页共用）：图标瓷片 + 标题 + 副标题 + 箭头。
class _AddMethodCard extends StatelessWidget {
  const _AddMethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
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
                child: Icon(icon, size: 22, color: scheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: AppColors.ink, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroBullet extends StatelessWidget {
  const _IntroBullet({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.seedSoft,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _pickContentFile(BuildContext context, WidgetRef ref) async {
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

Future<bool> _importParsed(
  WidgetRef ref,
  String sourceType,
  List<int> bytes, {
  String? title,
}) async {
  final data = Uint8List.fromList(bytes);
  final parsed = sourceType == 'epub' || sourceType == 'srt' || sourceType == 'lrc'
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

void _toast(BuildContext context, String msg, {IconData icon = Icons.info_outline}) {
  if (context.mounted) {
    FeedbackDialog.show(context, message: msg, icon: icon);
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const mode = ModeThemes.love;
    return Material(
      color: mode.chipBackground,
      shape: FoldShape(
        borderRadius: mode.inputRadius,
        side: BorderSide(
          color: mode.chipBorder.withValues(alpha: 0.55),
          width: 1,
        ),
        fold: mode.cornerFold,
      ),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: mode.cornerFold ? null : mode.inputRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 18,
                color: mode.chipForeground.withValues(alpha: 0.75),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '搜索标题 / 词 · 去查词',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 内容项右侧「⋯」操作按钮：选中态胶囊样式（primary 淡底 + 描边），
/// 比旧 IconButton 更显著，视觉与全局 PillButton 同构。
class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const mode = ModeThemes.love;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: 0.16),
      shape: FoldShape(
        borderRadius: mode.chipRadius,
        side: BorderSide(
          color: scheme.primary.withValues(alpha: 0.30),
          width: 1,
        ),
        fold: mode.cornerFold,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          child: Icon(
            Icons.more_horiz,
            size: 20,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }
}
