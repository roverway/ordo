// 真实 WebDAV 冒烟测试（M4 DoD 手工验证项，自动化版）。
//
// 凭据从环境变量读取，**不硬编码、不落库**（AGENTS.md §3-6）：
//   WEBDAV_BASE_URL  WEBDAV_USER  WEBDAV_PASS
// 任一缺失 → 全部测试跳过（不联网）。
//
// 覆盖 60-sync-design.md §14 场景 1–6，驱动真实 WebDavRemoteStore +
// 真实 RemoteStoreFactory + SyncEngine，在真实服务器（如坚果云）上验证。
// 使用独立子目录 `{baseUrl}todo-live-test/sN/` 隔离各场景，避免污染用户数据。
// 注意：store 传相对 key 后坚果云不会自动建子目录，每个场景开始前显式
// mkdirAll（见 ensureScenarioDir；对已存在目录返回 405 视为成功）。
//
// 注意：本文件仅供临时真实验证；凭据未设置时跳过，不影响常规 `flutter test`。

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/repositories/todo_repository.dart';
import 'package:todo/core/security/secure_store.dart';
import 'package:todo/core/sync/remote_store_factory.dart';
import 'package:todo/core/sync/remote_store_webdav.dart';
import 'package:todo/core/sync/snapshot.dart';
import 'package:todo/core/sync/snapshot_codec.dart';
import 'package:todo/core/sync/sync_config.dart';
import 'package:todo/core/sync/sync_engine.dart';
import 'package:webdav_client/webdav_client.dart';

import '../../helpers/db_test_setup.dart';

// ─────────────────────────── 环境与装配 ───────────────────────────

final String? _envBase = Platform.environment['WEBDAV_BASE_URL'];
final String? _envUser = Platform.environment['WEBDAV_USER'];
final String? _envPass = Platform.environment['WEBDAV_PASS'];
final bool _hasEnv = _envBase != null && _envUser != null && _envPass != null;
final String _skipReason =
    'WEBDAV 环境变量未设置（WEBDAV_BASE_URL/WEBDAV_USER/WEBDAV_PASS）';

String get _liveBase => _envBase!;
String get _liveUser => _envUser!;
String get _livePass => _envPass!;

/// 内存安全存储后端（同 sync_engine_test 注入方式）。
class _InMemoryBackend implements SecureKeyValueStore {
  final Map<String, String> store = {};
  @override
  Future<String?> read(String key) async => store[key];
  @override
  Future<void> write(String key, String value) async => store[key] = value;
  @override
  Future<void> delete(String key) async => store.remove(key);
}

/// 场景隔离：`{baseUrl}todo-live-test/sN/`（baseUrl 已含尾 `/`）。
String _scenarioBaseUrl(int n) => '${_liveBase}todo-live-test/s$n/';

/// 直接构造真实 WebDAV store（读取远端快照用）。
WebDavRemoteStore _liveStore(int n) => WebDavRemoteStore(
  baseUrl: _scenarioBaseUrl(n),
  username: _liveUser,
  password: _livePass,
);

/// 确保场景子目录 `{baseUrl}todo-live-test/sN/` 已存在。
///
/// store 传相对 key 后，坚果云不会自动创建不存在的父目录（write 前的
/// mkdirAll 仅对 key 的父路径生效，而相对 key 无 `/` 时父路径为空被跳过），
/// 故每个场景开始前用原始 webdav_client（非 WebDavRemoteStore）显式建目录。
/// 用 mkdirAll 而非 mkdir：目录已存在时 MKCOL 返回 405（视为成功）、
/// 父目录缺失时 409 分支递归逐级创建，可安全重复调用。
Future<void> ensureScenarioDir(int n) async {
  final client = newClient(_liveBase, user: _liveUser, password: _livePass);
  await client.mkdirAll('todo-live-test/s$n/');
}

SnapshotData _decode(Uint8List? bytes) {
  expect(bytes, isNotNull, reason: '远端快照不应为空');
  return decodeSnapshot(bytes!);
}

void main() {
  late AppDatabase db;
  late TodoRepository repo;
  late _InMemoryBackend secureBackend;
  late SecureStore secureStore;
  late List<SyncState> stateLog;

  setUp(() {
    db = openTestDatabase();
    repo = TodoRepository(database: db);
    secureBackend = _InMemoryBackend();
    secureStore = SecureStore(backend: secureBackend);
    stateLog = [];
  });

  tearDown(() async {
    await db.close();
  });

  /// 启用 webdav 同步（settings + 凭据写入共享安全存储），指向场景 n。
  ///
  /// 引擎 A/B 共享同一个内存 secureStore，凭据写一次即可。
  Future<void> enableSync(int n, {TodoRepository? repository}) async {
    final r = repository ?? repo;
    await r.settings.set(SyncSettingsKeys.type, 'webdav');
    await r.settings.set(SyncSettingsKeys.enabled, '1');
    await secureStore.writeCreds(
      SyncConfig(
        type: RemoteType.webdav,
        serverUrl: _scenarioBaseUrl(n),
        username: _liveUser,
        secret: _livePass,
      ),
    );
  }

  /// 构造真实 SyncEngine（真实 RemoteStoreFactory，共享 secureStore）。
  Future<SyncEngine> buildEngine({TodoRepository? repository}) async {
    return SyncEngine(
      repository: repository ?? repo,
      secureStore: secureStore,
      remoteStoreFactory: const RemoteStoreFactory(),
      onStateChanged: stateLog.add,
    );
  }

  group('§14 真实 WebDAV 场景 1–6', () {
    test(
      '场景 1：本地新增 → 同步 → 远端快照含新记录',
      () async {
        await enableSync(1);
        await ensureScenarioDir(1);
        final p = await repo.createProject(name: 'live-p1', color: 0xFF0000);
        final t = await repo.createTask(projectId: p.id, title: 'live-t1');

        final engine = await buildEngine();
        final result = await engine.run();

        expect(result.ok, isTrue, reason: result.message);
        final snap = _decode(await _liveStore(1).download());
        expect(snap.projects.map((x) => x.id), contains(p.id));
        expect(snap.tasks.map((x) => x.id), contains(t.id));
        expect(snap.tasks.singleWhere((x) => x.id == t.id).title, 'live-t1');
        expect(engine.state.status, SyncStateStatus.success);
        expect(
          await repo.settings.get(SyncSettingsKeys.lastSyncedAt),
          isNotNull,
        );
      },
      skip: _hasEnv ? false : _skipReason,
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      '场景 2：远端新增 → 同步 → 本地出现新记录',
      () async {
        await enableSync(2);
        await ensureScenarioDir(2);
        // 直接向真实远端 PUT 一个快照。
        final seed = SnapshotData(
          schemaVersion: kSnapshotSchemaVersion,
          deviceId: 'remote-device',
          exportedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
          projects: [
            ProjectRecord(
              id: 'p-remote-live',
              name: '远端项目',
              color: 0,
              sortOrder: 0,
              createdAt: 1,
              updatedAt: 1,
              deleted: false,
            ),
          ],
          tasks: [
            TaskRecord(
              id: 't-remote-live',
              projectId: 'p-remote-live',
              title: '远端任务',
              sortOrder: 0,
              createdAt: 1,
              updatedAt: 1,
              deleted: false,
            ),
          ],
        );
        await _liveStore(2).upload(encodeSnapshot(seed));

        final engine = await buildEngine();
        final result = await engine.run();

        expect(result.ok, isTrue, reason: result.message);
        final localP = (await repo.projects.getById('p-remote-live'))!;
        expect(localP.name, '远端项目');
        final localT = (await repo.tasks.getById('t-remote-live'))!;
        expect(localT.title, '远端任务');
      },
      skip: _hasEnv ? false : _skipReason,
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      '场景 3：两端改同一 id → 取 updatedAt 大者',
      () async {
        await enableSync(3);
        await ensureScenarioDir(3);
        final p = await repo.createProject(name: '本地名', color: 0);
        // 远端种子：同 id、updatedAt 更晚的项目。
        final seed = SnapshotData(
          schemaVersion: kSnapshotSchemaVersion,
          deviceId: 'remote-device',
          exportedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
          projects: [
            ProjectRecord(
              id: p.id,
              name: '远端名',
              color: 0,
              sortOrder: 0,
              createdAt: p.createdAt,
              updatedAt: p.updatedAt + 5000,
              deleted: false,
            ),
          ],
        );
        await _liveStore(3).upload(encodeSnapshot(seed));

        final engine = await buildEngine();
        final result = await engine.run();

        expect(result.ok, isTrue, reason: result.message);
        final localP = (await repo.projects.getById(p.id))!;
        expect(localP.name, '远端名');
        expect(localP.updatedAt, p.updatedAt + 5000);
        // 合并结果应回传远端。
        final snap = _decode(await _liveStore(3).download());
        expect(snap.projects.single.name, '远端名');
      },
      skip: _hasEnv ? false : _skipReason,
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      '场景 4：一端删除 → 墓碑传播，另一端同步后本地删除',
      () async {
        await enableSync(4);
        await ensureScenarioDir(4);
        final p = await repo.createProject(name: 'P', color: 0);
        final t = await repo.createTask(projectId: p.id, title: 'T');

        // 设备 A 首次同步（上传任务）。
        final engineA = await buildEngine();
        await engineA.run();

        // 设备 B：独立 DB，首次同步下载任务（共享 secureStore 凭据）。
        final dbB = openTestDatabase();
        addTearDown(dbB.close);
        final repoB = TodoRepository(database: dbB);
        await enableSync(4, repository: repoB);
        final engineB = await buildEngine(repository: repoB);
        await engineB.run();
        expect((await repoB.tasks.getById(t.id))!.title, 'T');

        // 设备 A 删除任务 → 墓碑 → 再同步（远端快照含 deleted=true）。
        await repo.deleteTask(t.id);
        await engineA.run();
        final remoteSnap = _decode(await _liveStore(4).download());
        final remoteTomb = remoteSnap.tasks.singleWhere((x) => x.id == t.id);
        expect(remoteTomb.deleted, isTrue);

        // 设备 B 再同步 → 本地硬删该任务。
        await engineB.run();
        expect(await repoB.tasks.getById(t.id), isNull);
      },
      skip: _hasEnv ? false : _skipReason,
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      '场景 5：首次同步本地空 + 远端有 → 下载应用',
      () async {
        await enableSync(5);
        await ensureScenarioDir(5);
        final seed = SnapshotData(
          schemaVersion: kSnapshotSchemaVersion,
          deviceId: 'remote-device',
          exportedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
          projects: [
            ProjectRecord(
              id: 'p5',
              name: '远端项目5',
              color: 0,
              sortOrder: 0,
              createdAt: 1,
              updatedAt: 1,
              deleted: false,
            ),
          ],
        );
        await _liveStore(5).upload(encodeSnapshot(seed));

        final engine = await buildEngine();
        final result = await engine.run();

        expect(result.ok, isTrue, reason: result.message);
        expect((await repo.projects.getById('p5'))!.name, '远端项目5');
      },
      skip: _hasEnv ? false : _skipReason,
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test(
      '场景 6：首次同步本地有 + 远端空 → 上传本地快照',
      () async {
        await enableSync(6);
        await ensureScenarioDir(6);
        final p = await repo.createProject(name: 'live-p6', color: 0);

        final engine = await buildEngine();
        final result = await engine.run();

        expect(result.ok, isTrue, reason: result.message);
        final snap = _decode(await _liveStore(6).download());
        expect(snap.projects.map((x) => x.id), contains(p.id));
      },
      skip: _hasEnv ? false : _skipReason,
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
