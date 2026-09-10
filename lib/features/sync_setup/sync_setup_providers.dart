// 同步配置装配层（docs/30-architecture.md §3，Riverpod 无 codegen）。
//
// 职责（本任务 M4 最后一块，只做 UI 与接线，不改同步引擎核心）：
// - 组装全局单例：SecureStore / RemoteStoreFactory / SyncEngine / SyncTriggers；
// - 暴露 SyncState Notifier（docs/30-architecture §3：idle/syncing/success/error
//   + lastSyncedAt，UI 订阅同步状态）；
// - syncConfigProvider：读取当前配置（settings 非敏感项 + SecureStore 凭据），
//   供配置页表单预填。**凭据从安全存储读出后仅在本 Provider 作用域内使用，
//   禁止写入日志**（60-sync-design.md §13）；
// - saveSyncConfig / testSyncConnection：保存 / 测试连接辅助（供页面调用）。
//   编辑自动同步（onEditSync）已移除：统一经 TodoRepository.onDataChanged
//   回调接线到 SyncTriggers.onEdit（装配在 main.dart）。
//
// 分层约束（30-architecture §1）：本文件只依赖 core/sync 与 Repository 抽象，
// 不反向依赖 UI。

import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/security/secure_store.dart';
import '../../core/sync/remote_store_factory.dart';
import '../../core/sync/sync_config.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/sync/sync_exceptions.dart';
import '../../core/sync/sync_triggers.dart';
import '../projects/project_providers.dart';
import '../settings/settings_providers.dart';

/// 凭据安全存储（flutter_secure_storage 封装，§13；凭据禁止明文入 settings）。
final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

/// 远端存储工厂（无状态，const 实例；§9.3）。
final remoteStoreFactoryProvider = Provider<RemoteStoreFactory>(
  (ref) => const RemoteStoreFactory(),
);

/// 同步状态 Notifier。
///
/// 单独定义（而非放在 SyncEngine 内部）以避免循环依赖：
/// engine 的 `onStateChanged` 回调写入本 Notifier，UI 侧 `watch` 本 Provider。
final syncStateProvider = NotifierProvider<SyncStateNotifier, SyncState>(
  SyncStateNotifier.new,
);

class SyncStateNotifier extends Notifier<SyncState> {
  /// 初始 idle（未同步）。
  @override
  SyncState build() => SyncState.idle;

  /// 由 SyncEngine.onStateChanged 回调写入最新状态。
  void update(SyncState state) {
    this.state = state;
  }
}

/// 时钟偏差确认回调持有者（docs/60-sync-design.md §11）。
///
/// 由同步配置页注册/注销（回调需要 BuildContext 弹确认框）；未注册时为
/// null → 引擎直接拒绝继续（安全默认，不静默合并）。
///
/// 用普通可变对象而非 Notifier：页面在 initState/dispose 中赋值，而 Riverpod
/// 禁止在这些生命周期内修改 Provider 状态（`_debugCanModifyProviders` 断言）。
/// 该字段只被引擎在同步时按需读取，不需要响应式通知。
class ClockSkewConfirmHolder {
  Future<bool> Function()? callback;
}

final clockSkewConfirmProvider = Provider<ClockSkewConfirmHolder>(
  (ref) => ClockSkewConfirmHolder(),
);

/// 同步引擎（应用生命周期内全局单例，触发层与配置页共用）。
final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    repository: ref.watch(todoRepositoryProvider),
    secureStore: ref.watch(secureStoreProvider),
    remoteStoreFactory: ref.watch(remoteStoreFactoryProvider),
    snapshotPoolService: ref.watch(snapshotPoolServiceProvider),
    confirmClockSkew: () async {
      final confirm = ref.read(clockSkewConfirmProvider).callback;
      return confirm != null ? confirm() : false;
    },
    onStateChanged: (state) =>
        ref.read(syncStateProvider.notifier).update(state),
  );
});

/// 同步触发调度（手动/启动/编辑/失败指数退避；§10.2）。
final syncTriggersProvider = Provider<SyncTriggers>((ref) {
  return SyncTriggers(
    engine: ref.watch(syncEngineProvider),
    // 桌面恒 true（§10.2 桌面恒真）；Android 经 connectivity_plus 真实检测
    // （M5 接入，2026-08；20-tech-stack.md §4）。
    isWifiAllowed: _isWifiAllowed,
  );
});

/// WiFi 可用性判定（供 syncTriggersProvider 注入，docs/60-sync-design.md §10.3）。
///
/// - 桌面（Windows/Linux/macOS）恒 true：connectivity_plus 桌面端通常返回
///   `other`/`vpn`，不具 Wi-Fi 语义（§10.2 桌面恒真，沿用现状语义）；
/// - 移动端经 connectivity_plus 真实检测：当前连接结果含
///   [ConnectivityResult.wifi] 才允许自动同步。
///
/// 每次调用 `Connectivity().checkConnectivity()`，不缓存（简单可靠，网络状态
/// 实时）。插件在测试环境不可用，测试侧只验证 SyncTriggers 注入链路
/// （sync_triggers_test.dart 用 fake 回调），真实检测留手工验证。
Future<bool> _isWifiAllowed() async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    return true;
  }
  final results = await Connectivity().checkConnectivity();
  return results.contains(ConnectivityResult.wifi);
}

/// 当前同步配置（settings 非敏感项 + SecureStore 凭据），供表单预填。
///
/// 凭据从安全存储读出后仅在本 Provider 作用域内使用，不得写入日志（§13）。
final syncConfigProvider = FutureProvider<SyncConfig>((ref) {
  return ref.watch(syncEngineProvider).loadConfig();
});

/// 保存同步配置。
///
/// - 非敏感项：经 `config.toMap()`（仅 6 项，绝不含凭据）逐条 `settings.set`；
/// - 凭据：经 `secureStore.writeCreds`（仅写非 null 字段）。
///
/// **写入顺序（防半应用状态，M4 评审缺陷 4）**：
/// 1. 先写**非启用类** settings（type/autoOnStart/autoOnEdit/wifiOnly/
///    lastSyncedAt）——不依赖凭据，先落盘无风险；
/// 2. 再写凭据（writeCreds）——凭据失败 → settings 中 enabled 保持旧值，
///    不会出现「enabled=true 但无凭据」的半应用态；
/// 3. 最后写 enabled——它是「凭据已就绪」的前置门。
/// 残余风险（注释）：凭据已写而最后一步 settings 写入失败（概率低）会留下
/// 「凭据已更新但开关未更新」的状态；下次保存幂等重写凭据，无安全影响。
///
/// 成功后由调用方 `ref.invalidate(syncConfigProvider)` 刷新表单预填。
Future<void> saveSyncConfig(WidgetRef ref, SyncConfig config) async {
  final repo = ref.read(todoRepositoryProvider);
  final store = ref.read(secureStoreProvider);
  final settings = config.toMap();
  final enabled = settings[SyncSettingsKeys.enabled]!;
  for (final entry in settings.entries) {
    if (entry.key == SyncSettingsKeys.enabled) continue;
    await repo.settings.set(entry.key, entry.value);
  }
  await store.writeCreds(config);
  await repo.settings.set(SyncSettingsKeys.enabled, enabled);
}

/// 测试远端连接：用 [config] 构造 RemoteStore 并调 `exists()`。
///
/// 返回 `(ok, errorCode)`：成功 ok=true 且 errorCode=null；失败 errorCode
/// 为结构化错误码（UI 按 errorCode 映射 ARB 文案；区分认证 / 网络 / 配置
/// 异常，§12，不含密钥或完整 URL）。引擎/异常层的 message **不得**在此
/// 透传给 UI。
Future<({bool ok, SyncErrorCode? errorCode})> testSyncConnection(
  WidgetRef ref,
  SyncConfig config,
) async {
  try {
    final store = ref.read(remoteStoreFactoryProvider).create(config);
    await store.exists();
    return (ok: true, errorCode: null);
  } on SyncConfigException {
    return (ok: false, errorCode: SyncErrorCode.config);
  } on SyncAuthException {
    return (ok: false, errorCode: SyncErrorCode.auth);
  } on SyncNetworkException {
    return (ok: false, errorCode: SyncErrorCode.network);
  } on SyncRemoteException {
    return (ok: false, errorCode: SyncErrorCode.remote);
  } catch (_) {
    return (ok: false, errorCode: SyncErrorCode.unknown);
  }
}
