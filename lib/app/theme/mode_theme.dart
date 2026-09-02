import 'package:flutter/material.dart';

import 'fold_decoration.dart';

/// GoSlow 全局视觉体系 —— 暖纸底 + 草木绿主色 + 全圆角 + 霞鹜文楷。
///
/// 只保留一套主题：暖纸色背景 + 草木绿主色 + 全圆角 + 霞鹜文楷。
/// 所有页面（含未来新增页面、push 出来的路由）自动继承这套视觉风格。
/// 令牌结构与 SoWhat 完全一致，后续若需扩展其他主题可直接追加。
class ModeTheme {
  const ModeTheme({
    required this.background,
    required this.surface,
    required this.primary,
    required this.onPrimary,
    required this.mineBubble,
    required this.mineText,
    required this.text,
    required this.textMuted,
    required this.inputRadius,
    required this.cardRadius,
    required this.chipRadius,
    required this.cardBackground,
    required this.cardTitle,
    required this.cardBody,
    required this.cardMuted,
    required this.cardBorder,
    required this.cardShadowAlpha,
    required this.chipBackground,
    required this.chipForeground,
    required this.chipBorder,
    required this.actionChipBackground,
    required this.actionChipForeground,
    required this.actionChipBorder,
    required this.inputBorderColor,
    this.inputBorderWidth = 0,
    this.fontFamily,
    this.fontFamilyFallback = const <String>[],
    this.strongWeight = FontWeight.w700,
    this.cornerFold = false,
  });

  final Color background;
  final Color surface;
  final Color primary;
  final Color onPrimary;

  /// 「我」的消息气泡底色与文字色（保留令牌位，未来扩展用）。
  final Color mineBubble;
  final Color mineText;

  final Color text;
  final Color textMuted;

  /// 输入框圆角（全圆胶囊）。
  final BorderRadius inputRadius;

  /// 卡片圆角。
  final BorderRadius cardRadius;

  /// 浮动按钮 / 主按钮圆角。
  final BorderRadius chipRadius;

  /// 卡片色组。
  final Color cardBackground;
  final Color cardTitle;
  final Color cardBody;
  final Color cardMuted;
  final Color cardBorder;

  /// 卡片阴影强度。
  final double cardShadowAlpha;

  /// 通用胶囊按钮（未选中态）——已含透明度。
  final Color chipBackground;
  final Color chipForeground;

  /// 胶囊按钮边框色。
  final Color chipBorder;

  /// 主要操作芯片（发送 / 主按钮）。
  final Color actionChipBackground;
  final Color actionChipForeground;
  final Color actionChipBorder;

  final Color inputBorderColor;
  final double inputBorderWidth;

  /// 全局中文字体（霞鹜文楷，随 App 打包）。
  ///
  /// 全局生效：`themeData.fontFamily` 驱动所有文字（含空态、输入框、提示语）。
  final String? fontFamily;

  /// 主字体不可用时的回退字体族（按优先级）。
  final List<String> fontFamilyFallback;
  final FontWeight strongWeight;

  /// 是否为「切角·撕开一角」角型（GoSlow 恒为 false，全圆角）。
  ///
  /// 为 false 时，所有用到 [`FoldShape`]/[`CutBox`] 的地方退化为普通圆角矩形。
  final bool cornerFold;

  bool get isDark =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark;

  ThemeData get themeData {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          onPrimary: onPrimary,
          surface: surface,
          onSurface: text,
          onSurfaceVariant: textMuted,
          primaryContainer: mineBubble,
          onPrimaryContainer: mineText,
          secondaryContainer: mineBubble,
          onSecondaryContainer: mineText,
          outline: textMuted.withValues(alpha: 0.5),
          outlineVariant: textMuted.withValues(alpha: 0.25),
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: chipBackground,
        hintStyle: TextStyle(color: textMuted),
        border: ShapedInputBorder(
          shape: FoldShape(borderRadius: inputRadius, fold: cornerFold),
          borderSide: BorderSide.none,
        ),
        enabledBorder: ShapedInputBorder(
          shape: FoldShape(borderRadius: inputRadius, fold: cornerFold),
          borderSide: BorderSide.none,
        ),
        focusedBorder: ShapedInputBorder(
          shape: FoldShape(borderRadius: inputRadius, fold: cornerFold),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: FoldShape(borderRadius: cardRadius, fold: cornerFold),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.26),
        selectionHandleColor: primary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface,
        contentTextStyle: TextStyle(color: text),
        shape: FoldShape(
          borderRadius: chipRadius,
          fold: cornerFold,
          side: BorderSide(color: cardBorder, width: 1),
        ),
      ),
      dividerColor: textMuted.withValues(alpha: 0.25),
    );
  }
}

/// GoSlow 唯一预置主题。
abstract final class ModeThemes {
  /// 暖纸色 · 圆润 · 楷体（霞鹜文楷）。
  static const theme1 = ModeTheme(
    background: Color(0xFFFAF3E6),
    surface: Color(0xFFF1F7EC),
    primary: Color(0xFF4F7B49),
    onPrimary: Colors.white,
    mineBubble: Color(0xFF6B9E5A),
    mineText: Color(0xFFF8FBF6),
    text: Color(0xFF2F3A2A),
    textMuted: Color(0xFF6F7D68),
    inputRadius: BorderRadius.all(Radius.circular(999)),
    cardRadius: BorderRadius.all(Radius.circular(26)),
    chipRadius: BorderRadius.all(Radius.circular(999)),
    cardBackground: Color(0xFFF1F7EC),
    cardTitle: Color(0xFF4F7B49),
    cardBody: Color(0xFF2F3A2A),
    cardMuted: Color(0xFF5F7057),
    cardBorder: Color(0x5E4F7B49),
    cardShadowAlpha: 0.10,
    chipBackground: Color(0xEBF1F7EC),
    chipForeground: Color(0xBD2F3A2A),
    chipBorder: Color(0xFF6F7D68),
    actionChipBackground: Color(0xFF4F7B49),
    actionChipForeground: Color(0xFFFFFFFF),
    actionChipBorder: Color(0xFF4F7B49),
    inputBorderColor: Colors.transparent,
    inputBorderWidth: 0,
    fontFamily: 'LXGW WenKai',
    strongWeight: FontWeight.w700,
  );
}
