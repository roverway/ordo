import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/backup/backup_codec.dart';
import 'package:todo/core/backup/backup_restore_service.dart';
import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/repositories/todo_repository.dart';
import 'package:todo/core/sync/snapshot.dart';
import 'package:todo/core/sync/snapshot_codec.dart';

import '../../helpers/db_test_setup.dart';

void main() {
  group('BackupRestoreService Tests', () {
    late AppDatabase db;
    late TodoRepository repo;
    late BackupRestoreService service;

    setUp(() {
      db = openTestDatabase();
      repo = TodoRepository(database: db);
      service = BackupRestoreService(repo);
    });

    tearDown(() async {
      await db.close();
    });

    test('全量导出与 inspectBackup 摘要信息准确', () async {
      // 1. 构造测试数据
      final folder = await repo.createFolder(name: '工作区');
      final project = await repo.createProject(
        name: '重要项目',
        color: 0xFF1E88E5,
        folderId: folder.id,
      );
      final tag = await repo.createTag(name: '紧急', color: 0xFFFF0000);
      final task1 = await repo.createTask(projectId: project.id, title: '父任务');
      await repo.tags.setTaskTags(task1.id, [tag.id]);

      await repo.createTask(
        projectId: project.id,
        title: '子任务',
        parentId: task1.id,
      );
      await repo.createCustomView(name: '自定义看板', panelsJson: '[]');

      // 2. 导出
      final bytes = await service.exportToBytes();
      expect(bytes.length, greaterThan(0));

      // 3. 检查摘要
      final summary = service.inspectBackup(bytes);
      expect(summary.folderCount, equals(1));
      expect(summary.projectCount, equals(1));
      expect(summary.tagCount, equals(1));
      expect(summary.taskCount, equals(2));
      expect(summary.customViewCount, equals(1));
    });

    test('覆盖恢复（ImportMode.replace）完全替换数据并清除原有状态', () async {
      // 1. 本地先创建一批待被覆盖的数据
      final oldProj = await repo.createProject(
        name: '将被覆盖的清单',
        color: 0xFF999999,
      );
      await repo.createTask(projectId: oldProj.id, title: '将被覆盖的任务');

      // 2. 构造一份外部备份
      final externalDb = openTestDatabase();
      final externalRepo = TodoRepository(database: externalDb);
      final externalService = BackupRestoreService(externalRepo);

      final extFolder = await externalRepo.createFolder(name: '新文件夹');
      final extProj = await externalRepo.createProject(
        name: '全新清单',
        color: 0xFF43A047,
        folderId: extFolder.id,
      );
      final extTag = await externalRepo.createTag(
        name: '核心标签',
        color: 0xFF00FF00,
      );
      final extTask = await externalRepo.createTask(
        projectId: extProj.id,
        title: '全新任务',
      );
      await externalRepo.tags.setTaskTags(extTask.id, [extTag.id]);

      final backupBytes = await externalService.exportToBytes();
      await externalDb.close();

      // 3. 执行覆盖恢复
      bool beforeCallbackInvoked = false;
      await service.importBackup(
        backupBytes,
        mode: ImportMode.replace,
        onBeforeRestore: () async {
          beforeCallbackInvoked = true;
        },
      );

      expect(beforeCallbackInvoked, isTrue);

      // 4. 验证数据库状态
      final projects = await repo.projects.getAll();
      expect(projects.map((p) => p.name), contains('全新清单'));
      expect(projects.map((p) => p.name), isNot(contains('将被覆盖的清单')));

      final tasks = await repo.tasks.getAllActive();
      expect(tasks.length, equals(1));
      expect(tasks.first.title, equals('全新任务'));
      expect(tasks.first.id, equals(extTask.id));

      final tags = await repo.tags.getAll();
      expect(tags.length, equals(1));
      expect(tags.first.name, equals('核心标签'));

      final taskTags = await repo.tags.tagIdsForTask(tasks.first.id);
      expect(taskTags, equals([extTag.id]));

      final folders = await repo.folders.getAll();
      expect(folders.length, equals(1));
      expect(folders.first.name, equals('新文件夹'));
    });

    test('增量合并（ImportMode.merge）基于 LWW 保留双方最新修改', () async {
      // 1. 本地数据：Task A 更新时间较新 (2000)
      final proj = await repo.createProject(name: '共有清单', color: 0xFF3F51B5);
      final taskA = await repo.createTask(
        projectId: proj.id,
        title: '本地最新修改的任务A',
      );
      // 手动设置 updatedAt 为 2000
      await db.update(db.tasks).replace(taskA.copyWith(updatedAt: 2000));

      // 2. 外部备份数据：Task A 为旧版 (1500)，新增 Task C (1800)
      final externalSnapshot = await service.exportToSnapshot();
      final backupSnapshot = SnapshotData(
        schemaVersion: kSnapshotSchemaVersion,
        deviceId: 'external-device-id',
        exportedAt: 1800,
        projects: [
          const ProjectRecord(
            id: 'proj-c-placeholder',
            name: '备份清单C',
            color: 0xFF123456,
            sortOrder: 0,
            createdAt: 1800,
            updatedAt: 1800,
            deleted: false,
          ),
          for (final p in externalSnapshot.projects) p,
        ],
        tasks: [
          // Task A 的旧版
          TaskRecord(
            id: taskA.id,
            projectId: proj.id,
            title: '备份中的旧版任务A',
            sortOrder: 0,
            createdAt: 1000,
            updatedAt: 1500, // 比本地的 2000 旧
            deleted: false,
          ),
          // Task C 为新任务
          const TaskRecord(
            id: 'task-c',
            projectId: 'proj-c-placeholder',
            title: '来自备份的新任务C',
            sortOrder: 0,
            createdAt: 1800,
            updatedAt: 1800,
            deleted: false,
          ),
        ],
        tags: externalSnapshot.tags,
        folders: externalSnapshot.folders,
        customViews: externalSnapshot.customViews,
      );
      final backupBytes = encodeBackup(backupSnapshot);

      // 3. 执行增量合并
      await service.importBackup(backupBytes, mode: ImportMode.merge);

      // 4. 验证：Task A 保留本地最新标题，Task C 被合入
      final updatedTaskA = await repo.tasks.getById(taskA.id);
      expect(updatedTaskA?.title, equals('本地最新修改的任务A'));

      final taskC = await repo.tasks.getById('task-c');
      expect(taskC, isNotNull);
      expect(taskC?.title, equals('来自备份的新任务C'));
    });
  });
}
