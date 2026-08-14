// SyncEngine 集成测试（docs/60-sync-design.md §14 场景 1–10 + 额外）。
//
// 架构（docs/30-architecture.md §8）：FakeRemoteStore（implements RemoteStore）
// + 真实 MergeEngine + 内存 DB（NativeDatabase.memory），SecureStore 用内存
// Fake 后端（secure_store_test.dart 同款注入方式），RemoteStoreFactory 用
// Fake 工厂（implements 返回 FakeRemoteStore），SyncConfig 直接构造写入
// settings + 凭据，不依赖真实网络。
//
// 覆盖：
//   1  本地新增 → 远端快照含新记录
//   2  远端新增 → 本地出现新记录
//   3  两端改同一 id → 取 updatedAt 大者
//   4  一端删除 → 墓碑传播（远端含 deleted=true；另一端同步后本地删除）
//   5  首次同步：本地空+远端有 → 下载
//   6  首次同步：本地有+远端空 → 上传
//   7  schemaVersion 不匹配 → 拒绝 + 错误态
//   8  标签删除后合并 → tagIds 悬空引用清理
//   9  并发：upload 前远端被改 → 重新下载合并后上传
//   10 快照损坏（decode 抛 FormatException）→ 不覆盖远端，错误可重试
// 额外：上传优化（内容无变化跳过 upload）、认证失败不重试、
//       时钟偏差被拒本地库不变、未启用 → skipped。
// 文件夹（62-folder-nav.md §5.4）：文件夹增删改跨端同步、项目移动后
//       folderId 传播、一端删除文件夹后另一端项目归属修复。

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/repositories/todo_repository.dart';
import 'package:todo/core/security/secure_store.dart';
import 'package:todo/core/sync/remote_store.dart';
import 'package:todo/core/sync/remote_store_factory.dart';
import 'package:todo/core/sync/snapshot.dart';
import 'package:todo/core/sync/snapshot_codec.dart';
import 'package:todo/core/sync/sync_config.dart';
import 'package:todo/core/sync/sync_engine.dart';
import 'package:todo/core/sync/sync_exceptions.dart';

import '../../helpers/db_test_setup.dart';

// ─────────────────────────── Fake RemoteStore ───────────────────────────

/// 内存 Fake 远端存储：upload/download/exists/lastModified/serverNow 全在
/// 内存完成，支持错误注入与并发写入钩子。
class FakeRemoteStore implements RemoteStore {
  Uint8List? remoteBytes;
  DateTime? remoteModifiedAt;

  /// `serverNow()` 返回值；null = 模拟「无法获取服务器时间」（如 S3，
  /// §11 A 检跳过）。
  DateTime? serverNowValue;
  int serverNowCount = 0;

  int uploadCount = 0;
  int downloadCount = 0;
  int existsCount = 0;
  int lastModifiedCount = 0;

  Exception? existsError;
  Exception? downloadError;
  Exception? uploadError;

  /// 每次 lastModified() 调用前触发（测试注入并发写入）。
  Future<void> Function()? onBeforeLastModified;

  @override
  Future<bool> exists() async {
    existsCount++;
    if (existsError != null) throw existsError!;
    return remoteBytes != null;
  }

  @override
  Future<Uint8List?> download() async {
    downloadCount++;
    if (downloadError != null) throw downloadError!;
    return remoteBytes;
  }

  @override
  Future<void> upload(Uint8List data) async {
    if (uploadError != null) throw uploadError!;
    uploadCount++;
    simulateExternalUpload(data);
  }

  @override
  Future<DateTime?> lastModified() async {
    lastModifiedCount++;
    if (onBeforeLastModified != null) await onBeforeLastModified!();
    return remoteModifiedAt;
  }

  @override
  Future<DateTime?> serverNow() async {
    serverNowCount++;
    return serverNowValue;
  }

  /// 模拟另一设备并发上传（不计数 [uploadCount]）。
  void simulateExternalUpload(Uint8List data) {
    remoteBytes = data;
    remoteModifiedAt = DateTime.now().toUtc();
  }
}

/// Fake 工厂：无论配置返回同一个 [FakeRemoteStore]。
class FakeRemoteStoreFactory implements RemoteStoreFactory {
  FakeRemoteStoreFactory(this.store);

  final FakeRemoteStore store;

  @override
  RemoteStore create(SyncConfig config) => store;
}

/// Fake 工厂：create 时抛 [SyncConfigException]（模拟本地配置无效 §9.3）。
class _ConfigErrorFactory implements RemoteStoreFactory {
  @override
  RemoteStore create(SyncConfig config) =>
      throw const SyncConfigException('WebDAV 配置缺少服务器地址');
}

/// 内存安全存储后端（同 secure_store_test.dart 注入方式）。
class _InMemoryBackend implements SecureKeyValueStore {
  final Map<String, String> store = {};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async {
    store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    store.remove(key);
  }
}

/// 读操作抛 [SecureStoreException] 的后端（模拟安全存储故障，§12 配置类）。
class _ThrowingReadBackend implements SecureKeyValueStore {
  @override
  Future<String?> read(String key) async =>
      throw SecureStoreException('模拟安全存储读取故障');

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}
}

// ─────────────────────────── 快照构造辅助 ───────────────────────────

SnapshotData remoteSnapshot({
  String deviceId = 'remote-device',
  int? exportedAt,
  List<ProjectRecord> projects = const [],
  List<TaskRecord> tasks = const [],
  List<TagRecord> tags = const [],
  List<FolderRecord> folders = const [],
}) {
  return SnapshotData(
    schemaVersion: kSnapshotSchemaVersion,
    deviceId: deviceId,
    exportedAt: exportedAt ?? DateTime.now().toUtc().millisecondsSinceEpoch,
    projects: projects,
    tasks: tasks,
    tags: tags,
    folders: folders,
  );
}

ProjectRecord projectRec({
  required String id,
  String name = 'P',
  int color = 0,
  String? folderId,
  int updatedAt = 100,
  int createdAt = 1,
  bool deleted = false,
}) {
  return ProjectRecord(
    id: id,
    name: name,
    color: color,
    folderId: folderId,
    sortOrder: 0,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted,
  );
}

TaskRecord taskRec({
  required String id,
  String projectId = '',
  String title = 'T',
  String description = '',
  int updatedAt = 100,
  int createdAt = 1,
  bool deleted = false,
  List<String> tagIds = const [],
}) {
  return TaskRecord(
    id: id,
    projectId: projectId,
    title: title,
    description: description,
    sortOrder: 0,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted,
    tagIds: tagIds,
  );
}

TagRecord tagRec({
  required String id,
  String name = 'TAG',
  int updatedAt = 100,
  int createdAt = 1,
  bool deleted = false,
}) {
  return TagRecord(
    id: id,
    name: name,
    color: 0,
    sortOrder: 0,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted,
  );
}

FolderRecord folderRec({
  required String id,
  String name = 'FOLDER',
  int updatedAt = 100,
  int createdAt = 1,
  bool deleted = false,
}) {
  return FolderRecord(
    id: id,
    name: name,
    sortOrder: 0,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted,
  );
}

/// 生成低压缩率随机串（固定种子，确定性）：
/// 随机字母数字在 gzip 下几乎不压缩（≈ 原始体积），用于构造 gzip 后
/// ≥256KB 的大快照，确保走 NFR-02 的 isolate 解析路径。
String _lowCompressString(int length) {
  const alphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rand = Random(42);
  final sb = StringBuffer();
  for (var i = 0; i < length; i++) {
    sb.write(alphabet[rand.nextInt(alphabet.length)]);
  }
  return sb.toString();
}

// ─────────────────────────── 测试主体 ───────────────────────────

void main() {
  late AppDatabase db;
  late TodoRepository repo;
  late _InMemoryBackend secureBackend;
  late SecureStore secureStore;
  late FakeRemoteStore remote;
  late List<SyncState> stateLog;
  late int fixedNowMs;

  setUp(() {
    db = openTestDatabase();
    repo = TodoRepository(database: db);
    secureBackend = _InMemoryBackend();
    secureStore = SecureStore(backend: secureBackend);
    remote = FakeRemoteStore();
    stateLog = [];
    fixedNowMs = 0; // 0 → 真实时钟；非 0 → 固定时钟（上传优化测试用）。
  });

  tearDown(() async {
    await db.close();
  });

  /// 构造 SyncEngine（可指定独立设备 DB 模拟另一端）。
  Future<SyncEngine> buildEngine({
    TodoRepository? repository,
    Future<bool> Function()? confirmClockSkew,
  }) async {
    return SyncEngine(
      repository: repository ?? repo,
      secureStore: secureStore,
      remoteStoreFactory: FakeRemoteStoreFactory(remote),
      confirmClockSkew: confirmClockSkew,
      onStateChanged: stateLog.add,
      now: () => DateTime.fromMillisecondsSinceEpoch(
        fixedNowMs == 0 ? DateTime.now().millisecondsSinceEpoch : fixedNowMs,
        isUtc: true,
      ),
    );
  }

  /// 启用 webdav 同步（settings 非敏感项 + 安全存储凭据）。
  Future<void> enableSync(TodoRepository r) async {
    await r.settings.set(SyncSettingsKeys.type, 'webdav');
    await r.settings.set(SyncSettingsKeys.enabled, '1');
    await secureStore.writeCreds(
      const SyncConfig(
        type: RemoteType.webdav,
        serverUrl: 'https://dav.example.com/todo/',
        username: 'user',
        secret: 'pass',
      ),
    );
  }

  /// 注入远端快照（同时更新 lastModified，保证读改写判定稳定）。
  void seedRemote(SnapshotData snap) {
    remote.simulateExternalUpload(encodeSnapshot(snap));
  }

  Uint8List encode(SnapshotData snap) => encodeSnapshot(snap);

  SnapshotData decode(Uint8List bytes) => decodeSnapshot(bytes);

  group('§14 场景 1/2：单侧新增', () {
    test('场景 1：本地新增 → 同步 → 远端快照含新记录', () async {
      await enableSync(repo);
      final p = await repo.createProject(name: '项目', color: 0xFF0000);
      final t = await repo.createTask(projectId: p.id, title: '任务');

      final engine = await buildEngine();
      final result = await engine.run();

      expect(result.ok, isTrue);
      expect(remote.uploadCount, 1);
      final snap = decode(remote.remoteBytes!);
      expect(snap.projects.map((x) => x.id), [p.id]);
      expect(snap.tasks.map((x) => x.id), [t.id]);
      expect(snap.tasks.single.title, '任务');
      expect(snap.projects.single.deleted, isFalse);
      // 成功路径：errorCode 为空。
      expect(result.errorCode, isNull);
      expect(engine.state.errorCode, isNull);
      // 成功写 lastSyncedAt + 状态回调。
      expect(await repo.settings.get(SyncSettingsKeys.lastSyncedAt), isNotNull);
      expect(stateLog.last.status, SyncStateStatus.success);
    });

    test('场景 2：远端新增 → 同步 → 本地出现新记录', () async {
      await enableSync(repo);
      seedRemote(
        remoteSnapshot(
          projects: [projectRec(id: 'p-remote', name: '远端项目')],
          tasks: [
            taskRec(id: 't-remote', projectId: 'p-remote', title: '远端任务'),
          ],
        ),
      );

      final engine = await buildEngine();
      final result = await engine.run();

      expect(result.ok, isTrue);
      final localP = (await repo.projects.getById('p-remote'))!;
      expect(localP.name, '远端项目');
      final localT = (await repo.tasks.getById('t-remote'))!;
      expect(localT.title, '远端任务');
      expect(remote.downloadCount, 1);
      // 本地空 → 分支 A，不上传。
      expect(remote.uploadCount, 0);
    });
  });

  group('§14 场景 3：两端改同一 id', () {
    test('场景 3：取 updatedAt 大者（远端更新更晚 → 远端胜）', () async {
      await enableSync(repo);
      final p = await repo.createProject(name: '本地名', color: 0);
      seedRemote(
        remoteSnapshot(
          projects: [
            projectRec(
              id: p.id,
              name: '远端名',
              updatedAt: p.updatedAt + 5000,
              createdAt: p.createdAt,
            ),
          ],
        ),
      );

      final engine = await buildEngine();
      final result = await engine.run();

      expect(result.ok, isTrue);
      final localP = (await repo.projects.getById(p.id))!;
      expect(localP.name, '远端名');
      expect(localP.updatedAt, p.updatedAt + 5000);
      // 合并结果上传回远端。
      expect(decode(remote.remoteBytes!).projects.single.name, '远端名');
    });
  });

  group('§14 场景 4：一端删除 → 墓碑传播', () {
    test('场景 4：墓碑传播到远端快照，另一端同步后本地删除', () async {
      await enableSync(repo);
      final p = await repo.createProject(name: 'P', color: 0);
      final t = await repo.createTask(projectId: p.id, title: 'T');

      // 设备 A 首次同步（上传任务）。
      final engineA = await buildEngine();
      await engineA.run();
      expect(decode(remote.remoteBytes!).tasks.single.deleted, isFalse);

      // 设备 B：独立 DB，首次同步下载任务。
      final dbB = openTestDatabase();
      addTearDown(dbB.close);
      final repoB = TodoRepository(database: dbB);
      await enableSync(repoB);
      final engineB = await buildEngine(repository: repoB);
      await engineB.run();
      expect((await repoB.tasks.getById(t.id))!.title, 'T');

      // 设备 A 删除任务 → 墓碑 → 再同步（远端快照含 deleted=true）。
      await repo.deleteTask(t.id);
      await engineA.run();
      final remoteTomb = decode(
        remote.remoteBytes!,
      ).tasks.singleWhere((x) => x.id == t.id);
      expect(remoteTomb.deleted, isTrue);

      // 设备 B 再同步 → 本地硬删该任务。
      await engineB.run();
      expect(await repoB.tasks.getById(t.id), isNull);
      // 墓碑保留在 B 的本地墓碑集合（要传播给远端，D1）。
      final tomsB = await repoB.readTombstones();
      expect(tomsB.any((e) => e.type == 'task' && e.id == t.id), isTrue);
    });
  });

  group('§14 场景 5/6：首次同步分支', () {
    test('场景 5：本地空 + 远端有 → 下载应用', () async {
      await enableSync(repo);
      seedRemote(
        remoteSnapshot(
          projects: [projectRec(id: 'p1', name: '远端项目')],
        ),
      );

      final engine = await buildEngine();
      final result = await engine.run();

      expect(result.ok, isTrue);
      expect(remote.downloadCount, 1);
      expect(remote.uploadCount, 0);
      expect((await repo.projects.getById('p1'))!.name, '远端项目');
    });

    test('场景 6：本地有 + 远端空 → 上传', () async {
      await enableSync(repo);
      final p = await repo.createProject(name: 'P', color: 0);

      final engine = await buildEngine();
      final result = await engine.run();

      expect(result.ok, isTrue);
      expect(remote.uploadCount, 1);
      expect(remote.downloadCount, 0);
      expect(decode(remote.remoteBytes!).projects.single.id, p.id);
    });
  });

  group('§14 场景 7：schemaVersion 不匹配', () {
    test('场景 7：拒绝 + 错误态，不覆盖远端、本地库不变', () async {
      await enableSync(repo);
      final p = await repo.createProject(name: 'P', color: 0);
      seedRemote(
        SnapshotData(
          schemaVersion: 99,
          deviceId: 'remote',
          exportedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
        ),
      );

      final engine = await buildEngine();
      final result = await engine.run();

      expect(result.ok, isFalse);
      expect(result.retryable, isFalse);
      expect(engine.state.status, SyncStateStatus.error);
      expect(result.errorCode, SyncErrorCode.schemaMismatch);
      expect(engine.state.errorCode, SyncErrorCode.schemaMismatch);
      expect(engine.state.errorMessage, contains('版本'));
      expect(remote.uploadCount, 0, reason: 'schema 不匹配不得覆盖远端');
      expect(remote.remoteBytes, isNotNull);
      expect((await repo.projects.getById(p.id))!.name, 'P');
    });
  });

  group('§14 场景 8：标签删除后合并 → tagIds 悬空引用清理', () {
    test('场景 8：悬空引用被清理，标签硬删，任务保留', () async {
      await enableSync(repo);
      final tag = await repo.createTag(name: '标签', color: 0);
      final p = await repo.createProject(name: 'P', color: 0);
      final t = await repo.createTask(projectId: p.id, title: 'T');
      await repo.tags.setTaskTags(t.id, [tag.id]);
      expect(await repo.tags.tagIdsForTask(t.id), [tag.id]);

      // 设备 A 同步上传。
      final engineA = await buildEngine();
      await engineA.run();

      // 设备 B 首次同步下载（任务+标签+关联）。
      final dbB = openTestDatabase();
      addTearDown(dbB.close);
      final repoB = TodoRepository(database: dbB);
      await enableSync(repoB);
      final engineB = await buildEngine(repository: repoB);
      await engineB.run();
      expect((await repoB.tags.getById(tag.id))!.name, '标签');
      expect(await repoB.tags.tagIdsForTask(t.id), [tag.id]);

      // 设备 A 删除标签 → 墓碑 → 同步。
      await repo.deleteTag(tag.id);
      await engineA.run();

      // 设备 B 再同步 → 标签硬删、任务的 tagIds 悬空引用被清理。
      await engineB.run();
      expect(await repoB.tags.getById(tag.id), isNull);
      expect(await repoB.tags.tagIdsForTask(t.id), isEmpty);
      expect((await repoB.tasks.getById(t.id))!.title, 'T');
    });
  });

  group('§5.4 文件夹跨端同步（62-folder-nav.md）', () {
    test('文件夹增删改跨端同步（创建/重命名/删除 → 墓碑传播 + 他端硬删）', () async {
      await enableSync(repo);
      final f = await repo.createFolder(name: '工作');
      final engineA = await buildEngine();
      await engineA.run();
      // A 上传后远端快照含文件夹。
      expect(decode(remote.remoteBytes!).folders.map((x) => x.id), [f.id]);
      expect(decode(remote.remoteBytes!).folders.single.name, '工作');

      // B 首次同步 → 文件夹出现。
      final dbB = openTestDatabase();
      addTearDown(dbB.close);
      final repoB = TodoRepository(database: dbB);
      await enableSync(repoB);
      final engineB = await buildEngine(repository: repoB);
      await engineB.run();
      expect((await repoB.folders.getById(f.id))!.name, '工作');

      // A 重命名 → 同步 → B 同步后名称更新。
      await repo.renameFolder(f.id, name: '工作夹');
      await engineA.run();
      expect(decode(remote.remoteBytes!).folders.single.name, '工作夹');
      await engineB.run();
      expect((await repoB.folders.getById(f.id))!.name, '工作夹');

      // A 删除文件夹 → 同步 → 远端含 deleted=true 文件夹墓碑。
      await repo.deleteFolder(f.id);
      await engineA.run();
      final remoteTomb = decode(
        remote.remoteBytes!,
      ).folders.singleWhere((x) => x.id == f.id);
      expect(remoteTomb.deleted, isTrue);

      // B 再同步 → 文件夹行硬删 + 文件夹墓碑保留在 B 的本地墓碑集合。
      await engineB.run();
      expect(await repoB.folders.getById(f.id), isNull);
      final tomsB = await repoB.readTombstones();
      expect(tomsB.any((e) => e.type == 'folder' && e.id == f.id), isTrue);
    });

    test('项目移动入夹后 folderId 跨端传播（远端快照含 folderId + B 端落库）', () async {
      await enableSync(repo);
      final f = await repo.createFolder(name: '归档');
      final p = await repo.createProject(name: 'P', color: 0);
      await repo.moveProjectToFolder(p.id, folderId: f.id, newIndex: 0);

      final engineA = await buildEngine();
      await engineA.run();

      // 远端快照：folder 记录 + project.folderId 指向该文件夹。
      final snap = decode(remote.remoteBytes!);
      expect(snap.folders.single.id, f.id);
      expect(snap.projects.singleWhere((x) => x.id == p.id).folderId, f.id);

      // B 同步 → 本地项目 folderId 与文件夹一致。
      final dbB = openTestDatabase();
      addTearDown(dbB.close);
      final repoB = TodoRepository(database: dbB);
      await enableSync(repoB);
      final engineB = await buildEngine(repository: repoB);
      await engineB.run();
      expect((await repoB.projects.getById(p.id))!.folderId, f.id);
      expect((await repoB.folders.getById(f.id))!.name, '归档');
    });

    test('一端删除文件夹 → 另一端项目归属修复（folderId 置 null 回未分组）', () async {
      await enableSync(repo);
      final f = await repo.createFolder(name: '归档');
      final p = await repo.createProject(name: 'P', color: 0);
      await repo.moveProjectToFolder(p.id, folderId: f.id, newIndex: 0);
      final engineA = await buildEngine();
      await engineA.run();

      // B 首次同步：folder + 项目挂载成功。
      final dbB = openTestDatabase();
      addTearDown(dbB.close);
      final repoB = TodoRepository(database: dbB);
      await enableSync(repoB);
      final engineB = await buildEngine(repository: repoB);
      await engineB.run();
      expect((await repoB.projects.getById(p.id))!.folderId, f.id);

      // A 删除文件夹（仅解除收纳，D3）→ 本地项目回未分组 → 同步。
      await repo.deleteFolder(f.id);
      expect(
        (await repo.projects.getById(p.id))!.folderId,
        isNull,
        reason: 'A 本地项目回未分组',
      );
      await engineA.run();

      // B 再同步 → 文件夹硬删、项目 folderId 修复为 null（reconcileFolderIds）。
      await engineB.run();
      expect(await repoB.folders.getById(f.id), isNull);
      expect(
        (await repoB.projects.getById(p.id))!.folderId,
        isNull,
        reason: 'B 端项目归属修复为未分组',
      );
    });
  });

  group('§14 场景 9：并发（读改写）', () {
    test('场景 9：upload 前远端被改 → 重新下载合并后上传', () async {
      await enableSync(repo);
      final p = await repo.createProject(name: 'P', color: 0);
      final engine = await buildEngine();

      // 第一次同步：远端空 → 上传本地。
      await engine.run();
      expect(remote.uploadCount, 1);
      expect(remote.downloadCount, 0);

      // 第二次同步（分支 C）：在 upload 前的 lastModified 检查时注入并发写。
      var lmCalls = 0;
      remote.onBeforeLastModified = () async {
        lmCalls++;
        if (lmCalls == 2) {
          // 模拟另一设备恰在此时上传了新快照。
          remote.simulateExternalUpload(
            encode(
              remoteSnapshot(
                deviceId: 'other-device',
                projects: [projectRec(id: 'p-other', name: '另一设备项目')],
              ),
            ),
          );
        }
      };

      final result = await engine.run();

      expect(result.ok, isTrue);
      // 并发写被检出 → 重新下载合并（≥2 次下载）。
      expect(remote.downloadCount, greaterThanOrEqualTo(2));
      expect(remote.uploadCount, greaterThan(1), reason: '并发写后应重新上传');
      // 最终远端同时包含两端记录。
      final finalSnap = decode(remote.remoteBytes!);
      expect(
        finalSnap.projects.map((x) => x.id),
        containsAll(['p-other', p.id]),
      );
      // 本地也获得远端记录。
      expect((await repo.projects.getById('p-other'))!.name, '另一设备项目');
    });
  });

  group('§14 场景 10：快照损坏', () {
    test('场景 10：不覆盖远端，错误可重试，本地库不变', () async {
      await enableSync(repo);
      final p = await repo.createProject(name: 'P', color: 0);
      // 非法 gzip 字节。
      final corrupt = Uint8List.fromList([1, 2, 3, 4, 5]);
      remote.simulateExternalUpload(corrupt);

      final engine = await buildEngine();
      final result = await engine.run();

      expect(result.ok, isFalse);
      expect(result.retryable, isTrue);
      expect(engine.state.status, SyncStateStatus.error);
      expect(result.errorCode, SyncErrorCode.snapshotCorrupt);
      expect(engine.state.errorCode, SyncErrorCode.snapshotCorrupt);
      expect(engine.state.errorMessage, contains('远端数据异常'));
      expect(remote.uploadCount, 0, reason: '损坏快照不得被覆盖');
      expect(remote.remoteBytes, corrupt);
      expect((await repo.projects.getById(p.id))!.name, 'P');
    });
  });

  group('NFR-02：大快照（≥256KB）走 isolate 解析', () {
    // sync_engine.dart 的 _kIsolateDecodeThresholdBytes = 256KB。既有测试
    // （场景 1–10）快照均低于阈值，恒走同步解析路径；本组专测 isolate 路径
    // （compute → Isolate.run）的解析成功与异常原类型冒泡。
    const isolateThresholdBytes = 256 * 1024;

    late Uint8List largeBytes;
    late String bigDesc;

    setUp(() {
      // ~512KB 低压缩率描述 → gzip 后 ≥256KB，确保到达 isolate 阈值。
      bigDesc = _lowCompressString(512 * 1024);
      largeBytes = encode(
        remoteSnapshot(
          projects: [projectRec(id: 'p-big', name: '大快照项目')],
          tasks: [
            taskRec(
              id: 't-big',
              projectId: 'p-big',
              title: '大快照任务',
              description: bigDesc,
            ),
          ],
        ),
      );
    });

    test('大快照在 isolate 中解析成功并应用', () async {
      expect(
        largeBytes.length,
        greaterThanOrEqualTo(isolateThresholdBytes),
        reason: '用例前置：快照字节数必须达到 isolate 阈值',
      );
      await enableSync(repo);
      remote.simulateExternalUpload(largeBytes);

      final engine = await buildEngine();
      final result = await engine.run();

      expect(result.ok, isTrue);
      expect(engine.state.status, SyncStateStatus.success);
      final localT = (await repo.tasks.getById('t-big'))!;
      expect(localT.title, '大快照任务');
      expect(localT.description, bigDesc, reason: 'isolate 解析内容应完整落库');
      // 本地空 → 分支 A，不上传。
      expect(remote.uploadCount, 0);
    });

    test('大快照损坏：FormatException 跨 isolate 原类型冒泡 → snapshotCorrupt', () async {
      await enableSync(repo);
      // 翻转 gzip 中间字节 → GZipCodec.decode 在 isolate 内抛 FormatException。
      final corrupt = Uint8List.fromList(largeBytes);
      corrupt[corrupt.length ~/ 2] ^= 0xFF;
      remote.simulateExternalUpload(corrupt);

      final engine = await buildEngine();
      final result = await engine.run();

      expect(result.ok, isFalse);
      expect(result.retryable, isTrue);
      expect(
        result.errorCode,
        SyncErrorCode.snapshotCorrupt,
        reason: 'compute 抛出的 FormatException 应以原类型命中 §12 catch',
      );
      expect(engine.state.errorCode, SyncErrorCode.snapshotCorrupt);
      expect(remote.uploadCount, 0, reason: '损坏快照不得被覆盖');
    });

    test(
      '大快照 schemaVersion 不匹配：SnapshotSchemaException 跨 isolate 原类型冒泡 → schemaMismatch',
      () async {
        await enableSync(repo);
        await repo.createProject(name: 'P', color: 0); // 本地非空 → 分支 C。
        final badBytes = encode(
          SnapshotData(
            schemaVersion: 99,
            deviceId: 'remote',
            exportedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
            projects: [projectRec(id: 'p-big', name: '大快照项目')],
            tasks: [
              taskRec(id: 't-big', projectId: 'p-big', description: bigDesc),
            ],
          ),
        );
        expect(
          badBytes.length,
          greaterThanOrEqualTo(isolateThresholdBytes),
          reason: '用例前置：快照字节数必须达到 isolate 阈值',
        );
        remote.simulateExternalUpload(badBytes);

        final engine = await buildEngine();
        final result = await engine.run();

        expect(result.ok, isFalse);
        expect(result.retryable, isFalse);
        expect(
          result.errorCode,
          SyncErrorCode.schemaMismatch,
          reason: 'compute 抛出的 SnapshotSchemaException 应以原类型命中 §12 catch',
        );
        expect(engine.state.errorCode, SyncErrorCode.schemaMismatch);
        expect(remote.uploadCount, 0, reason: 'schema 不匹配不得覆盖远端');
        expect(
          (await repo.projects.getById('p-big')),
          isNull,
          reason: '本地库不变（大快照未应用）',
        );
      },
    );
  });

  group('额外', () {
    test('上传优化：业务内容无变化 → 跳过 upload（上传次数不增）', () async {
      await enableSync(repo);
      final p = await repo.createProject(name: 'P', color: 0);
      // 真实时钟：两次 run 的 exportedAt 必然不同，但业务 hash 排除
      // exportedAt/deviceId → 内容无变化时应跳过上传（此前旧用例只能靠
      // 固定时钟通过，正是评审缺陷 1 的根因）。
      final engine = await buildEngine();

      final r1 = await engine.run();
      expect(r1.ok, isTrue);
      expect(remote.uploadCount, 1);

      // 无本地改动，再次同步 → 业务内容一致 → 跳过上传。
      final r2 = await engine.run();
      expect(r2.ok, isTrue);
      expect(remote.uploadCount, 1, reason: '业务内容无变化应跳过 upload');
      // 仍记成功（lastSyncedAt 更新），本地数据完好。
      expect(await repo.settings.get(SyncSettingsKeys.lastSyncedAt), isNotNull);
      expect((await repo.projects.getById(p.id))!.name, 'P');
    });

    test('上传优化：有业务变更 → 正常上传（不错误跳过）', () async {
      await enableSync(repo);
      await repo.createProject(name: 'P', color: 0);
      final engine = await buildEngine();
      await engine.run();
      expect(remote.uploadCount, 1);

      // 本地新增项目（业务变更）→ 再次同步必须上传。
      final p2 = await repo.createProject(name: 'P2', color: 0xFF0000);
      final r2 = await engine.run();
      expect(r2.ok, isTrue);
      expect(remote.uploadCount, 2, reason: '业务变更必须上传');
      expect(
        decode(remote.remoteBytes!).projects.map((x) => x.id),
        contains(p2.id),
      );
    });

    test('上传优化：远端被外部设备改写 → 业务 hash 变化 → 正常上传', () async {
      await enableSync(repo);
      final p = await repo.createProject(name: 'P', color: 0);
      final engine = await buildEngine();
      await engine.run();
      expect(remote.uploadCount, 1);

      // 另一设备改写远端快照（新增项目 p-other，deviceId 不同）。
      remote.simulateExternalUpload(
        encode(
          remoteSnapshot(
            deviceId: 'other-device',
            projects: [projectRec(id: 'p-other', name: '另一设备项目')],
          ),
        ),
      );

      final r2 = await engine.run();
      expect(r2.ok, isTrue);
      // 合并后本地内容与远端不同 → 必须上传（不得错误跳过）。
      expect(remote.uploadCount, 2, reason: '远端被改写应重新上传');
      final finalSnap = decode(remote.remoteBytes!);
      expect(
        finalSnap.projects.map((x) => x.id),
        containsAll([p.id, 'p-other']),
      );
      // 本地也获得远端记录。
      expect((await repo.projects.getById('p-other'))!.name, '另一设备项目');
    });

    test('认证失败 → 不重试（retryable=false），错误态', () async {
      await enableSync(repo);
      await repo.createProject(name: 'P', color: 0);
      remote.uploadError = const SyncAuthException('认证失败，请检查账号与密码');

      final engine = await buildEngine();
      final result = await engine.run();

      expect(result.ok, isFalse);
      expect(result.retryable, isFalse);
      expect(engine.state.status, SyncStateStatus.error);
      expect(result.errorCode, SyncErrorCode.auth);
      expect(engine.state.errorCode, SyncErrorCode.auth);
      expect(engine.state.errorMessage, contains('认证'));
      // 本地库不变、lastSyncedAt 不丢（未成功过则保持 null）。
      expect(await repo.settings.get(SyncSettingsKeys.lastSyncedAt), isNull);
    });

    test('网络失败 → network 错误码，可重试', () async {
      await enableSync(repo);
      await repo.createProject(name: 'P', color: 0);
      remote.existsError = const SyncNetworkException('网络连接失败或超时');

      final engine = await buildEngine();
      final result = await engine.run();

      expect(result.ok, isFalse);
      expect(result.retryable, isTrue);
      expect(result.errorCode, SyncErrorCode.network);
      expect(engine.state.status, SyncStateStatus.error);
      expect(engine.state.errorCode, SyncErrorCode.network);
      expect(await repo.settings.get(SyncSettingsKeys.lastSyncedAt), isNull);
    });

    test('远端 HTTP 错误 → remote 错误码，可重试', () async {
      await enableSync(repo);
      await repo.createProject(name: 'P', color: 0);
      remote.existsError = const SyncRemoteException('远端返回 HTTP 500');

      final engine = await buildEngine();
      final result = await engine.run();

      expect(result.ok, isFalse);
      expect(result.retryable, isTrue);
      expect(result.errorCode, SyncErrorCode.remote);
      expect(engine.state.status, SyncStateStatus.error);
      expect(engine.state.errorCode, SyncErrorCode.remote);
    });

    test('本地配置无效 → config 错误码，不重试', () async {
      await enableSync(repo);
      await repo.createProject(name: 'P', color: 0);

      final engine = SyncEngine(
        repository: repo,
        secureStore: secureStore,
        remoteStoreFactory: _ConfigErrorFactory(),
        onStateChanged: stateLog.add,
        now: () => DateTime.now().toUtc(),
      );
      final result = await engine.run();

      expect(result.ok, isFalse);
      expect(result.retryable, isFalse);
      expect(result.errorCode, SyncErrorCode.config);
      expect(engine.state.status, SyncStateStatus.error);
      expect(engine.state.errorCode, SyncErrorCode.config);
      expect(await repo.settings.get(SyncSettingsKeys.lastSyncedAt), isNull);
    });

    test('安全存储读取失败 → config 错误码（本地配置类，不重试）', () async {
      await enableSync(repo); // 凭据先正常写入（仅让 read 抛错）。
      await repo.createProject(name: 'P', color: 0);

      final engine = SyncEngine(
        repository: repo,
        secureStore: SecureStore(backend: _ThrowingReadBackend()),
        remoteStoreFactory: FakeRemoteStoreFactory(remote),
        onStateChanged: stateLog.add,
        now: () => DateTime.now().toUtc(),
      );
      final result = await engine.run();

      // SecureStoreException 必须映射为 config（而非 unknown 兜底）。
      expect(result.ok, isFalse);
      expect(result.retryable, isFalse);
      expect(result.errorCode, SyncErrorCode.config);
      expect(engine.state.status, SyncStateStatus.error);
      expect(engine.state.errorCode, SyncErrorCode.config);
      expect(remote.existsCount, 0, reason: '配置错误不应触碰远端');
      expect(await repo.settings.get(SyncSettingsKeys.lastSyncedAt), isNull);
    });

    test('未预期异常 → unknown 错误码，不重试', () async {
      await enableSync(repo);
      await repo.createProject(name: 'P', color: 0);
      remote.existsError = Exception('unexpected boom');

      final engine = await buildEngine();
      final result = await engine.run();

      expect(result.ok, isFalse);
      expect(result.retryable, isFalse);
      expect(result.errorCode, SyncErrorCode.unknown);
      expect(engine.state.status, SyncStateStatus.error);
      expect(engine.state.errorCode, SyncErrorCode.unknown);
      expect(await repo.settings.get(SyncSettingsKeys.lastSyncedAt), isNull);
    });

    test('时钟偏差被拒（A 检：本地 vs 服务器时钟差 >5min）→ 中止，本地库不变', () async {
      await enableSync(repo);
      final p = await repo.createProject(name: 'P', color: 0);
      // 远端快照本身健康（exportedAt 与服务器写时刻一致）→ 只触发 A 检。
      seedRemote(
        remoteSnapshot(
          projects: [projectRec(id: 'p-remote', name: '远端项目')],
        ),
      );
      // 本地时钟与服务器时钟偏差 10 分钟（A 检命中）。
      remote.serverNowValue = DateTime.now().toUtc().add(
        const Duration(minutes: 10),
      );

      var confirmed = false;
      final engine = await buildEngine(
        confirmClockSkew: () async {
          confirmed = true;
          return false; // 用户拒绝校准。
        },
      );

      final result = await engine.run();

      expect(confirmed, isTrue, reason: 'A 检命中应触发确认流程');
      expect(result.ok, isFalse);
      expect(engine.state.status, SyncStateStatus.error);
      expect(result.errorCode, SyncErrorCode.clockSkew);
      expect(engine.state.errorCode, SyncErrorCode.clockSkew);
      expect(engine.state.errorMessage, contains('时钟偏差'));
      expect(remote.uploadCount, 0);
      expect((await repo.projects.getById(p.id))!.name, 'P');
      expect(await repo.settings.get(SyncSettingsKeys.lastSyncedAt), isNull);
    });

    test('时钟偏差且 UI 未提供确认回调（null）→ 直接拒绝（A 检）', () async {
      await enableSync(repo);
      final p = await repo.createProject(name: 'P', color: 0);
      seedRemote(
        remoteSnapshot(
          projects: [projectRec(id: 'p-remote', name: '远端项目')],
        ),
      );
      // 本地时钟与服务器时钟偏差 10 分钟（A 检命中）。
      remote.serverNowValue = DateTime.now().toUtc().add(
        const Duration(minutes: 10),
      );

      final engine = await buildEngine(); // confirmClockSkew == null
      final result = await engine.run();

      expect(result.ok, isFalse);
      expect(engine.state.status, SyncStateStatus.error);
      expect(result.errorCode, SyncErrorCode.clockSkew);
      expect(engine.state.errorCode, SyncErrorCode.clockSkew);
      expect((await repo.projects.getById(p.id))!.name, 'P');
    });

    test('快照陈旧但不触发：exportedAt 与服务器写时刻一致（修复回归）', () async {
      await enableSync(repo);
      // 30 分钟前的远端快照——旧实现 |exportedAt - now| >5min 必然误报
      // clockSkew；新语义 exportedAt 与 lastModified 度量同一写时刻 → 不触发。
      final farPast = DateTime.now().toUtc().subtract(
        const Duration(minutes: 30),
      );
      seedRemote(
        remoteSnapshot(
          exportedAt: farPast.millisecondsSinceEpoch,
          projects: [projectRec(id: 'p-stale', name: '旧快照项目')],
        ),
      );
      // 服务器写时刻与 exportedAt 一致（同一写时刻）→ B 检不触发。
      remote.remoteModifiedAt = farPast;
      // 服务器时钟正常 → A 检不触发。
      remote.serverNowValue = DateTime.now().toUtc();

      final engine = await buildEngine();
      final result = await engine.run();

      expect(result.ok, isTrue, reason: '陈旧但时钟健康的快照必须同步成功');
      expect(engine.state.status, SyncStateStatus.success);
      // 本地空 → 分支 A，远端数据应用成功。
      expect((await repo.projects.getById('p-stale'))!.name, '旧快照项目');
    });

    test('对端时钟偏差触发 B 检：exportedAt 与服务器写时刻差 >5min', () async {
      await enableSync(repo);
      // 本地非空 → 分支 C（验证循环内复用 lastModifiedBefore，不重复请求）。
      final p = await repo.createProject(name: 'P', color: 0);
      // 远端快照 exportedAt 为未来 10 分钟（对端时钟偏快）。
      final farFuture = DateTime.now().toUtc().add(const Duration(minutes: 10));
      seedRemote(
        remoteSnapshot(
          deviceId: 'other-device',
          exportedAt: farFuture.millisecondsSinceEpoch,
          projects: [projectRec(id: 'p-other', name: '另一设备项目')],
        ),
      );
      // 服务器时钟正常 → A 检不触发；seedRemote 已把 remoteModifiedAt 设为
      // now，与 exportedAt 差 10 分钟 → B 检触发。
      remote.serverNowValue = DateTime.now().toUtc();

      var confirmed = false;
      final engine = await buildEngine(
        confirmClockSkew: () async {
          confirmed = true;
          return true; // 用户确认校准 → 继续同步。
        },
      );
      final result = await engine.run();

      expect(confirmed, isTrue, reason: 'B 检命中应触发确认流程');
      expect(result.ok, isTrue, reason: '用户确认后应继续同步');
      // 确认后正常合并：远端项目应用到本地。
      expect((await repo.projects.getById('p-other'))!.name, '另一设备项目');
      expect((await repo.projects.getById(p.id))!.name, 'P');
    });

    test('B 检并发写竞态：初判陈旧 mtime 超差但新鲜复检一致 → 同步成功（修复回归）', () async {
      await enableSync(repo);
      // 本地空 → 分支 A。远端快照本身健康（exportedAt = 当前写时刻）。
      final exportedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
      seedRemote(
        remoteSnapshot(
          exportedAt: exportedAt,
          projects: [projectRec(id: 'p-race', name: '远端项目')],
        ),
      );
      // 服务器时钟正常 → A 检不触发。
      remote.serverNowValue = DateTime.now().toUtc();

      // 模拟并发写竞态：第一次 lastModified（download 前取 mtime）返回比
      // exportedAt 早 10 分钟的陈旧值（>5min 容差 → B 检初判命中）；第二次
      // lastModified（_decodeAndVerify 内的新鲜复检）返回与 exportedAt 一致
      // 的当前写时刻 → 复检不超差 → 不得误报时钟偏差。
      final stale = DateTime.fromMillisecondsSinceEpoch(
        exportedAt - const Duration(minutes: 10).inMilliseconds,
        isUtc: true,
      );
      final fresh = DateTime.fromMillisecondsSinceEpoch(
        exportedAt,
        isUtc: true,
      );
      var lmCalls = 0;
      remote.onBeforeLastModified = () async {
        lmCalls++;
        remote.remoteModifiedAt = lmCalls == 1 ? stale : fresh;
      };

      final engine = await buildEngine(); // confirmClockSkew == null
      final result = await engine.run();

      expect(lmCalls, 2, reason: 'download 前一次 + B 检新鲜复检一次');
      expect(result.ok, isTrue, reason: '新鲜复检通过 → 不得误报时钟偏差');
      expect(engine.state.status, SyncStateStatus.success);
      expect(engine.state.errorCode, isNull);
      expect(remote.uploadCount, 0, reason: '本地空 → 分支 A 不上传');
      expect((await repo.projects.getById('p-race'))!.name, '远端项目');
    });

    test('B 检真实对端时钟偏差：新鲜复检仍超差且无确认回调 → 拒绝（复检路径）', () async {
      await enableSync(repo);
      // 本地空 → 分支 A。远端快照 exportedAt = 当前写时刻，但服务器记录的
      // 写时刻比 exportedAt 早 10 分钟（对端时钟偏慢）→ 无论初判还是新鲜
      // 复检均超差 → 真实时钟偏差，应被拒。
      final exportedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
      seedRemote(
        remoteSnapshot(
          deviceId: 'other-device',
          exportedAt: exportedAt,
          projects: [projectRec(id: 'p-skew', name: '另一设备项目')],
        ),
      );
      remote.serverNowValue = DateTime.now().toUtc(); // A 检不触发。
      remote.remoteModifiedAt = DateTime.fromMillisecondsSinceEpoch(
        exportedAt - const Duration(minutes: 10).inMilliseconds,
        isUtc: true,
      );

      final engine = await buildEngine(); // confirmClockSkew == null → 直接拒绝
      final result = await engine.run();

      expect(remote.lastModifiedCount, 2, reason: '初判一次 + 新鲜复检一次');
      expect(result.ok, isFalse);
      expect(engine.state.status, SyncStateStatus.error);
      expect(result.errorCode, SyncErrorCode.clockSkew);
      expect(engine.state.errorCode, SyncErrorCode.clockSkew);
      expect(engine.state.errorMessage, contains('时钟偏差'));
      expect((await repo.projects.getById('p-skew')), isNull);
      expect(await repo.settings.get(SyncSettingsKeys.lastSyncedAt), isNull);
    });

    test('serverNow 为 null（模拟 S3）→ A 检跳过、B 检正常不触发', () async {
      await enableSync(repo);
      // 本地空 → 分支 A（A 检依赖 store.serverNow()）。
      seedRemote(
        remoteSnapshot(
          projects: [projectRec(id: 'p-s3', name: 'S3 项目')],
        ),
      );
      remote.serverNowValue = null; // 模拟 S3：无法获取服务器时间。

      final engine = await buildEngine();
      final result = await engine.run();

      expect(remote.serverNowCount, 1, reason: 'A 检应尝试读取 serverNow');
      expect(result.ok, isTrue);
      expect(engine.state.status, SyncStateStatus.success);
      expect((await repo.projects.getById('p-s3'))!.name, 'S3 项目');
    });

    test('未启用同步 → skipped（不联网、不写库）', () async {
      // 不调用 enableSync：enabled=0。
      await repo.createProject(name: 'P', color: 0);
      final engine = await buildEngine();
      final result = await engine.run();

      expect(result.ok, isFalse);
      expect(result.skipped, isTrue);
      expect(remote.existsCount, 0, reason: '未启用不得触碰远端');
      expect(await repo.settings.get(SyncSettingsKeys.lastSyncedAt), isNull);
    });

    test('防重入：同步进行中再次 run() → 直接返回 skipped', () async {
      await enableSync(repo);
      await repo.createProject(name: 'P', color: 0);
      // 远端有数据 → 首次 run 走分支 C（读改写），可阻塞在 lastModified。
      seedRemote(remoteSnapshot(projects: [projectRec(id: 'p-remote')]));
      final engine = await buildEngine();

      // 首次 run 阻塞在第一次 lastModified 调用，模拟长时间同步。
      final gate = Completer<void>();
      var blockNext = true;
      remote.onBeforeLastModified = () async {
        if (blockNext) {
          blockNext = false;
          await gate.future;
        }
      };

      final first = engine.run();
      // 轮询等待首次 run 进入 syncing 且已停在 lastModified（读改写起点）。
      for (
        var i = 0;
        i < 100 &&
            (engine.state.status != SyncStateStatus.syncing ||
                remote.lastModifiedCount < 1);
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(engine.state.status, SyncStateStatus.syncing);
      expect(remote.lastModifiedCount, 1, reason: '首次 run 应已停在 lastModified');

      // 重入 → 直接返回 skipped（不等待、不排队）。
      final second = await engine.run();
      expect(second.ok, isFalse);
      expect(second.skipped, isTrue, reason: '重入应直接返回');
      expect(second.errorCode, SyncErrorCode.skippedRunning);

      gate.complete();
      final firstResult = await first;
      expect(firstResult.ok, isTrue);
    });
  });
}
