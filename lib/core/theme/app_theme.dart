import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Theme builder — single entry point for Material 3 theming.
///
/// TickTick-inspired clean aesthetic: soft blues, generous whitespace,
/// understated surfaces. Light/dark modes share the same seed.
abstract final class AppTheme {
  /// Build theme for a given brightness.
  ///
  /// App layer calls this twice (brightness light + dark) and passes both
  /// to MaterialApp.router's `theme` / `darkTheme` along with `themeMode`.
  static ThemeData build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppTokens.seedColor,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);

    return base.copyWith(
      // ── Scaffold background ──
      scaffoldBackgroundColor: isDark ? AppTokens.bgTintDark : AppTokens.bgTint,

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          fontSize: AppTokens.textHeadingSize,
          fontWeight: AppTokens.textHeadingWeight,
          color: colorScheme.onSurface,
        ),
      ),

      // ── Card ──
      cardTheme: CardThemeData(
        elevation: AppTokens.elevationCard,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        ),
        color: colorScheme.surface,
      ),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
        ),
      ),

      // ── Chip ──
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceSm,
          vertical: AppTokens.spaceXs,
        ),
      ),

      // ── ListTile ──
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusList),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
        ),
        minLeadingWidth: AppTokens.spaceMd,
      ),

      // ── Input Decoration ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
          vertical: AppTokens.spaceSm,
        ),
      ),

      // ── Buttons ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceXl,
            vertical: AppTokens.spaceSm,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          ),
        ),
      ),

      // ── FAB ──
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: AppTokens.elevationFab,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        ),
      ),

      // ── NavigationBar ──
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0.5,
        backgroundColor: colorScheme.surface,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      // ── NavigationRail ──
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        ),
        labelType: NavigationRailLabelType.all,
      ),

      // ── Checkbox ──
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusCheckbox),
        ),
        side: BorderSide(color: colorScheme.outline, width: 1.5),
        visualDensity: VisualDensity.compact,
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        thickness: 0.5,
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
      ),

      // ── Typography ──
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontSize: AppTokens.textHeadingSize,
          fontWeight: AppTokens.textHeadingWeight,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: AppTokens.textTitleSize,
          fontWeight: AppTokens.textTitleWeight,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: AppTokens.textBodySize,
          fontWeight: AppTokens.textBodyWeight,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: AppTokens.textBodySize,
          fontWeight: AppTokens.textBodyWeight,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          fontSize: AppTokens.textCaptionSize,
          fontWeight: AppTokens.textCaptionWeight,
        ),
      ),

      // ── SnackBar ──
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        ),
      ),
    );
  }
}
