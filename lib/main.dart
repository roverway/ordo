import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'features/settings/settings_providers.dart';
import 'features/sync_setup/sync_setup_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化共享偏好存储（非敏感设置），注入 ProviderContainer。
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  // 启动自动同步（FR-SYNC-02，fire-and-forget）：不阻塞首帧；同步内部的
  // 网络/认证/配置错误已由 SyncEngine 分类处理（SyncState.error 展示），
  // 这里只兜底 DB/存储初始化异常，避免未处理的异步错误。
  unawaited(
    container
        .read(syncTriggersProvider)
        .runOnStart()
        .catchError(
          (Object e) => debugPrint('sync: 启动自动同步异常 ${e.runtimeType}'),
        ),
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const TodoApp()),
  );
}
