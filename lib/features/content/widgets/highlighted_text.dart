import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../app/design/design.dart';
import '../../../data/dict/highlight_engine.dart';
import '../../../data/dict/dict_providers.dart';

/// 纸感高亮文本：把 [text] 按 [spans] 渲染为可点击的富文本。
///
/// - 非高亮：`ink` 15/26 正文，对齐阅读体验。
/// - 高亮：`highlightBg 0.13` 淡底 + `highlightBorder 0.35` 下划线，文字加粗。
/// - 多色模式下按词条首个 tag 取 [HighlightPalette] 底色。
class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.spans,
    required this.onTapSpan,
    this.highlightMode = HighlightMode.single,
  });

  final String text;
  final List<HighlightSpan> spans;
  final ValueChanged<HighlightSpan> onTapSpan;
  final HighlightMode highlightMode;

  Color _bgFor(HighlightSpan s) {
    if (highlightMode == HighlightMode.single) {
      return AppColors.highlight.withValues(alpha: AppColors.alphaHighlightBg);
    }
    final tag = s.entry.tags.isNotEmpty ? s.entry.tags.first : 'zk';
    return HighlightPalette.forTag(tag).withValues(alpha: AppColors.alphaHighlightBg);
  }

  Color _borderFor(HighlightSpan s) {
    if (highlightMode == HighlightMode.single) {
      return AppColors.highlight.withValues(alpha: AppColors.alphaHighlightBorder);
    }
    final tag = s.entry.tags.isNotEmpty ? s.entry.tags.first : 'zk';
    return HighlightPalette.forTag(tag).withValues(alpha: AppColors.alphaHighlightBorder);
  }

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    if (spans.isEmpty) {
      return Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.ink,
              height: 26 / 14,
              fontSize: 15,
            ),
      );
    }

    final defaultStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.ink,
          height: 26 / 14,
          fontSize: 15,
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
      final bg = _bgFor(span);
      final border = _borderFor(span);
      children.add(TextSpan(
        text: text.substring(span.start, span.end),
        style: defaultStyle?.copyWith(
          backgroundColor: bg,
          decoration: TextDecoration.underline,
          decorationColor: border,
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
