// 同步触发调度（docs/60-sync-design.md §10.2 / §12，UI 无关）。
//
// 与 SyncEngine 的分工：
// - SyncEngine.run()：手动/触发统一入口（串行防重入）+ runAfterEdit() 防抖入口；
// - 本类：把「何时触发」编排为具体入口（手动/启动/编辑/失败退避），并应用
//   wifiOnly 约束（可注入 isWifiAllowed；移动端需 connectivity 检测，本项目
//   未加依赖，桌面默认返回 true，UI 层后续接入实际检测）。
//
// 自动同步（启动/编辑/失败重试）受 wifiOnly 约束（§10.3）；手动 runNow 不受。

import 'dart:async';

import 'sync_config.dart';
import 'sync_engine.dart';

/// 失败重试最大次数（§12：指数退避，最多 5 次）。
const int _kMaxRetries = 5;

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

  /// 编辑自动同步：防抖 2s（多次写操作合并为一次）+ 可关（autoOnEdit）。
  ///
  /// 受 wifiOnly 约束（§10.3）。防抖由本层 Timer 完成；[SyncEngine.runAfterEdit]
  /// 是另一条独立入口（Repository/Provider 直接接线用），二者不叠加使用。
  Future<void> onEdit() async {
    final config = await _engine.loadSettingsConfig();
    if (!config.enabled || !config.autoOnEdit) return;
    if (!await _allowAuto(config)) return;
    _editTimer?.cancel();
    _editTimer = Timer(SyncEngine.editDebounce, () async {
      await _engine.run();
    });
  }

  /// 失败后指数退避重试（§12）：1,2,4,8,16 秒，最多 5 次。
  ///
  /// 只在结果 retryable 时继续调度；成功/跳过/不可重试错误即停止并重置计数。
  /// 受 wifiOnly 约束（自动同步）。调用方在每次失败后调用一次即可。
  Future<void> maybeRetry() async {
    final config = await _engine.loadSettingsConfig();
    if (config.enabled && !await _allowAuto(config)) {
      // wifi-only 且当前非 WiFi → 跳过本次自动重试（不消耗次数，留给下次触发）。
      return;
    }
    final result = await _engine.run();
    if (result.ok || result.skipped || !result.retryable) {
      _retryCount = 0;
      return;
    }
    if (_retryCount >= _kMaxRetries) {
      _retryCount = 0;
      return;
    }
    _retryCount++;
    final delay = Duration(seconds: 1 << (_retryCount - 1)); // 1,2,4,8,16
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => maybeRetry());
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
