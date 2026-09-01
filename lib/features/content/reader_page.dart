import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design/design.dart';
import '../../data/dict/dict_providers.dart';
import '../../data/dict/highlight_engine.dart';
import '../../data/models/content_entry.dart';
import '../../data/parsers/parsed_content.dart';
import '../../data/providers/app_providers.dart';
import '../../shared/overlay_page.dart';
import 'widgets/highlighted_text.dart';
import 'widgets/word_sheet.dart';

class _Para {
  const _Para(this.text, this.start, this.end);
  final String text;
  final int start;
  final int end;
}

/// 阅读器：按段落渲染高亮文本，点词弹出底部释义面板。
///
/// - 高亮联动当前考纲 + 已认识过滤 + 单色/多色模式。
/// - 纯文本内容：全文一次性高亮得到全局偏移，再按段落切片。
/// - 结构化内容（M5）：epub 按章节渲染（标题 + 正文），
///   srt/lrc 按时间轴行渲染（时间标签 + 文本），分节内单独高亮。
class ReaderPage extends ConsumerWidget {
  const ReaderPage({super.key, required this.content});

  final ContentEntry content;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examTag = ref.watch(examTagProvider);
    final highlightMode = ref.watch(highlightModeProvider);
    final engineAsync = ref.watch(highlightEngineProvider);
    final knownWords = ref.watch(knownWordsProvider);

    return OverlayPage(
      title: content.title,
      kicker: content.displaySource,
      child: engineAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: AppInsets.card,
            child: Text('词库加载失败：$e', style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        data: (engine) {
          if (content.hasSections) {
            return _buildSections(context, ref, engine, examTag, highlightMode, knownWords);
          }
          return _buildPlain(context, ref, engine, examTag, highlightMode, knownWords);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 结构化内容（epub 章节 / srt·lrc 时间轴）
  // ---------------------------------------------------------------------

  Widget _buildSections(
    BuildContext context,
    WidgetRef ref,
    HighlightEngine engine,
    String examTag,
    HighlightMode highlightMode,
    Set<String> knownWords,
  ) {
    final timed = content.sections.any((s) => s.isTimed);
    final sections = content.sections;

    // 顶部信息条：分节类型 + 数量。
    final infoBar = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.seedSoft.withValues(alpha: AppColors.alphaSubtle),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Icon(
            timed ? Icons.closed_caption_outlined : Icons.menu_book_outlined,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            timed ? '${sections.length} 行 · 时间轴浏览' : '${sections.length} 章',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
          const Spacer(),
          Text(
            highlightMode == HighlightMode.multi ? '多色' : '单色',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppOverlay.topInset(context),
        AppSpacing.lg,
        AppOverlay.bottomInset(context) + AppSpacing.xl,
      ),
      children: [
        infoBar,
        const SizedBox(height: AppSpacing.md),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: AppInsets.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < sections.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.lg),
                  _SectionBlock(
                    section: sections[i],
                    timed: timed,
                    engine: engine,
                    examTag: examTag,
                    highlightMode: highlightMode,
                    knownWords: knownWords,
                    onTapSpan: (span) {
                      showWordSheet(context, ref, span);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '点亮色词查看释义 · 已标记“认识”的词不再高亮',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // 纯文本内容（粘贴 / txt / md）— 原段落渲染
  // ---------------------------------------------------------------------

  Widget _buildPlain(
    BuildContext context,
    WidgetRef ref,
    HighlightEngine engine,
    String examTag,
    HighlightMode highlightMode,
    Set<String> knownWords,
  ) {
    final paras = _splitWithOffsets(content.body);
    final globalSpans = engine.highlight(
      content.body,
      examTag: highlightMode == HighlightMode.single ? (examTag == 'all' ? null : examTag) : null,
    );
    final visibleSpans = globalSpans.where((s) => !knownWords.contains(s.entry.word.toLowerCase())).toList();
    final perPara = _sliceSpans(paras, visibleSpans);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppOverlay.topInset(context),
        AppSpacing.lg,
        AppOverlay.bottomInset(context) + AppSpacing.xl,
      ),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.seedSoft.withValues(alpha: AppColors.alphaSubtle),
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${paras.length} 段 · ${visibleSpans.length} 个考纲词已高亮',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
              const Spacer(),
              Text(
                highlightMode == HighlightMode.multi ? '多色' : '单色',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 10,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: AppInsets.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < paras.length; i++) ...[
                  HighlightedText(
                    text: paras[i].text,
                    spans: perPara[i],
                    highlightMode: highlightMode,
                    onTapSpan: (span) {
                      final global = HighlightSpan(
                        start: span.start + paras[i].start,
                        end: span.end + paras[i].start,
                        word: span.word,
                        entry: span.entry,
                      );
                      showWordSheet(context, ref, global);
                    },
                  ),
                  if (i != paras.length - 1) const SizedBox(height: AppSpacing.lg),
                ],
                if (paras.isEmpty)
                  Text(
                    content.body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.ink,
                          height: 26 / 14,
                          fontSize: 15,
                        ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          '点亮色词查看释义 · 已标记“认识”的词不再高亮',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
        ),
      ],
    );
  }

  static List<_Para> _splitWithOffsets(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return const [];
    final out = <_Para>[];
    var cursor = 0;
    while (cursor < body.length) {
      while (cursor < body.length && (body[cursor] == '\n' || body[cursor] == '\r')) {
        cursor++;
      }
      if (cursor >= body.length) break;
      var end = cursor;
      var blankStart = -1;
      for (var i = cursor; i < body.length; i++) {
        if (body[i] == '\n') {
          var j = i + 1;
          while (j < body.length && (body[j] == '\n' || body[j] == '\r' || body[j] == ' ')) {
            j++;
          }
          if (j > i + 1 || (j < body.length && body.substring(i, j).contains('\n\n'))) {
            blankStart = i;
            break;
          }
        }
      }
      if (blankStart != -1) {
        end = blankStart;
      } else {
        end = body.length;
      }
      final text = body.substring(cursor, end).trim();
      if (text.isNotEmpty) out.add(_Para(text, cursor, end));
      if (blankStart != -1) {
        cursor = blankStart;
        while (cursor < body.length && (body[cursor] == '\n' || body[cursor] == '\r')) {
          cursor++;
        }
      } else {
        break;
      }
    }
    if (out.isEmpty) return [_Para(trimmed, 0, body.length)];
    return out;
  }

  static List<List<HighlightSpan>> _sliceSpans(List<_Para> paras, List<HighlightSpan> global) {
    final perPara = List<List<HighlightSpan>>.generate(paras.length, (_) => []);
    for (final span in global) {
      for (var i = 0; i < paras.length; i++) {
        final p = paras[i];
        if (span.start >= p.start && span.end <= p.end) {
          perPara[i].add(HighlightSpan(
            start: span.start - p.start,
            end: span.end - p.start,
            word: span.word,
            entry: span.entry,
          ));
          break;
        }
        if (span.start >= p.start && span.start < p.end) {
          final localEnd = (span.end <= p.end ? span.end : p.end) - p.start;
          final localStart = span.start - p.start;
          if (localEnd > localStart) {
            perPara[i].add(HighlightSpan(
              start: localStart,
              end: localEnd,
              word: span.word,
              entry: span.entry,
            ));
          }
          break;
        }
      }
    }
    return perPara;
  }
}

/// 单个结构化分节：epub 章节（标题 + 正文）或 srt/lrc 时间轴行（时间标签 + 文本）。
class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.section,
    required this.timed,
    required this.engine,
    required this.examTag,
    required this.highlightMode,
    required this.knownWords,
    required this.onTapSpan,
  });

  final ContentSection section;
  final bool timed;
  final HighlightEngine engine;
  final String examTag;
  final HighlightMode highlightMode;
  final Set<String> knownWords;
  final ValueChanged<HighlightSpan> onTapSpan;

  @override
  Widget build(BuildContext context) {
    final text = section.text;
    if (text.trim().isEmpty) return const SizedBox.shrink();

    final spans = engine
        .highlight(
          text,
          examTag: highlightMode == HighlightMode.single ? (examTag == 'all' ? null : examTag) : null,
        )
        .where((s) => !knownWords.contains(s.entry.word.toLowerCase()))
        .toList();

    final isChapter = section.title != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isChapter) ...[
          Text(
            section.title!,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontSize: 17,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (timed) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.seedSoft.withValues(alpha: AppColors.alphaSubtle),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  section.timeLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 10,
                      ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: HighlightedText(
                  text: text,
                  spans: spans,
                  highlightMode: highlightMode,
                  onTapSpan: onTapSpan,
                ),
              ),
            ],
          ),
        ] else ...[
          HighlightedText(
            text: text,
            spans: spans,
            highlightMode: highlightMode,
            onTapSpan: onTapSpan,
          ),
        ],
      ],
    );
  }
}
