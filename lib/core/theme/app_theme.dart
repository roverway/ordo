import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// 主题构建唯一入口（50-ui-ux.md §3，20-tech-stack.md §3）。
///
/// Material 3 基底 + ColorScheme.fromSeed，明/暗两套由种子色派生；
/// 圆角/字体等设计令牌在此统一接入 ThemeData。
abstract final class AppTheme {
  /// 按模式构建主题。
  ///
  /// - [ThemeMode.light] / [ThemeMode.dark]：直接生成对应亮度主题；
  /// - [ThemeMode.system]：解析为平台当前亮度。
  ///
  /// 应用层通常分别构建 light/dark 两套并交给 MaterialApp 的
  /// `theme` / `darkTheme` + `themeMode`，以获得系统模式实时跟随。
  static ThemeData build(
    ThemeMode mode, {
    Color seedColor = AppTokens.seedColor,
  }) {
    final brightness = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    return _build(brightness, seedColor);
  }

  static ThemeData _build(Brightness brightness, Color seedColor) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);

    return base.copyWith(
      // 圆角令牌（50-ui-ux.md §2.2）
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusChip),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusList),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusButton),
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
      // 字体令牌（50-ui-ux.md §2.4）
      textTheme: base.textTheme.copyWith(
        displayLarge: base.textTheme.displayLarge?.copyWith(
          fontSize: AppTokens.textDisplaySize,
          fontWeight: AppTokens.textDisplayWeight,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: AppTokens.textTitleSize,
          fontWeight: AppTokens.textTitleWeight,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: AppTokens.textBodySize,
          fontWeight: AppTokens.textBodyWeight,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          fontSize: AppTokens.textCaptionSize,
          fontWeight: AppTokens.textCaptionWeight,
        ),
      ),
    );
  }
}
