import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tokens.dart';

/// Theme builder — single entry point for Material 3 theming.
///
/// TickTick-inspired clean aesthetic: soft blues, generous whitespace,
/// understated surfaces. Light/dark modes share the same seed.
abstract final class AppTheme {
  /// 获取各平台的原生首选字体族（系统默认字体）。
  /// - Windows: 'Microsoft YaHei UI'（微软雅黑 UI 版，解决等线/宋体回退毛刺与字重不一）
  /// - macOS / iOS: 'PingFang SC'（苹方）
  /// - Linux: 'Noto Sans CJK SC'（思源黑体）
  /// - Android: null（自动匹配系统 Roboto + Noto Sans）
  static String? get _defaultFontFamily {
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows => 'Microsoft YaHei UI',
      TargetPlatform.macOS || TargetPlatform.iOS => 'PingFang SC',
      TargetPlatform.linux => 'Noto Sans CJK SC',
      _ => null,
    };
  }

  /// 全平台字体回退链，彻底解决中英文/数字混排时字体回退割裂与粗细不一问题。
  static const List<String> _fontFamilyFallback = [
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'PingFang SC',
    'Noto Sans CJK SC',
    'Noto Sans SC',
    'WenQuanYi Micro Hei',
    'Segoe UI',
    'sans-serif',
  ];

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
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: _defaultFontFamily,
      fontFamilyFallback: _fontFamilyFallback,
    );

    return base.copyWith(
      // ── Scaffold background ──
      // 页面基底：浅灰底 + 白卡片层次（55-ui-redesign-proposal.md §5 surfacePage）。
      scaffoldBackgroundColor: isDark
          ? AppTokens.surfacePageDark
          : AppTokens.surfacePageLight,

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        // 状态栏图标明暗（用户反馈：顶部时间/wifi/信号/电量看不清）：
        // AppBar 背景为透明，Flutter 按透明（luminance=0）误判为深色 → 默认
        // 浅色图标，落在浅色页面底（surfacePageLight）上几乎不可见。
        // 按主题明暗显式指定：浅色主题用深色图标、深色主题用浅色图标。
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontFamily: _defaultFontFamily,
          fontFamilyFallback: _fontFamilyFallback,
          fontSize: AppTokens.textHeadingSize,
          fontWeight: AppTokens.textHeadingWeight,
          color: colorScheme.onSurface,
        ),
      ),

      // ── Card ──
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          side: BorderSide(
            color: isDark
                ? AppTokens.borderSubtleDark
                : AppTokens.borderSubtleLight,
            width: 1,
          ),
        ),
        // Linear 风格：浅色纯白，深色碳黑浮层容器。
        color: isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCard,
      ),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
          side: BorderSide(
            color: isDark
                ? AppTokens.borderSubtleDark
                : AppTokens.borderSubtleLight,
            width: 1,
          ),
        ),
      ),

      // ── Chip ──
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusChip),
          side: BorderSide(
            color: isDark
                ? AppTokens.borderSubtleDark
                : AppTokens.borderSubtleLight,
            width: 0.5,
          ),
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
        // 输入井 = 凹陷面：比页面底更沉一档的内嵌区域（66 §3）。
        fillColor: isDark
            ? AppTokens.surfaceSunkenDark
            : AppTokens.surfaceSunkenLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          borderSide: BorderSide(
            color: isDark
                ? AppTokens.borderSubtleDark
                : AppTokens.borderSubtleLight,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          borderSide: BorderSide(
            color: isDark
                ? AppTokens.borderSubtleDark
                : AppTokens.borderSubtleLight,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          borderSide: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
          vertical: AppTokens.spaceSm,
        ),
      ),

      // ── SegmentedButton ──
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusChip),
            ),
          ),
          side: WidgetStateProperty.resolveWith((states) {
            return BorderSide(
              color: isDark
                  ? AppTokens.borderSubtleDark
                  : AppTokens.borderSubtleLight,
              width: 1,
            );
          }),
        ),
      ),

      // ── PopupMenu ──
      popupMenuTheme: PopupMenuThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          side: BorderSide(
            color: isDark
                ? AppTokens.borderSubtleDark
                : AppTokens.borderSubtleLight,
            width: 1,
          ),
        ),
        color: isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCard,
        // 去 M3 表面染色：菜单底色精确等于卡片色，与主体卡片层次一致。
        surfaceTintColor: Colors.transparent,
        // 菜单项文本用 bodyMedium（M3 默认 bodyLarge 16 偏大，与紧凑行不协调）。
        labelTextStyle: WidgetStatePropertyAll(base.textTheme.bodyMedium),
        // 紧凑化：容器上下内边距 4（M3 默认 8），配合 menuItemHeight 40。
        menuPadding: const EdgeInsets.symmetric(vertical: AppTokens.spaceXxs),
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
          side: BorderSide(
            color: isDark
                ? AppTokens.borderSubtleDark
                : AppTokens.borderSubtleLight,
            width: 1,
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
        // 宽屏 Rail 加宽 80 → 96（55-ui-redesign-proposal.md §3.2）。
        minWidth: AppTokens.railWidth,
        // 选中态药丸高亮：浅色容器 + 圆角（colorScheme 派生，不硬编码）。
        indicatorColor: colorScheme.secondaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        ),
        labelType: NavigationRailLabelType.all,
      ),

      // ── Checkbox ──
      // Linear / Things 风格圆形复选框：完成 = onSurfaceVariant 中性灰填充 + 白勾；
      // 禁用（有子任务，状态派生）= 浅灰填充。shape 走 AppTokens。
      checkboxTheme: CheckboxThemeData(
        shape: AppTokens.checkboxShape,
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BorderSide(color: colorScheme.onSurfaceVariant, width: 1.5);
          }
          return BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.28)
                : colorScheme.outline.withValues(alpha: 0.45),
            width: 1.5,
          );
        }),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            // 完成 = 中性灰填充（onSurfaceVariant，与完成态标题文字同色，
            // 用户评审 2026-08：不再用主题色填充）+ 白勾。
            return colorScheme.onSurfaceVariant;
          }
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.15);
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppTokens.colorOnCheck
              : Colors.transparent,
        ),
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        thickness: 0.5,
        color: isDark
            ? AppTokens.borderSubtleDark
            : AppTokens.borderSubtleLight,
        space: 1,
      ),

      // ── Typography ──
      textTheme: base.textTheme
          .apply(
            fontFamily: _defaultFontFamily,
            fontFamilyFallback: _fontFamilyFallback,
          )
          .copyWith(
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
              height: AppTokens.textBodyHeight,
            ),
            bodyMedium: base.textTheme.bodyMedium?.copyWith(
              fontSize: AppTokens.textBodySize,
              fontWeight: AppTokens.textBodyWeight,
              height: AppTokens.textBodyHeight,
            ),
            bodySmall: base.textTheme.bodySmall?.copyWith(
              fontSize: AppTokens.textCaptionSize,
              fontWeight: AppTokens.textCaptionWeight,
              height: AppTokens.textCaptionHeight,
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
