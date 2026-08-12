// 同步触发调度（docs/60-sync-design.md §10.2 / §12，UI 无关）。
//
// 与 SyncEngine 的分工：
// - SyncEngine.run()：手动/触发统一入口（串行防重入）；
// - 本类：把「何时触发」编排为具体入口（手动/启动/编辑/失败退避），并应用
//   wifiOnly 约束（可注入 isWifiAllowed；移动端需 connectivity 检测，本项目
//   未加依赖，桌面默认返回 true，UI 层后续接入实际检测）。
// - 编辑自动同步的唯一防抖入口在本层（SyncEngine 已删除 runAfterEdit，避免
//   双套防抖 Timer）；Repository 的用户写方法经 `onDataChanged` 回调接线到
//   本类的 onEdit（装配在 main.dart，见 todoRepositoryProvider 注释）。
//
// 自动同步（启动/编辑/失败重试）受 wifiOnly 约束（§10.3）；手动 runNow 不受。

import 'dart:async';

import 'sync_config.dart';
import 'sync_engine.dart';

/// 失败重试最大次数（§12：指数退避，最多 5 次）。
const int _kMaxRetries = 5;

/// 编辑防抖时长（§10.2：2s；原 `SyncEngine.editDebounce` 随 runAfterEdit
/// 删除，防抖时长统一归本层维护）。
const Duration _kEditDebounce = Duration(seconds: 2);

/// 同步触发调度（UI 无关，供应用启动/编辑写操作/设置页调用）。
class SyncTriggers {
  SyncTriggers({
    required SyncEngine engine,
    required Future<bool> Function() isWifiAllowed,
  }) : _engine = engine,
       _isWifiAllowed = isWifiAllowed;

  final SyncEngine _engine;

  /// WiFi 可用性判定（可注入）。WiFi-only 时非 WiFi 场景自动同步被跳过；
  /// 桌面默认恒 true（本项目未加 connectivity 依赖，UI 层后续接入检测）。
  final Future<bool> Function() _isWifiAllowed;

  Timer? _editTimer;
  Timer? _retryTimer;

  /// 已调度的重试次数（§12）。**共享计数**（未引入每链独立状态）：多条
  /// 退避链共用同一计数器与同一 Timer——后调度的会取消先前的 Timer，同一
  /// 时刻至多一条退避链生效；成功/跳过/不可重试/达上限即清零。
  int _retryCount = 0;

  /// 手动同步（设置页「立即同步」）：**不受 wifiOnly 约束**（§10.2）。
  Future<SyncResult> runNow() => _engine.run();

  /// 启动自动同步（可关：autoOnStart）。受 wifiOnly 约束。
  Future<void> runOnStart() async {
    final config = await _engine.loadSettingsConfig();
    if (!config.enabled || !config.autoOnStart) return;
    if (!await _allowAuto(config)) return;
    await _engine.run();
  }

  /// 应用回到前台（AppLifecycleState.resumed）自动同步（M5 生命周期触发）。
  ///
  /// 语义：**不受 autoOnStart 限制**（回到前台 ≠ 首次启动，用户回到应用
  /// 期望拿到最新数据）；受 enabled + wifiOnly 约束（属自动同步）。
  /// 由 `LifecycleSyncListener`（app 层）在 resumed 时调用，fire-and-forget。
  Future<void> runOnResume() async {
    final config = await _engine.loadSettingsConfig();
    if (!config.enabled) return;
    if (!await _allowAuto(config)) return;
    await _engine.run();
  }

  /// 编辑自动同步：防抖 2s（多次写操作合并为一次）+ 可关（autoOnEdit）。
  ///
  /// 受 wifiOnly 约束（§10.3）。这是编辑自动同步的唯一防抖入口（SyncEngine
  /// 不再提供 runAfterEdit）；由装配层注入 Repository.onDataChanged。
  Future<void> onEdit() async {
    final config = await _engine.loadSettingsConfig();
    if (!config.enabled || !config.autoOnEdit) return;
    if (!await _allowAuto(config)) return;
    _editTimer?.cancel();
    _editTimer = Timer(_kEditDebounce, () async {
      await _engine.run();
    });
  }

  /// 失败后指数退避重试调度（§12）：由**调用方在同步失败后**调用一次，
  /// 传入本次失败结果 [result]。**不再立即重跑**（首次失败已由调用方手动
  /// 触发，无需自动即时重跑）。
  ///
  /// - 成功/跳过/不可重试 → 重置计数并停止；
  /// - 可重试失败且未达上限 → 按 1/2/4/8/16 秒指数退避调度下一次 run()，
  ///   到点重跑后仍失败则继续退避（同一退避链最多 5 次）；
  /// - 受 wifiOnly 约束（§10.3 自动同步）。
  Future<void> scheduleRetryIfNeeded(SyncResult result) async {
    if (result.ok || result.skipped || !result.retryable) {
      _retryCount = 0;
      return;
    }
    final config = await _engine.loadSettingsConfig();
    if (!config.enabled || !await _allowAuto(config)) {
      // 已禁用 / wifi-only 且当前非 WiFi → 跳过本次自动重试（不消耗次数，
      // 留给下次触发）。
      return;
    }
    if (_retryCount >= _kMaxRetries) {
      _retryCount = 0;
      return;
    }
    _retryCount++;
    final delay = Duration(seconds: 1 << (_retryCount - 1)); // 1,2,4,8,16
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      unawaited(_runRetryAfterBackoff());
    });
  }

  /// 退避到点后的重试：到点时再核验配置/wifi（退避期间网络环境可能变化），
  /// 通过则 run()，并把结果交回 [scheduleRetryIfNeeded] 决定继续退避或终止。
  Future<void> _runRetryAfterBackoff() async {
    final config = await _engine.loadSettingsConfig();
    if (!config.enabled || !await _allowAuto(config)) return;
    final result = await _engine.run();
    await scheduleRetryIfNeeded(result);
  }

  /// wifiOnly 约束：仅 WiFi 时自动同步（§10.3）。
  Future<bool> _allowAuto(SyncConfig config) async {
    if (!config.wifiOnly) return true;
    return await _isWifiAllowed();
  }

  /// 取消未决的编辑防抖/重试 Timer（应用生命周期结束时调用）。
  void dispose() {
    _editTimer?.cancel();
    _retryTimer?.cancel();
  }
}
