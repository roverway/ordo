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
      TargetPlatform.windows => 'Segoe UI',
      TargetPlatform.macOS || TargetPlatform.iOS => 'PingFang SC',
      TargetPlatform.linux => 'Noto Sans SC',
      TargetPlatform.android => 'Noto Sans SC',
      _ => null,
    };
  }

  /// 全平台字体回退链，匹配设计原型字体系统（PingFang SC / HarmonyOS Sans SC / MiSans / Noto Sans SC / Segoe UI / Microsoft YaHei）。
  static const List<String> _fontFamilyFallback = [
    'PingFang SC',
    'HarmonyOS Sans SC',
    'MiSans',
    'Noto Sans SC',
    'Noto Sans CJK SC',
    'Segoe UI',
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'WenQuanYi Micro Hei',
    'sans-serif',
  ];

  /// Build theme for a given brightness and optional seed color.
  ///
  /// App layer calls this twice (brightness light + dark) and passes both
  /// to MaterialApp.router's `theme` / `darkTheme` along with `themeMode`.
  static ThemeData build(Brightness brightness, {Color? seedColor}) {
    final isDark = brightness == Brightness.dark;
    final activeSeed = seedColor ?? AppTokens.seedColor;

    // 匹配预设主题色
    final palette = AppTokens.themePalettes
        .where((p) => p.color.toARGB32() == activeSeed.toARGB32())
        .firstOrNull;

    Color primaryColor;
    Color onPrimaryColor;

    if (palette?.id == 'black' ||
        activeSeed.toARGB32() == const Color(0xFF111827).toARGB32()) {
      // 曜石黑特别处理：浅色纯黑极简质感，深色纯白高对比
      primaryColor = isDark ? const Color(0xFFF3F4F6) : const Color(0xFF111827);
      onPrimaryColor = isDark ? const Color(0xFF111827) : Colors.white;
    } else {
      // 个性主题色：浅色模式使用原色，深色模式使用明度校准的高亮色
      if (isDark) {
        primaryColor = switch (palette?.id) {
          'blue' => const Color(0xFF60A5FA),
          'emerald' => const Color(0xFF34D399),
          'amber' => const Color(0xFFFBBF24),
          'purple' => const Color(0xFFA78BFA),
          'rose' => const Color(0xFFFB7185),
          'teal' => const Color(0xFF22D3EE),
          'slate' => const Color(0xFF94A3B8),
          _ => Color.lerp(activeSeed, Colors.white, 0.35)!,
        };
        onPrimaryColor = const Color(0xFF111827);
      } else {
        primaryColor = activeSeed;
        onPrimaryColor = Colors.white;
      }
    }

    final rawColorScheme = ColorScheme.fromSeed(
      seedColor: activeSeed,
      brightness: brightness,
    );

    final colorScheme = rawColorScheme.copyWith(
      primary: primaryColor,
      onPrimary: onPrimaryColor,
    );

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
        filled: false,
        fillColor: Colors.transparent,
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
              borderRadius: BorderRadius.circular(AppTokens.radiusChip + 2),
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return isDark
                  ? colorScheme.primary.withValues(alpha: 0.22)
                  : colorScheme.primary.withValues(alpha: 0.12);
            }
            return isDark
                ? AppTokens.surfaceSunkenDark.withValues(alpha: 0.3)
                : AppTokens.surfaceSunkenLight.withValues(alpha: 0.5);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primary;
            }
            return colorScheme.onSurfaceVariant;
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.primary;
            }
            return colorScheme.onSurfaceVariant;
          }),
          textStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return TextStyle(
              fontFamily: _defaultFontFamily,
              fontFamilyFallback: _fontFamilyFallback,
              fontSize: AppTokens.textFootnoteSize,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            );
          }),
          elevation: const WidgetStatePropertyAll(0.0),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return BorderSide(
                color: colorScheme.primary.withValues(
                  alpha: isDark ? 0.35 : 0.25,
                ),
                width: 1,
              );
            }
            return BorderSide(
              color: isDark
                  ? AppTokens.borderSubtleDark
                  : AppTokens.borderSubtleLight,
              width: 0.5,
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
        elevation: 2,
        highlightElevation: 4,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
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
        indicatorColor: colorScheme.primary.withValues(
          alpha: AppTokens.alphaTintSoft,
        ),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        ),
        labelType: NavigationRailLabelType.all,
      ),

      // ── Checkbox ──
      // Linear / Things 风格圆形复选框：完成 = 当前全局主题色（primary）填充 + 白勾；
      // 禁用（有子任务，状态派生）= 浅灰填充。shape 走 AppTokens。
      checkboxTheme: CheckboxThemeData(
        shape: AppTokens.checkboxShape,
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BorderSide(color: colorScheme.primary, width: 1.5);
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
            return colorScheme.primary;
          }
          if (states.contains(WidgetState.disabled)) {
            return colorScheme.onSurface.withValues(alpha: 0.15);
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
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
