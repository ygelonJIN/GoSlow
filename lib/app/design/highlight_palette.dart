import 'package:flutter/material.dart';

/// 多色高亮调色板，见 docs/design-spec.md §2.1。
/// 单色模式下全部回落到 AppColors.highlight。
abstract final class HighlightPalette {
  /// 考纲标签 → 柔和底色（用于高亮块背景）。
  static const Map<String, Color> multi = {
    'zk': Color(0xFF8FA7C8),
    'gk': Color(0xFF9DB5A0),
    'cet4': Color(0xFFD9B56A),
    'cet6': Color(0xFFD18B6A),
    'ky': Color(0xFF8E9BB5),
    'ielts': Color(0xFF7FB8A8),
    'toefl': Color(0xFFB89AC5),
    'gre': Color(0xFFC49A8A),
  };

  static Color forTag(String tag) => multi[tag] ?? const Color(0xFF8FA7C8);
}
