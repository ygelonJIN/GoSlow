import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/design.dart';
import '../../../data/dict/dict_providers.dart';
import '../../../data/dict/highlight_engine.dart';
import '../../../data/models/word_entry.dart';
import '../../../data/providers/app_providers.dart';

/// 纸感高亮文本：把 [text] 按 [spans] 渲染为可点击的富文本。
///
/// - 非高亮：`ink` 15/26 正文，对齐阅读体验。
/// - 高亮：淡底 + 下划线，文字加粗；颜色按词条所属考纲取色——
///   单选考纲用该考纲的颜色，「全部」/多选时逐词按命中考纲取色，
///   支持用户在设置里自定义每个考纲对应的颜色。
class HighlightedText extends ConsumerWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.spans,
    required this.onTapSpan,
  });

  final String text;
  final List<HighlightSpan> spans;
  final ValueChanged<HighlightSpan> onTapSpan;

  /// 词条命中哪个当前考纲：单选时命中唯一选中的 tag；「全部」取词条首个 tag；
  /// 未命中任一选中考纲（全部模式下的无标签词）返回空串。
  String _tagFor(List<String> entryTags, Set<String> selection) {
    if (selection.contains(kAllTag)) {
      return entryTags.isNotEmpty ? entryTags.first : '';
    }
    for (final t in entryTags) {
      if (selection.contains(t)) return t;
    }
    return '';
  }

  Color _colorFor(
    HighlightSpan s,
    Set<String> selection,
    Map<String, Color> overrides,
  ) {
    final tag = _tagFor(s.entry.tags, selection);
    if (tag.isEmpty) return AppColors.highlight;
    return overrides[tag] ?? HighlightPalette.forTag(tag);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(examTagProvider);
    final overrides = ref.watch(highlightTagColorsProvider);
    if (text.isEmpty) return const SizedBox.shrink();
    if (spans.isEmpty) {
      return Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.ink,
              height:
                  AppSpacing.readingLineHeight / AppSpacing.readingFontSize,
              fontSize: AppSpacing.readingFontSize,
            ),
      );
    }

    final defaultStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.ink,
          height: AppSpacing.readingLineHeight / AppSpacing.readingFontSize,
          fontSize: AppSpacing.readingFontSize,
        );

    final children = <TextSpan>[];
    var cursor = 0;

    for (final span in spans) {
      if (span.start > cursor) {
        children.add(TextSpan(
          text: text.substring(cursor, span.start),
          style: defaultStyle,
        ));
      }
      final hlColor = _colorFor(span, selection, overrides);
      children.add(TextSpan(
        text: text.substring(span.start, span.end),
        style: defaultStyle?.copyWith(
          backgroundColor: hlColor.withValues(alpha: AppColors.alphaHighlightBg),
          decoration: TextDecoration.underline,
          decorationColor: hlColor.withValues(alpha: AppColors.alphaHighlightBorder),
          decorationThickness: 2,
          fontWeight: FontWeight.w700,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => onTapSpan(span),
      ));
      cursor = span.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor), style: defaultStyle));
    }

    return RichText(
      text: TextSpan(children: children),
      textAlign: TextAlign.left,
    );
  }
}
