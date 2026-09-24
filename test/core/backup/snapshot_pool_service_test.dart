import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/backup/backup_restore_service.dart';
import 'package:ordo/core/backup/snapshot_pool_service.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/repositories/todo_repository.dart';

import '../../helpers/db_test_setup.dart';

void main() {
  group('SnapshotPoolService Tests', () {
    late AppDatabase db;
    late TodoRepository repo;
    late BackupRestoreService backupService;
    late SnapshotPoolService poolService;
    late Directory tempDir;

    setUp(() async {
      db = openTestDatabase();
      repo = TodoRepository(database: db);
      await repo.ensureInboxProject('收件箱');
      backupService = BackupRestoreService(repo);
      tempDir = await Directory.systemTemp.createTemp('ordo_snapshot_test_');

      poolService = SnapshotPoolService(
        backupService: backupService,
        settings: repo.settings,
        getDirectory: () async => tempDir,
      );
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('创建快照并能列出正确元数据', () async {
      await repo.createProject(name: '测试项目', color: 0xFF123456);
      await repo.createTask(title: '待办项');

      final snap = await poolService.createSnapshot(
        trigger: SnapshotTriggerType.dailyAuto,
      );

      expect(snap.triggerType, equals(SnapshotTriggerType.dailyAuto));
      expect(snap.taskCount, equals(1));
      expect(snap.projectCount, equals(2)); // 收件箱 + 测试项目
      expect(snap.fileName, contains('_daily.ordobak'));

      final list = await poolService.listSnapshots();
      expect(list.length, equals(1));
      expect(list.first.filePath, equals(snap.filePath));
    });

    test('多快照排序与手动删除', () async {
      await repo.createProject(name: '项目A', color: 0xFF111111);

      final snap1 = await poolService.createSnapshot(
        trigger: SnapshotTriggerType.manual,
      );
      // 微小延时确保时间戳不同
      await Future.delayed(const Duration(milliseconds: 1100));
      final snap2 = await poolService.createSnapshot(
        trigger: SnapshotTriggerType.preSync,
      );

      final list = await poolService.listSnapshots();
      expect(list.length, equals(2));
      // 最新的排第一
      expect(list.first.fileName, equals(snap2.fileName));
      expect(list.last.fileName, equals(snap1.fileName));

      // 删除第一个
      await poolService.deleteSnapshot(snap2.filePath);
      final listAfterDelete = await poolService.listSnapshots();
      expect(listAfterDelete.length, equals(1));
      expect(listAfterDelete.first.fileName, equals(snap1.fileName));
    });

    test('过期快照清理算法与保底策略', () async {
      // 设置保留天数为 3 天
      await poolService.setRetentionDays(3);
      expect(await poolService.getRetentionDays(), equals(3));

      final bytes = await backupService.exportToBytes();

      // 模拟 10 天前的快照文件
      final oldFile = File(
        '${tempDir.path}/snap_20260801_120000_daily.ordobak',
      );
      await oldFile.writeAsBytes(bytes);

      // 模拟当天的快照文件
      final nowStr = SnapshotPoolService.formatTimestamp(DateTime.now());
      final newFile = File('${tempDir.path}/snap_${nowStr}_manual.ordobak');
      await newFile.writeAsBytes(bytes);

      var list = await poolService.listSnapshots();
      expect(list.length, equals(2));

      // 触发清理
      await poolService.pruneExpiredSnapshots();

      list = await poolService.listSnapshots();
      expect(list.length, equals(1));
      expect(list.first.fileName, equals('snap_${nowStr}_manual.ordobak'));
      expect(await oldFile.exists(), isFalse);

      // 模拟所有快照都过期（例如只剩 1 个超期快照）
      // 保底策略：绝不删空，至少留存 1 份
      await poolService.pruneExpiredSnapshots();
      list = await poolService.listSnapshots();
      expect(list.length, equals(1));
    });

    test('从快照还原前自动生成 preRestore 安全快照', () async {
      // 1. 状态 1：有 1 个原始清单
      await repo.createProject(name: '原始项目', color: 0xFF0000FF);
      final snapOriginal = await poolService.createSnapshot(
        trigger: SnapshotTriggerType.manual,
      );

      // 2. 状态 2：新增 1 个新项目，模拟误操作
      await repo.createProject(name: '误操作项目', color: 0xFFFF0000);
      expect(
        (await repo.projects.getAll()).map((p) => p.name),
        contains('误操作项目'),
      );

      // 3. 从快照 1 执行覆盖还原
      await poolService.restoreFromSnapshot(
        snapOriginal.filePath,
        mode: ImportMode.replace,
      );

      // 4. 验证数据已还原到原始状态
      final projects = await repo.projects.getAll();
      expect(projects.map((p) => p.name), contains('原始项目'));
      expect(projects.map((p) => p.name), isNot(contains('误操作项目')));

      // 5. 验证自动生成了 preRestore 保护快照
      final allSnaps = await poolService.listSnapshots();
      final preRestoreSnaps = allSnaps.where(
        (s) => s.triggerType == SnapshotTriggerType.preRestore,
      );
      expect(preRestoreSnaps, isNotEmpty);
    });
  });
}
