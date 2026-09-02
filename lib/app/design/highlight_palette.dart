import 'package:flutter/material.dart';

/// 多色高亮调色板，见 docs/design-spec.md §2.1。
/// 单选考纲时用该考纲对应的颜色；「全部」/多选时按词条考纲逐词取色。
abstract final class HighlightPalette {
  /// 考纲标签 → 默认柔和底色（用于高亮块背景）。
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

  /// 自定义高亮颜色时的候选色板（含默认 8 色 + 柔和扩展色）。
  static const List<Color> choices = [
    Color(0xFF8FA7C8), // 灰蓝
    Color(0xFF9DB5A0), // 草绿
    Color(0xFFD9B56A), // 金黄
    Color(0xFFD18B6A), // 橘棕
    Color(0xFF8E9BB5), // 黛蓝
    Color(0xFF7FB8A8), // 青碧
    Color(0xFFB89AC5), // 葡萄紫
    Color(0xFFC49A8A), // 赭石
    Color(0xFFE3B4BF), // 樱粉
    Color(0xFFA8C7D9), // 天蓝
    Color(0xFFC9C17E), // 橄榄
    Color(0xFFB0A8D9), // 香芋紫
    Color(0xFF7CC0AE), // 薄荷
    Color(0xFFD9A66A), // 蜜橘
    Color(0xFFA9BFA0), // 灰绿
    Color(0xFFC78FA8), // 玫粉
  ];
}
