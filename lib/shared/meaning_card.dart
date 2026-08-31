import 'package:flutter/material.dart';

import '../app/design/design.dart';
import '../data/models/word_entry.dart';

/// 释义卡片 v2.1：单词 + 音标 + 按词性一行的中英文释义 + 考纲标签。
///
/// M1 查词结果；M2 起复用为“点高亮词 → 底部释义面板”主卡。
/// 中英文释义同构：每行一个词性（`n.` / `vt.` / `a.` …）前缀 + 释义，
/// 替代整块文本与蓝框（见 docs/design-spec.md §15.1）。
/// 英文释义默认只露出前 [kMaxEnLinesVisible] 条，其余折叠可展开。
const int kMaxEnLinesVisible = 2;

class MeaningCard extends StatefulWidget {
  const MeaningCard({
    super.key,
    required this.entry,
    this.showTags = true,
    this.leadingWord,
    this.onTap,
  });

  final WordEntry entry;
  final bool showTags;
  final String? leadingWord;
  final VoidCallback? onTap;

  @override
  State<MeaningCard> createState() => _MeaningCardState();
}

class _MeaningCardState extends State<MeaningCard> {
  bool _enUnfolded = false;

  @override
  void didUpdateWidget(covariant MeaningCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换词时（如闪卡连续翻面）重置英文释义的展开状态。
    if (oldWidget.entry.id != widget.entry.id) {
      _enUnfolded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final entry = widget.entry;
    final zhLines = parseMeaningLines(entry.translation);
    final enLines = parseMeaningLines(entry.definition);
    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: AppInsets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    entry.word,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (widget.leadingWord != null &&
                    widget.leadingWord != entry.word) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '← ${widget.leadingWord}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ],
            ),
            if (entry.phonetic.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                entry.phonetic,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                  height: 1.4,
                ),
              ),
            ],
            if (zhLines.isEmpty && enLines.isEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                '词库未收录释义',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
            ],
            if (zhLines.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              ..._buildLines(theme.textTheme, zhLines),
            ],
            if (enLines.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              ..._buildLines(
                theme.textTheme,
                _enUnfolded
                    ? enLines
                    : enLines.take(kMaxEnLinesVisible).toList(),
              ),
              if (enLines.length > kMaxEnLinesVisible) ...[
                const SizedBox(height: AppSpacing.xxs),
                _EnFoldControl(
                  hiddenCount: enLines.length - kMaxEnLinesVisible,
                  unfolded: _enUnfolded,
                  onTap: () => setState(() => _enUnfolded = !_enUnfolded),
                ),
              ],
            ],
            if (entry.hasExample) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.format_quote_outlined,
                      size: 14,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      entry.example,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.inkMuted,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (widget.showTags && entry.tags.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final tag in entry.tags)
                    Chip(
                      label: Text(
                        kExamTagNames[tag] ?? tag,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                      visualDensity: VisualDensity.compact,
                      backgroundColor:
                          scheme.primary.withValues(alpha: AppColors.alphaSubtle),
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    if (widget.onTap == null) return card;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: card,
    );
  }

  List<Widget> _buildLines(TextTheme theme, List<({String pos, String text})> lines) {
    return [
      for (var i = 0; i < lines.length; i++) ...[
        if (i > 0) const SizedBox(height: AppSpacing.xs),
        _MeaningLineRow(pos: lines[i].pos, text: lines[i].text, theme: theme),
      ],
    ];
  }
}

/// 识别行首英文词性前缀。支持复合词性（`vt.vi.`、`pron. & a.`）：
/// 连续出现的 `xx.`（可含 `&` 连接）整体作为词性，其后到行尾为释义。
final RegExp _posRunPattern = RegExp(
  r'^((?:[A-Za-z]+\.)(?:\s*&\s*[A-Za-z]+\.|\s*[A-Za-z]+\.)*)\s+(.*)$',
);

/// 英文释义（definition 列）的 WordNet / 旧词典缩写 → 中文习惯词性。
/// 仅映射到中文释义同款缩写，降低次要英英释义的噪音（`s.`→`a.` 等）。
const Map<String, String> _posAlias = {
  's.': 'a.', // adjective satellite（卫星形容词）
  'r.': 'adv.', // adverb（副词）
  'imp.': 'v.', // imperative
  'p.': 'v.', // past participle
  'p. pr. & vb. n.': 'v.',
  'superl.': 'a.', // superlative adjective
  'dv.': 'adv.',
};

/// 数据源存储的行分隔是字面的 `\n`（反斜杠 + n 两个字符，见 build_dict.py 原样
/// 写入 ECDICT 的 translation/definition）。这里统一转成真实换行再按行拆分；
/// 同时兼容已含真实换行或 `\r\n` 的情况。
String _decodeLineBreaks(String raw) => raw
    .replaceAll(r'\r\n', '\n')
    .replaceAll(r'\n', '\n')
    .replaceAll('\r\n', '\n');

/// 解析释义文本 → 词性行列表（每行 `(词性前缀, 释义)`）。
///
/// 数据源以 `\n` 分隔多行词义，每行形如 `n. 苹果, 家伙` / `vt.vi. (使)自动化`。
/// 无词性前缀的行（如 `[医] 苹果`、`run的过去式和过去分词`）整体作为释义
/// ——此时 `pos` 为空串，整行按释义正文渲染。
List<({String pos, String text})> parseMeaningLines(String raw) {
  final s = _decodeLineBreaks(raw);
  if (s.trim().isEmpty) return const [];
  final out = <({String pos, String text})>[];
  for (final line in s.split('\n')) {
    final l = line.trim();
    if (l.isEmpty) continue;
    final m = _posRunPattern.firstMatch(l);
    if (m != null) {
      final rawPos = m.group(1)!.trim();
      final pos = _posAlias[rawPos.toLowerCase()] ?? rawPos;
      out.add((pos: pos, text: m.group(2)!.trim()));
    } else {
      out.add((pos: '', text: l));
    }
  }
  return out;
}

class _MeaningLineRow extends StatelessWidget {
  const _MeaningLineRow({
    required this.pos,
    required this.text,
    required this.theme,
  });

  /// 词性前缀（如 `n.`），无词性时为空（整行当释义）。
  final String pos;
  final String text;
  final TextTheme theme;

  @override
  Widget build(BuildContext context) {
    if (pos.isEmpty) {
      return Text(
        text,
        style: theme.bodyMedium?.copyWith(color: AppColors.ink, height: 1.6),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44),
          child: Text(
            pos,
            style: theme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: theme.bodyMedium?.copyWith(color: AppColors.ink, height: 1.6),
          ),
        ),
      ],
    );
  }
}

/// 英文释义的「展开 / 收起」控制（仅当英文释义条数超过 [kMaxEnLinesVisible] 时出现）。
class _EnFoldControl extends StatelessWidget {
  const _EnFoldControl({
    required this.hiddenCount,
    required this.unfolded,
    required this.onTap,
  });

  /// 被折叠（未展开时）的英文释义条数。
  final int hiddenCount;
  final bool unfolded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              unfolded ? Icons.expand_less : Icons.expand_more,
              size: 16,
              color: scheme.primary,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              unfolded ? '收起英文释义' : '展开英文释义（$hiddenCount）',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
