import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

/// 应用数据库（docs/30-architecture.md §2）。
///
/// schemaVersion = 6；迁移用 `MigrationStrategy.onUpgrade` 逐步执行
/// （docs/40-data-model.md §8）。v2：tasks 新增 priority 列；
/// v3：projects 新增 description 列（默认 ''）；
/// v4：新增 folders 表 + projects 新增 folderId 列（NULL = 未分组）；
/// v5：新增 custom_views 表（docs/65-custom-views-and-panels.md §4.3）；
/// v6：projects 新增 icon 列，folders 新增 icon 与 color 列。
@DriftDatabase(
  tables: [Projects, Folders, Tasks, Tags, TaskTags, Settings, CustomViews],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// 应用侧连接（drift_flutter，数据库文件位于应用文档目录 `todo.sqlite`）。
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'todo'));

  /// 测试用内存数据库（或注入自定义 [executor]）。
  factory AppDatabase.forTesting({QueryExecutor? executor}) =>
      AppDatabase(executor ?? NativeDatabase.memory());

  @override
  int get schemaVersion => 7;

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
    },
    beforeOpen: (details) async {
      // 开启外键约束（Drift 默认关闭，需应用层显式开启）。
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
