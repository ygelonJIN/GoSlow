import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design/design.dart';
import '../../data/models/word_entry.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/section_header.dart';
import '../celebration/celebration_page.dart';
import '../stats/stats_page.dart';

/// 设置面板的滚动内容（供 75% 宽度设置侧栏 [SettingsPanelFrame] 嵌入）。
///
/// 内容自上而下：学习（统计 / 掌握内容）→ 阅读（高亮颜色）→ 复习（自动朗读）
/// → 关于（数据备份 / GoSlow）。卡片统一主题一卡片语言（cardBackground 底 +
/// cardBorder 描边 + 全圆角 + 柔和投影），行内用主色图标瓷片；每张卡片只保留
/// 一行标题、不带简介——考纲选择与复习每轮张数已移入首页顶部学习入口卡。
class SettingsContent extends ConsumerWidget {
  const SettingsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    // 顶部 / 底部留白避让面板的上下渐变遮罩与浮层标题：
    // 顶 = 状态栏 + 80，底 = 安全区 + 150（与 IGotYou 侧栏模板一致）。
    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        mq.padding.top + AppSizes.settingsTopInset,
        0,
        mq.padding.bottom + AppSizes.settingsBottomInset,
      ),
      children: [
        const SectionHeader(
          '学习',
          padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
        ),
        _SettingRow(
          icon: Icons.bar_chart_outlined,
          title: '统计',
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const StatsPage()));
          },
        ),
        _SettingRow(
          icon: Icons.check_circle_outline,
          title: '掌握内容',
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ContentDonePage()));
          },
        ),
        const SectionHeader('阅读'),
        const _TagColorCard(),
        const SectionHeader('复习'),
        const _AutoSpeakCard(),
        const SectionHeader('关于'),
        const _SettingRow(
          icon: Icons.backup_outlined,
          title: '数据备份',
          enabled: false,
        ),
        const _SettingRow(
          icon: Icons.info_outline,
          title: 'GoSlow',
          trailing: null,
        ),
      ],
    );
  }
}

/// 设置行卡片：主色图标瓷片 + 一行标题 + 尾部箭头（无简介行）。
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    this.enabled = true,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final bool enabled;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: AppInsets.pageHorizontal.copyWith(
        top: AppSpacing.xxs,
        bottom: AppSpacing.xxs,
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 14,
          ),
          child: Row(
            children: [
              _IconTile(enabled: enabled, icon: icon),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: enabled ? AppColors.ink : AppColors.inkMuted,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              trailing ??
                  (enabled
                      ? Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: scheme.primary.withValues(alpha: 0.75),
                        )
                      : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

/// 行内主色图标瓷片（44 圆角方块：seedSoft 底 + 主色图标，SoWhat 瓷片语言）。
class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, this.enabled = true});

  final IconData icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.seedSoft
            : AppColors.line.withValues(alpha: AppColors.alphaSurface),
        borderRadius: BorderRadius.circular(AppRadius.sm2),
      ),
      child: Icon(
        icon,
        size: AppSpacing.cardIcon,
        color: enabled ? scheme.primary : AppColors.inkMuted,
      ),
    );
  }
}

/// 高亮颜色卡片：每个考纲一行（色点 + 名称），点击挑选该考纲对应的高亮颜色。
///
/// 单选考纲时全文用该考纲的颜色；「全部」/多选时每个考纲各用自己的颜色。
class _TagColorCard extends ConsumerWidget {
  const _TagColorCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrides = ref.watch(highlightTagColorsProvider);
    return Card(
      margin: AppInsets.pageHorizontal.copyWith(
        top: AppSpacing.xxs,
        bottom: AppSpacing.xxs,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _IconTile(icon: Icons.palette_outlined),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    '高亮颜色',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < kExamTags.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.line),
              InkWell(
                onTap: () => _pickColor(context, ref, kExamTags[i]),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: overrides[kExamTags[i]] ??
                              HighlightPalette.forTag(kExamTags[i]),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.line,
                            width: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          examTagName(kExamTags[i]),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.ink),
                        ),
                      ),
                      Icon(
                        overrides.containsKey(kExamTags[i])
                            ? Icons.tune
                            : Icons.chevron_right,
                        size: 18,
                        color: AppColors.inkMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickColor(
    BuildContext context,
    WidgetRef ref,
    String tag,
  ) async {
    final overrides = ref.read(highlightTagColorsProvider);
    final current = overrides[tag] ?? HighlightPalette.forTag(tag);

    final picked = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ColorSheet(
        tagName: examTagName(tag),
        current: current,
        customized: overrides.containsKey(tag),
      ),
    );
    if (picked == null || !context.mounted) return;

    final updated = {...overrides};
    if (picked == _kResetColor) {
      updated.remove(tag);
    } else {
      updated[tag] = picked as Color;
    }
    ref.read(highlightTagColorsProvider.notifier).state = updated;
  }
}

/// 还原默认颜色标记（点它移除自定义，回落 [HighlightPalette] 默认色）。
const Object _kResetColor = Object();

/// 颜色挑选底部面板：当前色预览 + 候选色板（[HighlightPalette.choices]）+ 还原默认。
class _ColorSheet extends StatelessWidget {
  const _ColorSheet({
    required this.tagName,
    required this.current,
    required this.customized,
  });

  final String tagName;
  final Color current;
  final bool customized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: AppInsets.pageHorizontal.copyWith(bottom: 8),
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: current,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    '$tagName 的高亮颜色',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final c in HighlightPalette.choices)
                  _ColorDot(
                    color: c,
                    selected: c == current && customized,
                    onTap: () => Navigator.of(context).pop(c),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: customized
                    ? () => Navigator.of(context).pop(_kResetColor)
                    : null,
                icon: Icon(
                  Icons.restart_alt,
                  size: 18,
                  color: customized
                      ? scheme.primary
                      : AppColors.inkMuted.withValues(alpha: 0.5),
                ),
                label: Text(
                  '还原默认',
                  style: TextStyle(
                    color: customized
                        ? scheme.primary
                        : AppColors.inkMuted.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 候选色圆点（选中：描边 + 对勾）。
class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : AppColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 18, color: Colors.white)
            : null,
      ),
    );
  }
}

/// 复习设置卡片：自动朗读（翻开新卡时自动读单词）开关。
class _AutoSpeakCard extends ConsumerWidget {
  const _AutoSpeakCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(flashcardSettingsProvider);
    return Card(
      margin: AppInsets.pageHorizontal.copyWith(
        top: AppSpacing.xxs,
        bottom: AppSpacing.xxs,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 8,
        ),
        child: Row(
          children: [
            const _IconTile(icon: Icons.record_voice_over_outlined),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                '自动朗读',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Switch(
              value: settings.autoSpeak,
              onChanged: (v) {
                ref.read(flashcardSettingsProvider.notifier).state =
                    settings.copyWith(autoSpeak: v);
              },
            ),
          ],
        ),
      ),
    );
  }
}