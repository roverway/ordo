import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backup/backup_restore_service.dart';
import '../../core/backup/snapshot_pool_service.dart';
import '../../core/db/daos/settings_dao.dart';
import '../../core/services/wallpaper_storage_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/background_config.dart';
import '../projects/project_providers.dart';

/// 设备本地偏好缓存：settings 表在内存的同步镜像（docs/64-local-preferences.md §3.1）。
///
/// Drift 读是异步的，但 [themeModeProvider]/[localeProvider] 需在首帧同步可用
/// （避免主题闪烁）。启动时 main() 预载 settings 表到本缓存，providers 同步读、
/// 写时穿透到 [SettingsDao]（异步）。
///
/// **写入约束（评审 #5）**：`theme_mode` / `locale` / `hide_completed` 这三个
/// key 的偏好**只能经本缓存的 [set] 写入**——直接写 [SettingsDao] 会让缓存
/// 与 DB 失步（providers 读的是缓存）。同步配置类 key（lastSyncedAt/deviceId/
/// 墓碑等）不经本缓存，直接走 DAO，互不干扰。
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

  /// 删除内存 + 穿透到 SettingsDao（未 attach 时仅删内存）。
  Future<void> remove(String key) async {
    _values.remove(key);
    await _dao?.remove(key);
  }
}

/// 全局缓存 Provider：main() 注入；测试经 override 提供内存实例。
final appSettingsCacheProvider = Provider<AppSettingsCache>((ref) {
  return AppSettingsCache();
});

/// 主题模式持久化 key（settings 表；键名与旧 SharedPreferences 一致，兼容迁移）。
const String themeModePrefKey = 'theme_mode';

/// 语言持久化 key（settings 表；键名与旧 SharedPreferences 一致，兼容迁移）。
const String localePrefKey = 'locale';

/// 四象限作用域选中清单持久化 key（JSON 数组或未设置/all）。
const String quadrantFilterProjectIdsPrefKey = 'quadrant_filter_project_ids';

/// 四象限是否显示已完成任务持久化 key。
const String quadrantFilterShowCompletedPrefKey =
    'quadrant_filter_show_completed';

/// 四象限视图模式持久化 key（matrix / list）。
const String quadrantViewModePrefKey = 'quadrant_view_mode';

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
    final cache = ref.read(appSettingsCacheProvider);
    state = mode;
    try {
      await cache.set(themeModePrefKey, mode.name);
    } catch (e) {
      debugPrint('setThemeMode 持久化失败：${e.runtimeType}');
    }
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
    final cache = ref.read(appSettingsCacheProvider);
    state = locale;
    try {
      await cache.set(localePrefKey, locale.languageCode);
    } catch (e) {
      debugPrint('setLocale 持久化失败：${e.runtimeType}');
    }
  }
}

/// 主题种子色持久化 key（settings 表）。
const String themeSeedColorPrefKey = 'theme_seed_color';

/// 主题种子色 Notifier：读取/持久化/即时生效。
final themeSeedColorProvider = NotifierProvider<ThemeSeedColorNotifier, Color>(
  ThemeSeedColorNotifier.new,
);

class ThemeSeedColorNotifier extends Notifier<Color> {
  /// 默认种子色。
  static const Color defaultSeedColor = AppTokens.seedColor;

  @override
  Color build() {
    final hexString = ref
        .watch(appSettingsCacheProvider)
        .get(themeSeedColorPrefKey);
    if (hexString == null) return defaultSeedColor;
    try {
      final value = int.tryParse(hexString, radix: 16);
      if (value != null) return Color(value);
    } catch (_) {}
    return defaultSeedColor;
  }

  /// 切换主题种子色并持久化（写内存缓存 + 穿透 settings 表）。
  Future<void> setSeedColor(Color color) async {
    final cache = ref.read(appSettingsCacheProvider);
    state = color;
    try {
      await cache.set(
        themeSeedColorPrefKey,
        color.toARGB32().toRadixString(16),
      );
    } catch (e) {
      debugPrint('setSeedColor 持久化失败：${e.runtimeType}');
    }
  }
}

/// 显示农历持久化 key。
const String calendarShowLunarPrefKey = 'calendar_show_lunar';

/// 显示节假日与调休持久化 key。
const String calendarShowHolidaysPrefKey = 'calendar_show_holidays';

/// 是否在日历中显示中国农历 Notifier。
final calendarShowLunarProvider =
    NotifierProvider<CalendarShowLunarNotifier, bool>(
      CalendarShowLunarNotifier.new,
    );

class CalendarShowLunarNotifier extends Notifier<bool> {
  /// 默认显示农历。
  static const bool defaultShowLunar = true;

  @override
  bool build() {
    final value = ref
        .watch(appSettingsCacheProvider)
        .get(calendarShowLunarPrefKey);
    if (value == null) return defaultShowLunar;
    return value == 'true';
  }

  /// 切换是否显示农历并持久化。
  Future<void> setShowLunar(bool enable) async {
    final cache = ref.read(appSettingsCacheProvider);
    state = enable;
    try {
      await cache.set(calendarShowLunarPrefKey, enable.toString());
    } catch (e) {
      debugPrint('setShowLunar 持久化失败：${e.runtimeType}');
    }
  }
}

/// 是否在日历中显示法定节假日及调休 Notifier。
final calendarShowHolidaysProvider =
    NotifierProvider<CalendarShowHolidaysNotifier, bool>(
      CalendarShowHolidaysNotifier.new,
    );

class CalendarShowHolidaysNotifier extends Notifier<bool> {
  /// 默认显示法定节假日及调休。
  static const bool defaultShowHolidays = true;

  @override
  bool build() {
    final value = ref
        .watch(appSettingsCacheProvider)
        .get(calendarShowHolidaysPrefKey);
    if (value == null) return defaultShowHolidays;
    return value == 'true';
  }

  /// 切换是否显示法定节假日及调休并持久化。
  Future<void> setShowHolidays(bool enable) async {
    final cache = ref.read(appSettingsCacheProvider);
    state = enable;
    try {
      await cache.set(calendarShowHolidaysPrefKey, enable.toString());
    } catch (e) {
      debugPrint('setShowHolidays 持久化失败：${e.runtimeType}');
    }
  }
}

/// 全局应用级背景壁纸持久化 key。
const String appBackgroundPrefKey = 'pref_app_background_config';

/// 获取清单专属背景壁纸持久化 key。
String projectBackgroundPrefKey(String projectId) =>
    'pref_project_bg_$projectId';

/// 壁纸沙箱存储服务 Provider。
final wallpaperStorageServiceProvider = Provider<WallpaperStorageService>((
  ref,
) {
  return WallpaperStorageService();
});

/// 应用级全局背景壁纸 Notifier。
final appBackgroundConfigProvider =
    NotifierProvider<AppBackgroundConfigNotifier, BackgroundConfig>(
      AppBackgroundConfigNotifier.new,
    );

class AppBackgroundConfigNotifier extends Notifier<BackgroundConfig> {
  @override
  BackgroundConfig build() {
    final raw = ref.watch(appSettingsCacheProvider).get(appBackgroundPrefKey);
    return BackgroundConfig.deserialize(raw);
  }

  /// 设置并持久化全局壁纸配置。
  Future<void> setConfig(BackgroundConfig config) async {
    final cache = ref.read(appSettingsCacheProvider);
    state = config;
    try {
      await cache.set(appBackgroundPrefKey, config.serialize());
    } catch (e) {
      debugPrint('setAppBackgroundConfig 持久化失败：${e.runtimeType}');
    }
  }
}

/// 清单/项目专属背景壁纸 Notifier Family。
final projectBackgroundConfigProvider =
    NotifierProvider.family<
      ProjectBackgroundConfigNotifier,
      BackgroundConfig,
      String
    >((arg) => ProjectBackgroundConfigNotifier(arg));

class ProjectBackgroundConfigNotifier extends Notifier<BackgroundConfig> {
  ProjectBackgroundConfigNotifier(this.projectId);

  final String projectId;

  @override
  BackgroundConfig build() {
    final raw = ref
        .watch(appSettingsCacheProvider)
        .get(projectBackgroundPrefKey(projectId));
    return BackgroundConfig.deserialize(raw);
  }

  /// 设置并持久化清单壁纸配置。
  Future<void> setConfig(BackgroundConfig config) async {
    final cache = ref.read(appSettingsCacheProvider);
    state = config;
    try {
      await cache.set(projectBackgroundPrefKey(projectId), config.serialize());
    } catch (e) {
      debugPrint('setProjectBackgroundConfig 持久化失败：${e.runtimeType}');
    }
  }
}

/// 统一计算当前视图最终生效的背景壁纸 Provider（优先级：清单专属 > 应用全局 > none）。
final effectiveBackgroundConfigProvider =
    Provider.family<BackgroundConfig, String?>((ref, projectId) {
      final appBg = ref.watch(appBackgroundConfigProvider);
      if (projectId != null && projectId.trim().isNotEmpty) {
        final projectBg = ref.watch(
          projectBackgroundConfigProvider(projectId.trim()),
        );
        if (projectBg.isEffective) {
          return projectBg;
        }
      }
      return appBg;
    });

/// 快照保留天数持久化 key（settings 表）。
const String backupRetentionDaysPrefKey = 'backup_retention_days';

/// 默认本地快照保留天数（7 天）。
const int defaultBackupRetentionDays = 7;

/// 快照保留天数 Notifier。
final backupRetentionDaysProvider =
    NotifierProvider<BackupRetentionDaysNotifier, int>(
      BackupRetentionDaysNotifier.new,
    );

class BackupRetentionDaysNotifier extends Notifier<int> {
  @override
  int build() {
    final value = ref
        .watch(appSettingsCacheProvider)
        .get(backupRetentionDaysPrefKey);
    return int.tryParse(value ?? '') ?? defaultBackupRetentionDays;
  }

  /// 更改快照保留天数并持久化。
  Future<void> setDays(int days) async {
    final cache = ref.read(appSettingsCacheProvider);
    state = days;
    try {
      await cache.set(backupRetentionDaysPrefKey, days.toString());
    } catch (e) {
      debugPrint('setBackupRetentionDays 持久化失败：${e.runtimeType}');
    }
  }
}

/// 数据导入导出与灾难恢复服务 Provider。
final backupRestoreServiceProvider = Provider<BackupRestoreService>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return BackupRestoreService(repo);
});

/// 本地安全快照池管理服务 Provider。
final snapshotPoolServiceProvider = Provider<SnapshotPoolService>((ref) {
  final backupService = ref.watch(backupRestoreServiceProvider);
  final repo = ref.watch(todoRepositoryProvider);
  AppSettingsCache? cache;
  try {
    cache = ref.watch(appSettingsCacheProvider);
  } catch (_) {
    // 允许在未显式 override appSettingsCacheProvider 的测试环境中健壮降级
  }
  return SnapshotPoolService(
    backupService: backupService,
    settings: repo.settings,
    onRetentionDaysChanged: cache != null
        ? (days) => cache!.set(backupRetentionDaysPrefKey, days.toString())
        : null,
  );
});

/// 本地快照列表 Notifier。
final localSnapshotsProvider =
    AsyncNotifierProvider<LocalSnapshotsNotifier, List<LocalSnapshotInfo>>(
      LocalSnapshotsNotifier.new,
    );

class LocalSnapshotsNotifier extends AsyncNotifier<List<LocalSnapshotInfo>> {
  @override
  Future<List<LocalSnapshotInfo>> build() async {
    final pool = ref.watch(snapshotPoolServiceProvider);
    return pool.listSnapshots();
  }

  /// 重新扫描快照池并刷新列表。
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final pool = ref.read(snapshotPoolServiceProvider);
      return pool.listSnapshots();
    });
  }
}
