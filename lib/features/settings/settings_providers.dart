import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 实例的全局 Provider。
///
/// 由 main() 初始化后通过 `overrideWithValue` 注入，保证各 Notifier
/// 可同步读取（非敏感设置，凭据类数据禁止存于此，AGENTS.md §3-6）。
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError('sharedPreferencesProvider 必须在 main() 中通过 override 注入');
});

/// 主题模式持久化 key。
const String themeModePrefKey = 'theme_mode';

/// 语言持久化 key。
const String localePrefKey = 'locale';

/// 主题模式 Notifier：读取/持久化/即时生效（FR-SET-01）。
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  /// 默认主题模式：跟随系统。
  static const ThemeMode defaultThemeMode = ThemeMode.system;

  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final value = prefs.getString(themeModePrefKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => defaultThemeMode,
    );
  }

  /// 切换主题模式并持久化。
  Future<void> setThemeMode(ThemeMode mode) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(themeModePrefKey, mode.name);
    state = mode;
  }
}

/// 语言 Notifier：读取/持久化/即时生效（FR-SET-02，M0 仅 zh/en）。
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<Locale> {
  /// 默认语言：简体中文（源语言）。
  static const Locale defaultLocale = Locale('zh');

  @override
  Locale build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final code = prefs.getString(localePrefKey);
    return switch (code) {
      'en' => const Locale('en'),
      'zh' => defaultLocale,
      _ => defaultLocale,
    };
  }

  /// 切换语言并持久化。
  Future<void> setLocale(Locale locale) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(localePrefKey, locale.languageCode);
    state = locale;
  }
}
