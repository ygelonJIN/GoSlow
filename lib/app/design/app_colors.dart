import 'package:flutter/material.dart';

/// 色彩 Token（Paper Editorial v2.0）。
/// 页面禁止直接写 Color(0x...)，统一引用此处。见 docs/design-spec.md §2。
abstract final class AppColors {
  static const Color seed = Color(0xFF3B6EA5);
  static const Color paper = Color(0xFFFAF8F5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1A1C1E);
  static const Color inkMuted = Color(0xFF8B8680);
  static const Color line = Color(0xFFEDE9E3);
  static const Color seedSoft = Color(0xFFE8EEF6);
  static const Color accent = Color(0xFFC9A96E);
  static const Color highlight = seed;

  // 纸感扩展位（暗色预留，预览 F Midnight 可作夜读参考）
  static const Color paperDark = Color(0xFF1A1A1C);

  // 允许的透明度档位（规范 §2.3）
  static const double alphaSubtle = 0.08;
  static const double alphaSoft = 0.10;
  static const double alphaIndicator = 0.12;
  static const double alphaHighlightBg = 0.13;
  static const double alphaHighlightBorder = 0.35;
  static const double alphaSurface = 0.50;
}
