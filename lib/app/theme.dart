import 'package:flutter/material.dart';

import 'design/design.dart';

/// GoSlow 主题——唯一真相源（Paper Editorial v2.0）。
///
/// 全部颜色 / 间距 / 圆角 / 阴影均引用 `lib/app/design` 的 Token，
/// 详见 `docs/design-spec.md`。页面层禁止出现 `Color(0x...)` / 裸数值。
class AppTheme {
  AppTheme._();

  static const Color seed = AppColors.seed;
  static const Color highlight = AppColors.highlight;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.paper,
      textTheme: _textTheme(scheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: AppElevation.level0,
        scrolledUnderElevation: AppElevation.level0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          letterSpacing: -0.3,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        // 透明背景：底部导航作为浮层直接压在渐隐遮罩之上。
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(
          alpha: AppColors.alphaIndicator,
        ),
        elevation: AppElevation.level0,
        height: AppSpacing.navHeight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 10,
            letterSpacing: 0.06 * 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.primary : AppColors.inkMuted,
          );
        }),
      ),
      cardTheme: CardThemeData(
        elevation: AppElevation.level0,
        color: AppColors.card,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.line),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: 14,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        side: BorderSide.none,
        backgroundColor: scheme.primary.withValues(
          alpha: AppColors.alphaSubtle,
        ),
        labelStyle: TextStyle(
          color: scheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        hintStyle: const TextStyle(color: AppColors.inkMuted, fontSize: 13),
        prefixIconColor: AppColors.inkMuted,
        suffixIconColor: AppColors.inkMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm2),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm2),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm2),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.35)),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        space: 1,
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: AppInsets.listTile,
      ),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    const ink = AppColors.ink;
    const muted = AppColors.inkMuted;
    return TextTheme(
      headlineMedium: const TextStyle(
        fontSize: 28,
        height: 32 / 28,
        fontWeight: FontWeight.w700,
        color: ink,
        letterSpacing: -0.5,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: ink,
        letterSpacing: -0.3,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        height: 22 / 16,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyLarge: TextStyle(
        fontSize: 14,
        height: 21 / 14,
        fontWeight: FontWeight.w400,
        color: scheme.primary,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        height: 21 / 14,
        fontWeight: FontWeight.w400,
        color: ink,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        height: 18 / 12,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      labelLarge: const TextStyle(
        fontSize: 13,
        height: 16 / 13,
        fontWeight: FontWeight.w600,
        color: muted,
        letterSpacing: 0.08 * 13,
      ),
      labelSmall: const TextStyle(
        fontSize: 11,
        height: 14 / 11,
        fontWeight: FontWeight.w500,
        color: muted,
        letterSpacing: 0.04 * 11,
      ),
    );
  }
}
