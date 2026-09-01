import 'package:flutter/material.dart';

import 'design/design.dart';
import 'theme/fold_decoration.dart';
import 'theme/mode_theme.dart';

/// GoSlow 主题——唯一真相源（暖纸底 + 草木绿主色 + 全圆角）。
///
/// 全部颜色 / 圆角 / 阴影均由 `ModeThemes.love` 令牌驱动，
/// 页面层禁止出现 `Color(0x...)` / 裸数值。详见 `docs/design-spec.md`。
class AppTheme {
  AppTheme._();

  static ModeTheme get love => ModeThemes.love;
  static const Color seed = AppColors.seed;
  static const Color highlight = AppColors.highlight;

  static ThemeData light() {
    const mode = ModeThemes.love;
    final base = mode.themeData;
    final scheme = base.colorScheme;
    return base.copyWith(
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
      cardTheme: CardThemeData(
        // SoWhat 卡片语言：cardBackground 底 + cardBorder 绿描边 +
        // 柔和阴影。
        elevation: 2,
        color: AppColors.card,
        shadowColor: Colors.black.withValues(alpha: mode.cardShadowAlpha),
        surfaceTintColor: Colors.transparent,
        shape: FoldShape(
          borderRadius: mode.cardRadius,
          fold: mode.cornerFold,
          side: BorderSide(color: mode.cardBorder, width: 1),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: mode.actionChipBackground,
          foregroundColor: mode.actionChipForeground,
          disabledBackgroundColor: mode.actionChipBackground.withValues(
            alpha: 0.38,
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: FoldShape(
            borderRadius: mode.chipRadius,
            fold: mode.cornerFold,
            side: BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: mode.chipForeground,
          backgroundColor: mode.chipBackground,
          side: BorderSide(color: mode.chipBorder.withValues(alpha: 0.55)),
          shape: FoldShape(
            borderRadius: mode.chipRadius,
            fold: mode.cornerFold,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: mode.primary,
          shape: FoldShape(
            borderRadius: mode.chipRadius,
            fold: mode.cornerFold,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: FoldShape(
          borderRadius: mode.chipRadius,
          fold: mode.cornerFold,
        ),
        side: BorderSide.none,
        backgroundColor: mode.primary.withValues(alpha: AppColors.alphaSubtle),
        labelStyle: TextStyle(
          color: mode.primary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      ),
      inputDecorationTheme: InputDecorationTheme(
        // SoWhat 输入条语言：chipBackground 底 + chipBorder 55% 描边 + 全圆角。
        filled: true,
        fillColor: mode.chipBackground,
        hintStyle: TextStyle(color: mode.textMuted, fontSize: 13),
        prefixIconColor: mode.textMuted,
        suffixIconColor: mode.textMuted,
        border: OutlineInputBorder(
          borderRadius: mode.inputRadius,
          borderSide: BorderSide(
            color: mode.chipBorder.withValues(alpha: 0.55),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: mode.inputRadius,
          borderSide: BorderSide(
            color: mode.chipBorder.withValues(alpha: 0.55),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: mode.inputRadius,
          borderSide: BorderSide(color: mode.primary.withValues(alpha: 0.75)),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      ),
      dividerTheme: DividerThemeData(
        color: mode.textMuted.withValues(alpha: 0.25),
        space: 1,
        thickness: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return mode.primary;
          return mode.cardBackground;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return mode.primary.withValues(alpha: 0.35);
          }
          return AppColors.line;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (_) => Colors.transparent,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return mode.primary.withValues(alpha: 0.16);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return mode.primary;
            return mode.textMuted;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: mode.cardBorder, width: 1),
          ),
          shape: WidgetStatePropertyAll(
            FoldShape(
              borderRadius: mode.chipRadius,
              fold: mode.cornerFold,
            ),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: mode.primary,
        linearTrackColor: AppColors.line,
        circularTrackColor: AppColors.line,
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
