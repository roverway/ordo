// SyncTriggers 退避调度单元测试（docs/60-sync-design.md §12 指数退避）。
//
// 注入：SyncEngine 子类桩（覆写 run/loadSettingsConfig，按队列返回可控结果）
// + fakeAsync 控制 Timer（fake_async 为 flutter_test 传递依赖，此处定点豁免
// depend_on_referenced_packages，同 remote_store_webdav_test.dart 的 dio 处理）。
//
// 覆盖：可重试失败不立即重跑、1/2/4/8/16s 退避调度、成功即停止并清零、
// 不可重试不调度、wifiOnly 约束、单链上限 5 次。

// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/repositories/todo_repository.dart';
import 'package:todo/core/security/secure_store.dart';
import 'package:todo/core/sync/remote_store.dart';
import 'package:todo/core/sync/remote_store_factory.dart';
import 'package:todo/core/sync/sync_config.dart';
import 'package:todo/core/sync/sync_engine.dart';
import 'package:todo/core/sync/sync_triggers.dart';

import '../../helpers/db_test_setup.dart';

/// 内存安全存储后端（SyncEngine 构造必需；桩不会真正读写）。
class _MemorySecureBackend implements SecureKeyValueStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

/// 不会实例化真实远端（run 已被桩覆盖）。
class _StubRemoteStoreFactory implements RemoteStoreFactory {
  const _StubRemoteStoreFactory();

  @override
  RemoteStore create(SyncConfig config) => throw UnimplementedError();
}

/// SyncEngine 桩：按队列依次返回 run() 结果；loadSettingsConfig 返回注入配置。
class _StubEngine extends SyncEngine {
  _StubEngine({
    required super.repository,
    required List<SyncResult> results,
    SyncConfig config = const SyncConfig(enabled: true),
  }) : _results = results,
       _config = config,
       super(
         secureStore: SecureStore(backend: _MemorySecureBackend()),
         remoteStoreFactory: const _StubRemoteStoreFactory(),
       );

  final List<SyncResult> _results;
  final SyncConfig _config;

  /// run() 被实际调用的次数。
  int runCount = 0;

  int _next = 0;

  @override
  Future<SyncResult> run() async {
    runCount++;
    final index = _next.clamp(0, _results.length - 1);
    if (_next < _results.length) _next++;
    return _results[index];
  }

  @override
  Future<SyncConfig> loadSettingsConfig() async => _config;
}

/// 可重试失败结果（§12：网络/远端/快照损坏类）。
const _retryableFail = SyncResult(
  ok: false,
  retryable: true,
  errorCode: SyncErrorCode.network,
);

void main() {
  late AppDatabase db;
  late TodoRepository repo;

  setUp(() {
    db = openTestDatabase();
    repo = TodoRepository(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  SyncTriggers buildTriggers(_StubEngine engine, {bool wifiAllowed = true}) {
    return SyncTriggers(engine: engine, isWifiAllowed: () async => wifiAllowed);
  }

  test('可重试失败 → 不立即重跑；按 1/2/4s 退避调度；成功即停止', () {
    fakeAsync((async) {
      final engine = _StubEngine(
        repository: repo,
        results: [_retryableFail, _retryableFail, const SyncResult(ok: true)],
      );
      final triggers = buildTriggers(engine);

      triggers.scheduleRetryIfNeeded(_retryableFail);
      async.flushMicrotasks();
      expect(engine.runCount, 0, reason: '调度后不立即重跑（首次失败由调用方触发）');

      async.elapse(const Duration(seconds: 1)); // 第 1 次退避（1s）→ 重跑（仍失败）
      async.flushMicrotasks();
      expect(engine.runCount, 1);

      async.elapse(const Duration(seconds: 2)); // 第 2 次退避（2s）→ 重跑（仍失败）
      async.flushMicrotasks();
      expect(engine.runCount, 2);

      async.elapse(const Duration(seconds: 4)); // 第 3 次退避（4s）→ 重跑（成功）
      async.flushMicrotasks();
      expect(engine.runCount, 3);

      // 成功 → 链终止：再无定时器触发。
      async.elapse(const Duration(minutes: 1));
      async.flushMicrotasks();
      expect(engine.runCount, 3);
    });
  });

  test('不可重试失败 → 不调度退避（不重跑）', () {
    fakeAsync((async) {
      final engine = _StubEngine(
        repository: repo,
        results: [const SyncResult(ok: true)],
      );
      final triggers = buildTriggers(engine);

      triggers.scheduleRetryIfNeeded(
        const SyncResult(
          ok: false,
          retryable: false,
          errorCode: SyncErrorCode.auth,
        ),
      );
      async.flushMicrotasks();
      expect(engine.runCount, 0);

      async.elapse(const Duration(minutes: 1));
      async.flushMicrotasks();
      expect(engine.runCount, 0, reason: '认证类错误不可重试');
    });
  });

  test('成功 → 停止并清零；后续可重试失败重新从 1s 起算', () {
    fakeAsync((async) {
      final engine = _StubEngine(
        repository: repo,
        results: [
          const SyncResult(ok: true), // 链 1 重跑（成功 → 停止）
          _retryableFail, // 链 2 第一次重跑（失败 → 继续 2s 退避）
          const SyncResult(ok: true), // 链 2 第二次重跑（成功 → 停止）
        ],
      );
      final triggers = buildTriggers(engine);

      // 链 1：可重试失败 → 1s 退避 → 重跑成功 → 停止（计数清零）。
      triggers.scheduleRetryIfNeeded(_retryableFail);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(engine.runCount, 1);

      // 计数已清零 → 链 2 从 1s 重新起算（而非 2s+）。
      triggers.scheduleRetryIfNeeded(_retryableFail);
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 500));
      expect(engine.runCount, 1, reason: '1s 前不应重跑（计数已清零）');
      async.elapse(const Duration(milliseconds: 500));
      async.flushMicrotasks();
      expect(engine.runCount, 2, reason: '链 2 从 1s 起算（而非 2s）');

      // 收尾：链 2 重跑失败 → 2s 退避 → 重跑成功 → 停止。
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(engine.runCount, 3);
    });
  });

  test('wifiOnly 且当前非 WiFi → 跳过自动重试（不重跑）', () {
    fakeAsync((async) {
      final engine = _StubEngine(
        repository: repo,
        results: [const SyncResult(ok: true)],
        config: const SyncConfig(enabled: true, wifiOnly: true),
      );
      final triggers = buildTriggers(engine, wifiAllowed: false);

      triggers.scheduleRetryIfNeeded(_retryableFail);
      async.flushMicrotasks();
      expect(engine.runCount, 0);

      async.elapse(const Duration(minutes: 1));
      async.flushMicrotasks();
      expect(engine.runCount, 0, reason: '非 WiFi 时自动重试被 wifiOnly 拦截');
    });
  });

  test('wifiOnly 且当前非 WiFi → 启动/回前台自动同步被跳过（_allowAuto 链路）', () {
    fakeAsync((async) {
      final engine = _StubEngine(
        repository: repo,
        results: [const SyncResult(ok: true)],
        config: const SyncConfig(
          enabled: true,
          autoOnStart: true,
          wifiOnly: true,
        ),
      );
      final triggers = buildTriggers(engine, wifiAllowed: false);

      triggers.runOnStart();
      async.flushMicrotasks();
      expect(engine.runCount, 0, reason: '非 WiFi 时启动自动同步被 wifiOnly 拦截');

      triggers.runOnResume();
      async.flushMicrotasks();
      expect(engine.runCount, 0, reason: '非 WiFi 时回前台自动同步被 wifiOnly 拦截');
    });
  });

  test('wifiOnly 且当前为 WiFi → 回前台自动同步正常执行', () {
    fakeAsync((async) {
      final engine = _StubEngine(
        repository: repo,
        results: [const SyncResult(ok: true)],
        config: const SyncConfig(enabled: true, wifiOnly: true),
      );
      final triggers = buildTriggers(engine, wifiAllowed: true);

      triggers.runOnResume();
      async.flushMicrotasks();
      expect(engine.runCount, 1, reason: 'WiFi 时自动同步应正常执行');
    });
  });

  test('同一退避链最多 5 次重试（1+2+4+8+16s）后停止；新触发才重新起链', () {
    fakeAsync((async) {
      final engine = _StubEngine(
        repository: repo,
        results: List.filled(8, _retryableFail),
      );
      final triggers = buildTriggers(engine);

      triggers.scheduleRetryIfNeeded(_retryableFail);
      async.flushMicrotasks();
      // 5 次重试分别在 1、3、7、15、31 秒触发。
      async.elapse(const Duration(seconds: 31));
      async.flushMicrotasks();
      expect(engine.runCount, 5, reason: '单链最多 5 次退避重试');

      // 无新触发 → 不再自动重跑。
      async.elapse(const Duration(minutes: 1));
      async.flushMicrotasks();
      expect(engine.runCount, 5);

      // 新的一次失败（如用户再次手动触发）→ 重新起链。
      triggers.scheduleRetryIfNeeded(_retryableFail);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(engine.runCount, 6);
    });
  });
}
