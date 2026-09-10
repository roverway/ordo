import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import '../db/repositories/todo_repository.dart';
import '../db/tables.dart';
import '../sync/merge_engine.dart';
import '../sync/snapshot.dart';
import '../sync/snapshot_codec.dart';
import 'backup_codec.dart';

/// 导入模式枚举。
enum ImportMode {
  /// 全新覆盖模式（完全清空现有数据与同步墓碑，使用备份数据全量重建）。
  replace,

  /// 增量合并模式（基于 LWW 时间戳算法合流，保留双方最新数据）。
  merge,
}

/// 备份数据摘要信息（供 UI 弹窗展示）。
class BackupSummary {
  const BackupSummary({
    required this.exportedAt,
    required this.taskCount,
    required this.projectCount,
    required this.tagCount,
    required this.folderCount,
    required this.customViewCount,
    required this.snapshot,
  });

  /// 备份导出时间（UTC 毫秒）。
  final int exportedAt;

  /// 活跃任务数。
  final int taskCount;

  /// 清单数。
  final int projectCount;

  /// 标签数。
  final int tagCount;

  /// 文件夹数。
  final int folderCount;

  /// 自定义视图数。
  final int customViewCount;

  /// 解析后的完整快照。
  final SnapshotData snapshot;
}

/// 数据导入导出与灾难恢复服务。
class BackupRestoreService {
  BackupRestoreService(this._repository);

  final TodoRepository _repository;

  AppDatabase get _db => _repository.database;

  /// 生成当前活动数据的内存快照 [SnapshotData]。
  Future<SnapshotData> exportToSnapshot() async {
    final exportData = await _repository.exportAll();
    final deviceId =
        await _repository.settings.get('device_id') ?? const Uuid().v4();
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    return SnapshotData(
      schemaVersion: kSnapshotSchemaVersion,
      deviceId: deviceId,
      exportedAt: nowMs,
      projects: [
        for (final p in exportData.projects)
          ProjectRecord(
            id: p.id,
            name: p.name,
            color: p.color,
            description: p.description,
            icon: p.icon,
            folderId: p.folderId,
            sortOrder: p.sortOrder,
            createdAt: p.createdAt,
            updatedAt: p.updatedAt,
            deleted: false,
          ),
      ],
      tasks: [
        for (final t in exportData.tasks)
          TaskRecord(
            id: t.id,
            projectId: t.projectId,
            parentId: t.parentId,
            title: t.title,
            description: t.description,
            notes: t.notes,
            startAt: t.startAt,
            endAt: t.endAt,
            completedAt: t.completedAt,
            status: t.status.index,
            priority: t.priority.index,
            sortOrder: t.sortOrder,
            createdAt: t.createdAt,
            updatedAt: t.updatedAt,
            deleted: false,
            tagIds: exportData.taskTagIds[t.id] ?? const [],
          ),
      ],
      tags: [
        for (final t in exportData.tags)
          TagRecord(
            id: t.id,
            name: t.name,
            color: t.color,
            sortOrder: t.sortOrder,
            createdAt: t.createdAt,
            updatedAt: t.updatedAt,
            deleted: false,
          ),
      ],
      folders: [
        for (final f in exportData.folders)
          FolderRecord(
            id: f.id,
            name: f.name,
            color: f.color,
            icon: f.icon,
            sortOrder: f.sortOrder,
            createdAt: f.createdAt,
            updatedAt: f.updatedAt,
            deleted: false,
          ),
      ],
      customViews: [
        for (final cv in exportData.customViews)
          CustomViewRecord(
            id: cv.id,
            name: cv.name,
            icon: cv.icon,
            color: cv.color,
            sortOrder: cv.sortOrder,
            layoutMode: cv.layoutMode,
            panelsJson: cv.panelsJson,
            createdAt: cv.createdAt,
            updatedAt: cv.updatedAt,
            deleted: false,
          ),
      ],
    );
  }

  /// 将当前活动数据打包导出为 `.ordobak` 二进制。
  Future<Uint8List> exportToBytes() async {
    final snapshot = await exportToSnapshot();
    return encodeBackup(snapshot);
  }

  /// 检查并解包备份文件，返回摘要信息（不产生写操作）。
  BackupSummary inspectBackup(Uint8List bytes) {
    final snapshot = decodeBackup(bytes);
    final activeTasks = snapshot.tasks.where((t) => !t.deleted).length;
    final activeProjects = snapshot.projects.where((p) => !p.deleted).length;
    final activeTags = snapshot.tags.where((t) => !t.deleted).length;
    final activeFolders = snapshot.folders.where((f) => !f.deleted).length;
    final activeCustomViews = snapshot.customViews
        .where((cv) => !cv.deleted)
        .length;

    return BackupSummary(
      exportedAt: snapshot.exportedAt,
      taskCount: activeTasks,
      projectCount: activeProjects,
      tagCount: activeTags,
      folderCount: activeFolders,
      customViewCount: activeCustomViews,
      snapshot: snapshot,
    );
  }

  /// 导入备份数据。
  ///
  /// [onBeforeRestore]：在开始对数据库进行任何写入操作前执行的回调，
  /// 用于触发自动前置保护快照生成。
  Future<void> importBackup(
    Uint8List bytes, {
    required ImportMode mode,
    Future<void> Function()? onBeforeRestore,
  }) async {
    final snapshot = decodeBackup(bytes);

    if (onBeforeRestore != null) {
      await onBeforeRestore();
    }

    if (mode == ImportMode.replace) {
      await _executeReplaceImport(snapshot);
    } else {
      await _executeMergeImport(snapshot);
    }

    await _repository.onDataChanged?.call();
  }

  /// 执行覆盖恢复。
  Future<void> _executeReplaceImport(SnapshotData snapshot) async {
    await _db.transaction(() async {
      // 1. 逆序物理清空现有活跃数据（遵守外键约束）
      await _db.delete(_db.taskTags).go();
      await _db.delete(_db.tasks).go();
      await _db.delete(_db.customViews).go();
      await _db.delete(_db.projects).go();
      await _db.delete(_db.folders).go();
      await _db.delete(_db.tags).go();

      // 2. 清除设置中的历史同步墓碑与远端基准状态，确保不会被旧删除墓碑冲刷
      await _repository.settings.remove('sync_tombstones');

      // 3. 按拓扑依赖顺序写入备份实体
      // 3.1 文件夹
      for (final f in snapshot.folders) {
        if (f.deleted) continue;
        await _db
            .into(_db.folders)
            .insertOnConflictUpdate(
              FoldersCompanion.insert(
                id: f.id,
                name: f.name,
                color: Value(f.color),
                icon: Value(f.icon),
                sortOrder: f.sortOrder,
                createdAt: f.createdAt,
                updatedAt: f.updatedAt,
              ),
            );
      }

      // 3.2 自定义视图
      for (final cv in snapshot.customViews) {
        if (cv.deleted) continue;
        await _db
            .into(_db.customViews)
            .insertOnConflictUpdate(
              CustomViewsCompanion.insert(
                id: cv.id,
                name: cv.name,
                icon: Value(cv.icon),
                color: Value(cv.color),
                sortOrder: Value(cv.sortOrder),
                layoutMode: Value(cv.layoutMode),
                panelsJson: cv.panelsJson,
                createdAt: cv.createdAt,
                updatedAt: cv.updatedAt,
              ),
            );
      }

      // 3.3 标签
      for (final t in snapshot.tags) {
        if (t.deleted) continue;
        await _db
            .into(_db.tags)
            .insertOnConflictUpdate(
              TagsCompanion.insert(
                id: t.id,
                name: t.name,
                color: t.color,
                sortOrder: t.sortOrder,
                createdAt: t.createdAt,
                updatedAt: t.updatedAt,
              ),
            );
      }

      // 3.4 清单
      final validFolderIds = {
        for (final f in snapshot.folders)
          if (!f.deleted) f.id,
      };
      for (final p in snapshot.projects) {
        if (p.deleted) continue;
        final folderId =
            (p.folderId != null && validFolderIds.contains(p.folderId))
            ? p.folderId
            : null;
        await _db
            .into(_db.projects)
            .insertOnConflictUpdate(
              ProjectsCompanion.insert(
                id: p.id,
                name: p.name,
                color: p.color,
                description: Value(p.description),
                icon: Value(p.icon),
                folderId: Value(folderId),
                sortOrder: p.sortOrder,
                createdAt: p.createdAt,
                updatedAt: p.updatedAt,
              ),
            );
      }

      // 3.5 任务（按父子层级排序，先父后子）
      final validProjectIds = {
        for (final p in snapshot.projects)
          if (!p.deleted) p.id,
      };
      final activeTasks = [
        for (final t in snapshot.tasks)
          if (!t.deleted && validProjectIds.contains(t.projectId)) t,
      ];
      final activeTaskMap = {for (final t in activeTasks) t.id: t};

      int depthOf(TaskRecord task, Set<String> visited) {
        if (task.parentId == null ||
            !activeTaskMap.containsKey(task.parentId)) {
          return 0;
        }
        if (visited.contains(task.id)) return 0;
        visited.add(task.id);
        final parent = activeTaskMap[task.parentId!];
        if (parent == null) return 0;
        return 1 + depthOf(parent, visited);
      }

      activeTasks.sort((a, b) {
        final da = depthOf(a, <String>{});
        final db = depthOf(b, <String>{});
        return da.compareTo(db);
      });

      for (final t in activeTasks) {
        final parentId =
            (t.parentId != null && activeTaskMap.containsKey(t.parentId))
            ? t.parentId
            : null;

        await _db
            .into(_db.tasks)
            .insertOnConflictUpdate(
              TasksCompanion.insert(
                id: t.id,
                projectId: t.projectId,
                parentId: Value(parentId),
                title: t.title,
                description: Value(t.description),
                notes: Value(t.notes),
                startAt: Value(t.startAt),
                endAt: Value(t.endAt),
                completedAt: Value(t.completedAt),
                status: _taskStatusFromIndex(t.status),
                priority: Value(_taskPriorityFromIndex(t.priority)),
                sortOrder: t.sortOrder,
                createdAt: t.createdAt,
                updatedAt: t.updatedAt,
              ),
            );
      }

      // 3.6 任务标签关联
      final validTagIds = {
        for (final t in snapshot.tags)
          if (!t.deleted) t.id,
      };
      for (final t in activeTasks) {
        final tagIds = t.tagIds.where(validTagIds.contains).toList();
        if (tagIds.isNotEmpty) {
          await _db.batch((b) {
            b.insertAll(_db.taskTags, [
              for (final tagId in tagIds)
                TaskTagsCompanion.insert(taskId: t.id, tagId: tagId),
            ]);
          });
        }
      }
    });
  }

  /// 执行增量合并。
  Future<void> _executeMergeImport(SnapshotData importedSnapshot) async {
    final localSnapshot = await exportToSnapshot();
    final deviceId = localSnapshot.deviceId;

    // 1. 调用纯函数 MergeEngine.merge
    final merged = merge(
      localSnapshot,
      importedSnapshot,
      localDeviceId: deviceId,
      remoteDeviceId: importedSnapshot.deviceId,
    );

    // 2. 转换为 MergedApplyOperation
    final ops = _opsFromMerged(merged);

    // 3. 应用到仓库
    await _repository.applyMerged(ops);
  }

  MergedApplyOperation _opsFromMerged(SnapshotData merged) {
    final upsertProjects = <Project>[];
    final upsertTasks = <Task>[];
    final upsertTags = <Tag>[];
    final upsertFolders = <Folder>[];
    final upsertCustomViews = <CustomView>[];
    final hardDeleteProjectIds = <String>[];
    final hardDeleteTaskIds = <String>[];
    final hardDeleteTagIds = <String>[];
    final hardDeleteFolderIds = <String>[];
    final hardDeleteCustomViewIds = <String>[];
    final taskTagLinks = <String, List<String>>{};

    for (final p in merged.projects) {
      if (p.deleted) {
        hardDeleteProjectIds.add(p.id);
      } else {
        upsertProjects.add(
          Project(
            id: p.id,
            name: p.name,
            color: p.color,
            description: p.description,
            icon: p.icon,
            folderId: p.folderId,
            sortOrder: p.sortOrder,
            createdAt: p.createdAt,
            updatedAt: p.updatedAt,
            deleted: 0,
          ),
        );
      }
    }

    for (final t in merged.tasks) {
      if (t.deleted) {
        hardDeleteTaskIds.add(t.id);
      } else {
        upsertTasks.add(
          Task(
            id: t.id,
            projectId: t.projectId,
            parentId: t.parentId,
            title: t.title,
            description: t.description,
            notes: t.notes,
            startAt: t.startAt,
            endAt: t.endAt,
            completedAt: t.completedAt,
            status: _taskStatusFromIndex(t.status),
            priority: _taskPriorityFromIndex(t.priority),
            sortOrder: t.sortOrder,
            createdAt: t.createdAt,
            updatedAt: t.updatedAt,
            deleted: 0,
          ),
        );
        taskTagLinks[t.id] = t.tagIds;
      }
    }

    for (final t in merged.tags) {
      if (t.deleted) {
        hardDeleteTagIds.add(t.id);
      } else {
        upsertTags.add(
          Tag(
            id: t.id,
            name: t.name,
            color: t.color,
            sortOrder: t.sortOrder,
            createdAt: t.createdAt,
            updatedAt: t.updatedAt,
            deleted: 0,
          ),
        );
      }
    }

    for (final f in merged.folders) {
      if (f.deleted) {
        hardDeleteFolderIds.add(f.id);
      } else {
        upsertFolders.add(
          Folder(
            id: f.id,
            name: f.name,
            sortOrder: f.sortOrder,
            createdAt: f.createdAt,
            updatedAt: f.updatedAt,
            deleted: 0,
          ),
        );
      }
    }

    for (final cv in merged.customViews) {
      if (cv.deleted) {
        hardDeleteCustomViewIds.add(cv.id);
      } else {
        upsertCustomViews.add(
          CustomView(
            id: cv.id,
            name: cv.name,
            icon: cv.icon,
            color: cv.color,
            sortOrder: cv.sortOrder,
            layoutMode: cv.layoutMode,
            panelsJson: cv.panelsJson,
            createdAt: cv.createdAt,
            updatedAt: cv.updatedAt,
            deleted: 0,
          ),
        );
      }
    }

    return MergedApplyOperation(
      upsertProjects: upsertProjects,
      upsertTasks: upsertTasks,
      upsertTags: upsertTags,
      upsertFolders: upsertFolders,
      upsertCustomViews: upsertCustomViews,
      hardDeleteProjectIds: hardDeleteProjectIds,
      hardDeleteTaskIds: hardDeleteTaskIds,
      hardDeleteTagIds: hardDeleteTagIds,
      hardDeleteFolderIds: hardDeleteFolderIds,
      hardDeleteCustomViewIds: hardDeleteCustomViewIds,
      taskTagLinks: taskTagLinks,
    );
  }

  TaskStatus _taskStatusFromIndex(int index) =>
      (index >= 0 && index < TaskStatus.values.length)
      ? TaskStatus.values[index]
      : TaskStatus.todo;

  TaskPriority _taskPriorityFromIndex(int index) =>
      (index >= 0 && index < TaskPriority.values.length)
      ? TaskPriority.values[index]
      : TaskPriority.none;
}
