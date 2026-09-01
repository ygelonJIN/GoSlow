import 'package:flutter/material.dart';

/// 色彩 Token —— 全局主题色板。
/// 页面禁止直接写 Color(0x...)，统一引用此处或 `ModeThemes.love`。
abstract final class AppColors {
  static const Color seed = Color(0xFF4F7B49);
  static const Color paper = Color(0xFFFAF3E6);
  static const Color card = Color(0xFFF1F7EC);
  static const Color ink = Color(0xFF2F3A2A);
  static const Color inkMuted = Color(0xFF6F7D68);
  static const Color line = Color(0xFFDCE6D3);
  static const Color seedSoft = Color(0xFFE7F0E0);
  static const Color accent = Color(0xFFC9A96E);
  static const Color highlight = seed;

  // 纸感扩展位（暗色预留，预览 F Midnight 可作夜读参考）
  static const Color paperDark = Color(0xFF1A1A1C);

  // 允许的透明度档位
  static const double alphaSubtle = 0.08;
  static const double alphaSoft = 0.10;
  static const double alphaIndicator = 0.12;
  static const double alphaHighlightBg = 0.13;
  static const double alphaHighlightBorder = 0.35;
  static const double alphaSurface = 0.50;
}
