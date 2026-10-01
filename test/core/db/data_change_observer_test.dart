import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/db/db_providers.dart';
import 'package:ordo/core/db/tables.dart';
import 'package:ordo/core/sync/sync_engine.dart';
import 'package:ordo/core/sync/sync_triggers.dart';
import 'package:ordo/features/sync_setup/sync_setup_providers.dart';

import '../../helpers/db_test_setup.dart';

class _FakeObserver implements DataChangeObserver {
  int changeCount = 0;

  @override
  Future<void> onDataChanged() async {
    changeCount++;
  }
}

class _FakeSyncEngine implements SyncEngine {
  int runCount = 0;

  @override
  Future<SyncResult> run() async {
    runCount++;
    return const SyncResult(ok: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DataChangeObserver DIP 解耦测试 (docs/98 §4)', () {
    test('TodoRepository 写操作触发 dataChangeObserver', () async {
      final db = openTestDatabase();
      addTearDown(() => db.close());
      final repo = TodoRepository(database: db);

      final observer = _FakeObserver();
      repo.dataChangeObserver = observer;

      expect(observer.changeCount, 0);

      // 创建项目触发通知
      final p = await repo.createProject(name: '测试项目', color: 0xFF123456);
      expect(observer.changeCount, 1);

      // 创建任务触发通知
      final t = await repo.createTask(projectId: p.id, title: '测试任务');
      expect(observer.changeCount, 2);

      // 更新任务状态触发通知
      await repo.updateTask(t.id, status: TaskStatus.done);
      expect(observer.changeCount, 3);

      // 删除任务触发通知
      await repo.deleteTask(t.id);
      expect(observer.changeCount, 4);
    });

    test('SyncTriggers 实现 DataChangeObserver 契约', () async {
      final fakeEngine = _FakeSyncEngine();
      final triggers = SyncTriggers(
        engine: fakeEngine,
        isWifiAllowed: () async => true,
      );
      addTearDown(() => triggers.dispose());

      expect(triggers, isA<DataChangeObserver>());
    });

    test('syncTriggersProvider 自动装配 dataChangeObserver 且生命周期安全', () async {
      final container = ProviderContainer(
        overrides: [syncEngineProvider.overrideWithValue(_FakeSyncEngine())],
      );
      addTearDown(() => container.dispose());

      final repo = container.read(todoRepositoryProvider);
      expect(repo.dataChangeObserver, isNull);

      // 读取 syncTriggersProvider 建立连接
      final triggers = container.read(syncTriggersProvider);
      expect(repo.dataChangeObserver, same(triggers));
    });
  });
}
