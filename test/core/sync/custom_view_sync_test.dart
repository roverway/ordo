import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/repositories/todo_repository.dart';
import 'package:todo/core/security/secure_store.dart';
import 'package:todo/core/sync/remote_store.dart';
import 'package:todo/core/sync/remote_store_factory.dart';
import 'package:todo/core/sync/sync_config.dart';
import 'package:todo/core/sync/sync_engine.dart';

import '../../helpers/db_test_setup.dart';

class _FakeRemoteStore implements RemoteStore {
  Uint8List? remoteBytes;
  DateTime? remoteModifiedAt;

  @override
  Future<bool> exists() async => remoteBytes != null;

  @override
  Future<Uint8List?> download() async => remoteBytes;

  @override
  Future<void> upload(Uint8List data) async {
    remoteBytes = data;
    remoteModifiedAt = DateTime.now().toUtc();
  }

  @override
  Future<DateTime?> lastModified() async => remoteModifiedAt;

  @override
  Future<DateTime?> serverNow() async => DateTime.now().toUtc();
}

class _FakeRemoteStoreFactory implements RemoteStoreFactory {
  _FakeRemoteStoreFactory(this.store);

  final _FakeRemoteStore store;

  @override
  RemoteStore create(SyncConfig config) => store;
}

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

void main() {
  group('Custom Views Multi-Device Sync', () {
    late AppDatabase dbA;
    late TodoRepository repoA;
    late AppDatabase dbB;
    late TodoRepository repoB;
    late _FakeRemoteStore remoteStore;
    late SecureStore secA;
    late SecureStore secB;
    late SyncEngine engineA;
    late SyncEngine engineB;

    setUp(() async {
      dbA = openTestDatabase();
      repoA = TodoRepository(database: dbA);
      dbB = openTestDatabase();
      repoB = TodoRepository(database: dbB);

      remoteStore = _FakeRemoteStore();
      final factory = _FakeRemoteStoreFactory(remoteStore);

      secA = SecureStore(backend: _InMemoryBackend());
      secB = SecureStore(backend: _InMemoryBackend());

      const cfg = SyncConfig(
        type: RemoteType.webdav,
        serverUrl: 'https://example.com/dav',
        username: 'user',
        secret: 'pass',
      );
      await secA.writeCreds(cfg);
      await secB.writeCreds(cfg);
      await repoA.settings.set(SyncSettingsKeys.type, 'webdav');
      await repoB.settings.set(SyncSettingsKeys.type, 'webdav');
      await repoA.settings.set(SyncSettingsKeys.enabled, '1');
      await repoB.settings.set(SyncSettingsKeys.enabled, '1');

      engineA = SyncEngine(
        repository: repoA,
        secureStore: secA,
        remoteStoreFactory: factory,
      );
      engineB = SyncEngine(
        repository: repoB,
        secureStore: secB,
        remoteStoreFactory: factory,
      );
    });

    tearDown(() async {
      await dbA.close();
      await dbB.close();
    });

    test(
      'Device A creates custom view -> sync -> Device B receives custom view',
      () async {
        // 1. A 端创建视图
        final viewA = await repoA.createCustomView(
          name: '工作看板',
          icon: 'dashboard',
          color: 0xFF123456,
          layoutMode: 'kanban',
          panelsJson: '[{"id":"p1","title":"待办"}]',
        );

        // 2. A 端同步（上传）
        final resA = await engineA.run();
        expect(resA.ok, isTrue);
        expect(await remoteStore.exists(), isTrue);

        // 3. B 端同步（下载合并）
        final resB = await engineB.run();
        expect(resB.ok, isTrue);

        // 4. 断言 B 端拥有相同自定义视图
        final viewB = await repoB.customViews.getById(viewA.id);
        expect(viewB, isNotNull);
        expect(viewB!.name, '工作看板');
        expect(viewB.icon, 'dashboard');
        expect(viewB.color, 0xFF123456);
        expect(viewB.layoutMode, 'kanban');
        expect(viewB.panelsJson, '[{"id":"p1","title":"待办"}]');
      },
    );

    test(
      'Device B deletes custom view -> sync -> Device A receives deletion (tombstone)',
      () async {
        // 1. A 创建并同步给 B
        final view = await repoA.createCustomView(
          name: '待删视图',
          panelsJson: '[]',
        );
        await engineA.run();
        await engineB.run();
        expect(await repoB.customViews.getById(view.id), isNotNull);

        // 2. B 删除并同步
        await repoB.deleteCustomView(view.id);
        final resB = await engineB.run();
        expect(resB.ok, isTrue);

        // 3. A 端同步
        final resA = await engineA.run();
        expect(resA.ok, isTrue);

        // 4. A 端已物理删除
        expect(await repoA.customViews.getById(view.id), isNull);
      },
    );
  });
}
