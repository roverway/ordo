import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

/// 应用数据库（docs/30-architecture.md §2）。
///
/// schemaVersion = 7；迁移用 `MigrationStrategy.onUpgrade` 逐步执行
/// （docs/40-data-model.md §8）。v2：tasks 新增 priority 列；
/// v3：projects 新增 description 列（默认 ''）；
/// v4：新增 folders 表 + projects 新增 folderId 列（NULL = 未分组）；
/// v5：新增 custom_views 表（docs/65-custom-views-and-panels.md §4.3）；
/// v6：projects 新增 icon 列，folders 新增 icon 与 color 列；
/// v7：tasks 新增 completedAt 列；
/// v8：tasks/task_tags 新增 5 个复合索引，新增 sync_tombstones 独立表并迁移历史 settings 墓碑。
@DriftDatabase(
  tables: [
    Projects,
    Folders,
    Tasks,
    Tags,
    TaskTags,
    Settings,
    CustomViews,
    SyncTombstones,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// 应用侧连接（drift_flutter，数据库文件位于应用文档目录 `todo.sqlite`）。
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'todo'));

  /// 测试用内存数据库（或注入自定义 [executor]）。
  factory AppDatabase.forTesting({QueryExecutor? executor}) =>
      AppDatabase(executor ?? NativeDatabase.memory());

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // v1 → v2（40-data-model.md §8）：tasks 新增 priority 列（默认 0 = 无优先级）。
      if (from < 2) {
        await m.addColumn(tasks, tasks.priority);
      }
      // v2 → v3（40-data-model.md §8）：projects 新增 description 列（默认 ''）。
      if (from < 3) {
        await m.addColumn(projects, projects.description);
      }
      // v3 → v4（62-folder-nav.md §7.1）：新增 folders 表 + projects.folderId
      // 列（NULL = 未分组）。先建 folders 表再补 FK 列，满足外键依赖。
      if (from < 4) {
        await m.createTable(folders);
        await m.addColumn(projects, projects.folderId);
      }
      // v4 → v5（65-custom-views-and-panels.md §4.3）：新增 custom_views 表。
      if (from < 5) {
        await m.createTable(customViews);
      }
      // v5 → v6：projects 新增 icon 列；folders 新增 icon 与 color 列。
      if (from < 6) {
        await m.addColumn(projects, projects.icon);
        if (from >= 4) {
          await m.addColumn(folders, folders.icon);
          await m.addColumn(folders, folders.color);
        }
      }
      // v6 → v7：tasks 新增 completedAt 列（UTC 毫秒完成时间戳）。
      if (from < 7) {
        await m.addColumn(tasks, tasks.completedAt);
      }
      // v7 → v8（docs/96-code-review P1-1/P1-2）：
      // 1. 为 tasks 与 task_tags 创建高频复合索引；
      // 2. 新增 sync_tombstones 独立表；
      // 3. 将 settings 表历史 'sync_tombstones' JSON 迁移入 sync_tombstones 表。
      if (from < 8) {
        await m.createTable(syncTombstones);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_tasks_deleted_project_order ON tasks(deleted, project_id, sort_order)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_tasks_deleted_parent_order ON tasks(deleted, parent_id, sort_order)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_tasks_deleted_status_order ON tasks(deleted, status, sort_order)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_tasks_deleted_due ON tasks(deleted, end_at, sort_order)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_task_tags_tag_task ON task_tags(tag_id, task_id)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_sync_tombstones_updated_at ON sync_tombstones(updated_at)',
        );

        // 迁移 settings 表历史墓碑 JSON
        final legacyRow = await customSelect(
          "SELECT value FROM settings WHERE key = 'sync_tombstones'",
        ).getSingleOrNull();
        if (legacyRow != null) {
          final rawJson = legacyRow.read<String>('value');
          try {
            final decoded = jsonDecode(rawJson);
            if (decoded is List) {
              for (final item in decoded) {
                if (item is Map) {
                  final entityType = item['type'] as String?;
                  final entityId = item['id'] as String?;
                  final updatedAt = item['updatedAt'] as int?;
                  if (entityType != null &&
                      entityType.isNotEmpty &&
                      entityId != null &&
                      entityId.isNotEmpty &&
                      updatedAt != null) {
                    await into(syncTombstones).insertOnConflictUpdate(
                      SyncTombstonesCompanion.insert(
                        entityType: entityType,
                        entityId: entityId,
                        updatedAt: updatedAt,
                      ),
                    );
                  }
                }
              }
            }
          } catch (_) {
            // 历史损坏数据安全降级忽略
          }
        }
      }
    },
    beforeOpen: (details) async {
      // 开启外键约束（Drift 默认关闭，需应用层显式开启）。
      await customStatement('PRAGMA foreign_keys = ON');
      // 开启 WAL 模式与并发防锁配置（docs/96-code-review P0-1）
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA busy_timeout = 5000');
      await customStatement('PRAGMA synchronous = NORMAL');
    },
  );
}
