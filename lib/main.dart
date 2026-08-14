import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'features/projects/project_providers.dart';
import 'features/settings/settings_providers.dart';
import 'features/sync_setup/sync_setup_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 设备本地偏好统一持久化（docs/64-local-preferences.md §3.3）：先注入空缓存
  // 实例，随后 attach SettingsDao 并 seed 预载 settings 表到内存同步缓存。
  final container = ProviderContainer(
    overrides: [appSettingsCacheProvider.overrideWithValue(AppSettingsCache())],
  );
  final repo = container.read(todoRepositoryProvider);
  final cache = container.read(appSettingsCacheProvider);
  cache.attach(repo.settings);
  // 一次性迁移：SharedPreferences → settings 表（theme_mode/locale，仅缺失时）。
  await migrateLegacyPrefs(container, repo);
  // 预载 settings 表 → 内存缓存（迁移结果已并入）。
  cache.seed(await repo.settings.getAll());

  // 编辑自动同步接线（FR-SYNC-02）：把触发层 onEdit（防抖 2s + autoOnEdit
  // 开关 + wifiOnly 约束）注入 Repository 的用户写方法。Repository 层不
  // import lib/core/sync/（分层约束，docs/30-architecture §1），回调经可变
  // 字段注入；此处容器已创建、两个 Provider 均已可读，无循环依赖。
  final syncTriggers = container.read(syncTriggersProvider);
  repo.onDataChanged = syncTriggers.onEdit;

  // 启动自动同步（FR-SYNC-02，fire-and-forget）：不阻塞首帧；同步内部的
  // 网络/认证/配置错误已由 SyncEngine 分类处理（SyncState.error 展示），
  // 这里只兜底 DB/存储初始化异常，避免未处理的异步错误。
  unawaited(
    syncTriggers.runOnStart().catchError(
      (Object e) => debugPrint('sync: 启动自动同步异常 ${e.runtimeType}'),
    ),
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const TodoApp()),
  );
}

/// 一次性迁移（docs/64-local-preferences.md §3.3，幂等）：SharedPreferences
/// 的 `theme_mode`/`locale` → settings 表。
///
/// 仅当 settings 表**缺失**对应 key 且 SharedPreferences 有值时写入（不覆盖
/// settings 表中已存在的值）。迁移完成后 SharedPreferences 值保留但不再读取
/// （无副作用；后续版本移除依赖后可一并清理）。
Future<void> migrateLegacyPrefs(
  ProviderContainer container,
  TodoRepository repo,
) async {
  final cache = container.read(appSettingsCacheProvider);
  final settings = repo.settings;
  final prefs = await SharedPreferences.getInstance();
  for (final key in const [themeModePrefKey, localePrefKey]) {
    final legacy = prefs.getString(key);
    if (legacy == null) continue; // SharedPreferences 无旧值，跳过。
    final existing = await settings.get(key);
    if (existing != null) continue; // settings 表已有值，不覆盖（幂等）。
    // 写内存缓存 + 穿透到 settings 表（attach 须先于本函数调用）。
    await cache.set(key, legacy);
  }
}
