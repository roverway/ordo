// 本地偏好统一持久化测试（docs/64-local-preferences.md）。
//
// 覆盖：
// 1. AppSettingsCache：attach 前仅写内存 / attach 后穿透 DAO；seed 合并。
// 2. hideCompletedTasksProvider：toggle 持久化，重建容器（同一内存 DB）后保留。
// 3. themeModeProvider / localeProvider：切换持久化，重启（重 seed）后保留。
// 4. migrateLegacyPrefs：SharedPreferences → settings 表一次性迁移（幂等）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:todo/core/db/daos/settings_dao.dart';
import 'package:todo/core/db/repositories/todo_repository.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/features/tasks/task_providers.dart';
import 'package:todo/main.dart';

import '../../helpers/db_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettingsCache', () {
    test('attach 前 set 仅写内存；attach 后穿透 DAO', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final settings = SettingsDao(db);
      final cache = AppSettingsCache();

      await cache.set('k', 'v1');
      expect(cache.get('k'), 'v1');
      expect(await settings.get('k'), isNull, reason: '未 attach 不落库');

      cache.attach(settings);
      await cache.set('k', 'v2');
      expect(cache.get('k'), 'v2');
      expect(await settings.get('k'), 'v2', reason: 'attach 后穿透 DAO');
    });

    test('seed 合并追加；缺失 key get 返回 null', () {
      final cache = AppSettingsCache();
      expect(cache.get('missing'), isNull);
      cache.seed({'a': '1'});
      cache.seed({'b': '2', 'a': '3'}); // 后 seed 覆盖同 key
      expect(cache.get('a'), '3');
      expect(cache.get('b'), '2');
    });
  });

  group('hideCompletedTasksProvider 持久化', () {
    test('toggle 写缓存 + DAO；重建容器（同一内存 DB）后保留', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final settings = SettingsDao(db);
      final repo = TodoRepository(database: db);
      expect(repo.settings, isNotNull); // 引用确保 repo 持有同一 DAO 路径。

      // 首次启动：attach + seed。
      final cache1 = AppSettingsCache()..attach(settings);
      cache1.seed(await settings.getAll());
      final container1 = ProviderContainer(
        overrides: [appSettingsCacheProvider.overrideWithValue(cache1)],
      );
      addTearDown(container1.dispose);

      expect(
        container1.read(hideCompletedTasksProvider),
        isFalse,
        reason: '缺失 = 默认显示全部',
      );

      await container1.read(hideCompletedTasksProvider.notifier).toggle();
      expect(container1.read(hideCompletedTasksProvider), isTrue);
      expect(await settings.get('hide_completed'), '1');

      // 模拟重启：新缓存 attach 同一 DAO + seed（与 main.dart 启动链路一致）。
      final cache2 = AppSettingsCache()..attach(settings);
      cache2.seed(await settings.getAll());
      final container2 = ProviderContainer(
        overrides: [appSettingsCacheProvider.overrideWithValue(cache2)],
      );
      addTearDown(container2.dispose);

      expect(
        container2.read(hideCompletedTasksProvider),
        isTrue,
        reason: '重启后隐藏状态保留',
      );

      // 再 toggle 回来 → '0' 且持久化。
      await container2.read(hideCompletedTasksProvider.notifier).toggle();
      expect(container2.read(hideCompletedTasksProvider), isFalse);
      expect(await settings.get('hide_completed'), '0');
    });

    test('缓存预置 hide_completed=1 → build 直接为 true（重启恢复路径）', () {
      final cache = AppSettingsCache()..seed({'hide_completed': '1'});
      final container = ProviderContainer(
        overrides: [appSettingsCacheProvider.overrideWithValue(cache)],
      );
      addTearDown(container.dispose);
      expect(container.read(hideCompletedTasksProvider), isTrue);
    });
  });

  group('主题/语言持久化（重启保留）', () {
    test('切换即时生效并写 DAO；重启（重 seed）后保留', () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final settings = SettingsDao(db);

      final cache1 = AppSettingsCache()..attach(settings);
      cache1.seed(await settings.getAll());
      final container1 = ProviderContainer(
        overrides: [appSettingsCacheProvider.overrideWithValue(cache1)],
      );
      addTearDown(container1.dispose);

      expect(
        container1.read(themeModeProvider),
        ThemeMode.system,
        reason: '默认跟随系统',
      );
      expect(
        container1.read(localeProvider),
        const Locale('zh'),
        reason: '默认简体中文',
      );

      await container1
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      await container1
          .read(localeProvider.notifier)
          .setLocale(const Locale('en'));
      expect(container1.read(themeModeProvider), ThemeMode.dark);
      expect(container1.read(localeProvider), const Locale('en'));
      expect(await settings.get(themeModePrefKey), 'dark');
      expect(await settings.get(localePrefKey), 'en');

      // 模拟重启：新缓存 attach 同一 DAO + seed。
      final cache2 = AppSettingsCache()..attach(settings);
      cache2.seed(await settings.getAll());
      final container2 = ProviderContainer(
        overrides: [appSettingsCacheProvider.overrideWithValue(cache2)],
      );
      addTearDown(container2.dispose);

      expect(container2.read(themeModeProvider), ThemeMode.dark);
      expect(container2.read(localeProvider), const Locale('en'));
    });

    test('缓存 seed 直接驱动（theme_mode=light / locale=en）', () {
      final cache = AppSettingsCache()
        ..seed({themeModePrefKey: 'light', localePrefKey: 'en'});
      final container = ProviderContainer(
        overrides: [appSettingsCacheProvider.overrideWithValue(cache)],
      );
      addTearDown(container.dispose);
      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(container.read(localeProvider), const Locale('en'));
    });
  });

  group('migrateLegacyPrefs（SharedPreferences → settings 表）', () {
    test('SharedPreferences 有值且 settings 缺失 → 迁移，并入缓存', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = TodoRepository(database: db);
      final cache = AppSettingsCache();
      final container = ProviderContainer(
        overrides: [appSettingsCacheProvider.overrideWithValue(cache)],
      );
      addTearDown(container.dispose);
      cache.attach(repo.settings);

      await migrateLegacyPrefs(container, repo);

      expect(await repo.settings.get(themeModePrefKey), 'dark');
      expect(cache.get(themeModePrefKey), 'dark', reason: '迁移值并入内存缓存');
      expect(await repo.settings.get(localePrefKey), isNull);
    });

    test('settings 已存在 → 不被覆盖（幂等）', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = TodoRepository(database: db);
      await repo.settings.set(themeModePrefKey, 'dark'); // 已有值。

      final cache = AppSettingsCache();
      final container = ProviderContainer(
        overrides: [appSettingsCacheProvider.overrideWithValue(cache)],
      );
      addTearDown(container.dispose);
      cache.attach(repo.settings);

      await migrateLegacyPrefs(container, repo);

      expect(
        await repo.settings.get(themeModePrefKey),
        'dark',
        reason: '不覆盖 settings 表已有值',
      );
      expect(cache.get(themeModePrefKey), isNull, reason: '未迁移即不写缓存');
    });

    test('SharedPreferences 无值 → settings 表保持为空', () async {
      SharedPreferences.setMockInitialValues({});
      final db = openTestDatabase();
      addTearDown(db.close);
      final repo = TodoRepository(database: db);
      final cache = AppSettingsCache();
      final container = ProviderContainer(
        overrides: [appSettingsCacheProvider.overrideWithValue(cache)],
      );
      addTearDown(container.dispose);
      cache.attach(repo.settings);

      await migrateLegacyPrefs(container, repo);

      expect(await repo.settings.get(themeModePrefKey), isNull);
      expect(await repo.settings.get(localePrefKey), isNull);
    });
  });
}
