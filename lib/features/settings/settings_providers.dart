import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/daos/settings_dao.dart';

/// 设备本地偏好缓存：settings 表在内存的同步镜像（docs/64-local-preferences.md §3.1）。
///
/// Drift 读是异步的，但 [themeModeProvider]/[localeProvider] 需在首帧同步可用
/// （避免主题闪烁）。启动时 main() 预载 settings 表到本缓存，providers 同步读、
/// 写时穿透到 [SettingsDao]（异步）。
///
/// 注入时序（main）：容器创建时 override 空实例 → 读 repo →
/// `attach(repo.settings)` → `seed(getAll())`。测试用不 attach 的纯内存实例
/// （写只进内存 Map，不落库）。
class AppSettingsCache {
  SettingsDao? _dao;
  final Map<String, String> _values = {};

  /// 绑定 SettingsDao（写穿透目标；不调用则不落库）。
  void attach(SettingsDao dao) => _dao = dao;

  /// 同步读缓存。
  String? get(String key) => _values[key];

  /// 预载全量设置（启动时调用，可多次，合并追加）。
  void seed(Map<String, String> values) => _values.addAll(values);

  /// 写内存 + 穿透到 SettingsDao（未 attach 时仅写内存）。
  Future<void> set(String key, String value) async {
    _values[key] = value;
    await _dao?.set(key, value);
  }
}

/// 全局缓存 Provider：main() 注入；测试经 override 提供内存实例。
final appSettingsCacheProvider = Provider<AppSettingsCache>((ref) {
  throw StateError('appSettingsCacheProvider 必须在 main() 中通过 override 注入');
});

/// 主题模式持久化 key（settings 表；键名与旧 SharedPreferences 一致，兼容迁移）。
const String themeModePrefKey = 'theme_mode';

/// 语言持久化 key（settings 表；键名与旧 SharedPreferences 一致，兼容迁移）。
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
    final value = ref.watch(appSettingsCacheProvider).get(themeModePrefKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => defaultThemeMode,
    );
  }

  /// 切换主题模式并持久化（写内存缓存 + 穿透 settings 表）。
  Future<void> setThemeMode(ThemeMode mode) async {
    await ref.read(appSettingsCacheProvider).set(themeModePrefKey, mode.name);
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
    final code = ref.watch(appSettingsCacheProvider).get(localePrefKey);
    return switch (code) {
      'en' => const Locale('en'),
      'zh' => defaultLocale,
      _ => defaultLocale,
    };
  }

  /// 切换语言并持久化（写内存缓存 + 穿透 settings 表）。
  Future<void> setLocale(Locale locale) async {
    await ref
        .read(appSettingsCacheProvider)
        .set(localePrefKey, locale.languageCode);
    state = locale;
  }
}
