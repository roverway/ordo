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
  // 初始化共享偏好存储（非敏感设置），注入 ProviderContainer。
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  // 编辑自动同步接线（FR-SYNC-02）：把触发层 onEdit（防抖 2s + autoOnEdit
  // 开关 + wifiOnly 约束）注入 Repository 的用户写方法。Repository 层不
  // import lib/core/sync/（分层约束，docs/30-architecture §1），回调经可变
  // 字段注入；此处容器已创建、两个 Provider 均已可读，无循环依赖。
  final repo = container.read(todoRepositoryProvider);
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
