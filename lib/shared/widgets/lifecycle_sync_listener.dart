// 生命周期同步监听（M5 平台细节：Android 回到前台触发自动同步）。
//
// 挂载在 MaterialApp 外层（app.dart）。AppLifecycleState.resumed 时调用
// SyncTriggers.runOnResume()（受 enabled + wifiOnly 约束，不受 autoOnStart
// 限制——回到前台 ≠ 首次启动）。fire-and-forget；同步错误已由 SyncEngine
// 分类处理（SyncState.error 展示），此处仅兜底异常避免未处理异步错误。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sync_setup/sync_setup_providers.dart';

/// 生命周期监听壳：包住 [child]，resumed 时触发一次自动同步。
class LifecycleSyncListener extends ConsumerStatefulWidget {
  const LifecycleSyncListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LifecycleSyncListener> createState() =>
      _LifecycleSyncListenerState();
}

class _LifecycleSyncListenerState extends ConsumerState<LifecycleSyncListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // 回到前台自动同步（可关：enabled / wifiOnly 在 runOnResume 内部判断）。
    final triggers = ref.read(syncTriggersProvider);
    unawaited(
      triggers.runOnResume().catchError(
        (Object e) => debugPrint('sync: resumed 自动同步异常 ${e.runtimeType}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
