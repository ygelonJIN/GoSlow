import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design/design.dart';
import '../../app/theme/fold_decoration.dart';
import '../../app/theme/mode_theme.dart';
import '../../data/dict/dict_providers.dart';
import '../../data/models/word_entry.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/entry_card.dart';
import '../../shared/exam_tag_picker.dart';
import '../../shared/feedback_dialog.dart';
import '../../shared/overlay_page.dart';
import '../../shared/review_size_picker.dart';
import '../../shared/section_header.dart';
import '../celebration/celebration_page.dart';
import '../favorite/favorite_page.dart';
import 'content_import.dart';
import 'paste_page.dart';
import 'reader_page.dart';
import 'review_session.dart';

class ContentPage extends ConsumerWidget {
  const ContentPage({super.key, this.searchQuery = ''});

  /// 主页底部输入条的实时关键词：非空时按标题 / 来源过滤「最近阅读」。
  final String searchQuery;

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
        final hasContents = contents.isNotEmpty;
        final q = searchQuery.trim().toLowerCase();
        final visible = q.isEmpty
            ? contents
            : contents
                  .where(
                    (c) =>
                        c.title.toLowerCase().contains(q) ||
                        c.displaySource.toLowerCase().contains(q),
                  )
                  .toList();
        return ListView(
          padding: EdgeInsets.only(
            top: AppOverlay.topInset(context),
            bottom: AppOverlay.bottomInset(context) + 96 + AppSpacing.xl,
          ),
          children: [
            if (hasContents)
              _ReviewFavoriteCard(
                onReview: () => pushContentReviewSession(context, ref),
                onFavorite: () => _openFavorite(context),
              ),
            if (!hasContents)
              const _ContentIntroCard()
            else ...[
              const SectionHeader('最近阅读'),
              if (visible.isEmpty)
                Padding(
                  padding: AppInsets.pageHorizontal,
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: AppInsets.card,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '没有找到匹配的内容',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: AppColors.ink),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '没有标题或来源包含“${searchQuery.trim()}”的内容；'
                            '如果是要查单词，直接用输入框搜索即可。',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.inkMuted,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                for (final c in visible)
                  EntryCard(
                    title: c.title,
                    subtitle: [
                      c.displaySource,
                      '${c.wordCount} 词',
                      _formatDate(c.createdAt),
                      if (c.isCompleted) '已学完',
                    ].join(' · '),
                    onTap: () => _openReader(context, ref, c),
                    trailing: _MoreButton(
                      onTap: () => _showContentActions(context, ref, c),
                    ),
                  ),
            ],
          ],
        );
      },
    );
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

  void _openFavorite(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const OverlayPage(
          title: '收藏',
          kicker: 'FAVORITE',
          child: FavoritePage(),
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  Future<void> _showContentActions(
    BuildContext context,
    WidgetRef ref,
    dynamic content,
  ) async {
    final entry = await ref.read(contentRepoProvider).byId(content.id as int);
    if (!context.mounted) return;
    final latest = entry ?? content;
    const mode = ModeThemes.theme1;
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
                  _openReader(context, ref, latest);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.inkMuted,
                ),
                title: Text(
                  latest.isCompleted ? '查看内容总结' : '标记为已学完',
                  style: const TextStyle(color: AppColors.ink),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final repo = ref.read(contentRepoProvider);
                  if (!latest.isCompleted) {
                    await repo.markCompleted(latest.id as int);
                    ref.read(contentVersionProvider.notifier).state++;
                  }
                  final refreshed = await repo.byId(latest.id as int) ?? latest;
                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CelebrationPage(content: refreshed),
                    ),
                  );
                },
              ),
              if (latest.isCompleted)
                ListTile(
                  leading: const Icon(
                    Icons.undo_outlined,
                    color: AppColors.inkMuted,
                  ),
                  title: const Text(
                    '取消已学完',
                    style: TextStyle(color: AppColors.ink),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final repo = ref.read(contentRepoProvider);
                    await repo.clearCompleted(latest.id as int);
                    ref.read(contentVersionProvider.notifier).state++;
                    if (context.mounted) {
                      FeedbackDialog.show(context, message: '已取消“已学完”标记');
                    }
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
                    message: '“${latest.title}” 将被移除',
                    confirmLabel: '删除',
                    icon: Icons.delete_outline,
                  );
                  if (ok) {
                    final repo = ref.read(contentRepoProvider);
                    await repo.delete(latest.id as int);
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

/// 顶部学习入口卡：内容词总览 + 复习/收藏 + 当前考纲 + 复习每轮张数。
class _ReviewFavoriteCard extends ConsumerWidget {
  const _ReviewFavoriteCard({
    required this.onReview,
    required this.onFavorite,
  });

  final VoidCallback onReview;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(contentWordsStatsProvider);
    final favCount = ref.watch(favoriteWordSetProvider).length;
    final currentTags = ref.watch(examTagProvider);
    final examLabel = currentTags.contains(kAllTag)
        ? '全部考纲'
        : currentTags.map((t) => kExamTagNames[t] ?? t).join(' / ');
    final reviewSettings = ref.watch(flashcardSettingsProvider);

    return Padding(
      padding: AppInsets.pageHorizontal.copyWith(bottom: AppSpacing.sm),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: AppInsets.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _Stat(label: '内容词', value: '${stats.total}')),
                  Container(
                    width: 1,
                    height: 24,
                    color: AppColors.line,
                  ),
                  Expanded(child: _Stat(label: '已认识', value: '${stats.known}')),
                  Container(
                    width: 1,
                    height: 24,
                    color: AppColors.line,
                  ),
                  Expanded(child: _Stat(label: '待复习', value: '${stats.review}')),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _ActionPillButton(
                      icon: Icons.replay_outlined,
                      label: '复习',
                      badge: stats.review,
                      filled: true,
                      onTap: onReview,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _ActionPillButton(
                      icon: Icons.star_outline,
                      label: '收藏',
                      badge: favCount,
                      onTap: onFavorite,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, color: AppColors.line),
              const SizedBox(height: AppSpacing.sm),
              _PickerRow(
                title: '当前考纲',
                value: examLabel,
                onTap: () async {
                  final picked = await showExamTagPicker(context, currentTags);
                  if (picked != null) {
                    ref.read(examTagProvider.notifier).state = picked;
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1, color: AppColors.line),
              const SizedBox(height: AppSpacing.sm),
              _PickerRow(
                title: '复习每轮张数',
                value: '${reviewSettings.sessionSize} 张',
                onTap: () async {
                  final picked = await showReviewSizePicker(
                    context,
                    reviewSettings.sessionSize,
                  );
                  if (picked != null) {
                    ref.read(flashcardSettingsProvider.notifier).state =
                        reviewSettings.copyWith(sessionSize: picked);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 卡片内的选择行：标题 + 尾部值胶囊 + 箭头（当前考纲 / 复习每轮张数共用）。
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.seedSoft,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: scheme.primary.withValues(alpha: 0.75),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.ink,
            fontSize: AppSpacing.statFontSize,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

/// 复习 / 收藏胶囊动作（选中态胶囊按钮：主色实底高亮态 / 普通态
/// chip 浅底 + 描边，badge 数字）。
class _ActionPillButton extends StatelessWidget {
  const _ActionPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    const mode = ModeThemes.theme1;
    final scheme = Theme.of(context).colorScheme;
    final fg = filled ? scheme.onPrimary : scheme.primary;
    return Material(
      color: filled ? scheme.primary : mode.chipBackground,
      shape: FoldShape(
        borderRadius: mode.chipRadius,
        side: BorderSide(
          color: filled ? scheme.primary : mode.chipBorder.withValues(alpha: 0.55),
          width: 1,
        ),
        fold: mode.cornerFold,
      ),
      elevation: filled ? 2 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pillHorizontal,
            vertical: AppSpacing.pillVertical,
          ),
          child: Row(
            children: [
              Icon(icon, size: AppSpacing.pillIcon, color: fg),
              const SizedBox(width: AppSpacing.pillGap),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppSpacing.pillFontSize,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              const Spacer(),
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: filled
                        ? scheme.onPrimary.withValues(alpha: 0.24)
                        : scheme.primary.withValues(alpha: AppColors.alphaIndicator),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '$badge',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
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
            onTap: () => pickContentFile(context, ref),
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
                    size: AppSpacing.cardIcon,
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
                '底部输入框可以直接查单词、搜标题；想添加阅读内容，'
                '点输入框右侧的「添加」按钮，粘贴文本或导入文件即可。',
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
                subtitle: '输入后按回车，支持变形词，离线可用',
              ),
              const SizedBox(height: AppSpacing.sm),
              const _IntroBullet(
                icon: Icons.add_rounded,
                title: '添加内容',
                subtitle: '点输入框右侧「添加」→ 粘贴文本或导入文件',
              ),
              const SizedBox(height: AppSpacing.sm),
              const _IntroBullet(
                icon: Icons.upload_file_outlined,
                title: '支持的文件',
                subtitle: 'txt / md / epub / srt / lrc',
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
                child: Icon(
                  icon,
                  size: AppSpacing.cardIcon,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
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

/// 内容项右侧「⋯」操作按钮：选中态胶囊样式（primary 淡底 + 描边），
/// 比旧 IconButton 更显著，视觉与全局 PillButton 同构。
class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const mode = ModeThemes.theme1;
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
