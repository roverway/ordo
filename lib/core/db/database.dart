import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

/// 应用数据库（docs/30-architecture.md §2）。
///
/// schemaVersion = 1；迁移用 `MigrationStrategy.onUpgrade` 逐步执行
/// （docs/40-data-model.md §8）。M1 无实际迁移步骤，仅框架。
@DriftDatabase(tables: [Projects, Tasks, Tags, TaskTags, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// 应用侧连接（drift_flutter，数据库文件位于应用文档目录 `todo.sqlite`）。
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'todo'));

  /// 测试用内存数据库（或注入自定义 [executor]）。
  factory AppDatabase.forTesting({QueryExecutor? executor}) =>
      AppDatabase(executor ?? NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // M1：无实际迁移步骤，框架预留。
      // 后续版本在此按 m1 → m2 → … 顺序执行（40-data-model.md §8）。
    },
    beforeOpen: (details) async {
      // 开启外键约束（Drift 默认关闭，需应用层显式开启）。
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
