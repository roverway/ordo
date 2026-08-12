// 迁移测试（docs/40-data-model.md §8，70-milestones.md M1 任务 6）。
//
// schemaVersion = 3（v2：tasks 新增 priority 列；v3：projects 新增 description 列）。
// 本文件验证：
// 1. schemaVersion = 3；
// 2. onCreate 建出全部 5 张表（含 tasks.priority 与 projects.description）；
// 3. 数据写入/读取完整（迁移后数据完整性的基线）；
// 4. v1 → v2 真实迁移：旧版本 schema 造数据 → 升级 → 断言数据完整；
// 5. v2 → v3 真实迁移：projects 新增 description 列，旧行默认 ''。

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/repositories/todo_repository.dart';
import 'package:todo/core/db/tables.dart';

import '../helpers/db_test_setup.dart';

/// v1 tasks 建表 DDL（无 priority 列，schemaVersion = 1）。
const String _v1TasksDdl = '''
CREATE TABLE tasks (
  id TEXT NOT NULL PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects (id),
  parent_id TEXT REFERENCES tasks (id),
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  notes TEXT NOT NULL DEFAULT '',
  start_at INTEGER,
  end_at INTEGER,
  status INTEGER NOT NULL,
  sort_order INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0
)
''';

/// v2 tasks 建表 DDL（含 priority 列，schemaVersion = 2）。
const String _v2TasksDdl = '''
CREATE TABLE tasks (
  id TEXT NOT NULL PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects (id),
  parent_id TEXT REFERENCES tasks (id),
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  notes TEXT NOT NULL DEFAULT '',
  start_at INTEGER,
  end_at INTEGER,
  status INTEGER NOT NULL,
  priority INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0
)
''';

void main() {
  late AppDatabase db;
  late TodoRepository repo;

  setUp(() {
    db = openTestDatabase();
    repo = TodoRepository(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('schemaVersion = 3', () {
    expect(db.schemaVersion, 3);
  });

  test('onCreate 建出全部 5 张表（含 tasks.priority 与 projects.description）', () async {
    final rows = await db
        .customSelect('SELECT name FROM sqlite_master WHERE type = \'table\'')
        .get();
    final names = rows.map((r) => r.data['name'] as String).toSet();
    expect(
      names,
      containsAll(['projects', 'tasks', 'tags', 'task_tags', 'settings']),
    );

    // v2 新增列（tasks.priority）。
    final taskColumns = await db.customSelect('PRAGMA table_info(tasks)').get();
    final taskColumnNames = taskColumns.map((r) => r.data['name']).toSet();
    expect(taskColumnNames, contains('priority'));

    // v3 新增列（projects.description）。
    final projectColumns = await db
        .customSelect('PRAGMA table_info(projects)')
        .get();
    final projectColumnNames = projectColumns
        .map((r) => r.data['name'])
        .toSet();
    expect(projectColumnNames, contains('description'));
  });

  test('外键约束已开启（beforeOpen PRAGMA）', () async {
    final rows = await db.customSelect('PRAGMA foreign_keys').get();
    expect(rows.single.data.values.single, 1);
  });

  test('数据写入/读取完整（迁移后数据完整性基线）', () async {
    final p1 = await repo.createProject(name: '迁移项目', color: 0xFF000000);
    final t = await repo.createTask(
      projectId: p1.id,
      title: '迁移任务',
      priority: TaskPriority.high,
    );
    final tag = await repo.createTag(name: '迁移标签', color: 0);
    await repo.tags.setTaskTags(t.id, [tag.id]);
    await repo.settings.set('theme', 'dark');

    // 重新打开同一数据库（模拟应用重启），数据应完整。
    // 内存库无法重开，这里直接断言当前库数据完整。
    expect((await repo.projects.getById(p1.id))!.name, '迁移项目');
    expect((await repo.tasks.getById(t.id))!.title, '迁移任务');
    expect((await repo.tasks.getById(t.id))!.priority, TaskPriority.high);
    expect((await repo.tags.tagsForTask(t.id)).single.name, '迁移标签');
    expect(await repo.settings.get('theme'), 'dark');
  });

  test('v1 → v2 迁移：tasks 新增 priority 列，旧行默认 none', () async {
    configureTestSqlite3();
    final dir = await Directory.systemTemp.createTemp('todo_migration_test');
    addTearDown(() => dir.delete(recursive: true));
    final dbPath = '${dir.path}/v1.db';

    // 1. 用原始 sqlite3 按 v1 schema 造库（user_version = 1）。
    final raw = sqlite3.open(dbPath);
    raw.execute(
      'CREATE TABLE projects ('
      'id TEXT NOT NULL PRIMARY KEY,'
      'name TEXT NOT NULL,'
      'color INTEGER NOT NULL,'
      'sort_order INTEGER NOT NULL,'
      'created_at INTEGER NOT NULL,'
      'updated_at INTEGER NOT NULL,'
      'deleted INTEGER NOT NULL DEFAULT 0)',
    );
    raw.execute(_v1TasksDdl);
    raw.execute(
      'CREATE TABLE tags ('
      'id TEXT NOT NULL PRIMARY KEY,'
      'name TEXT NOT NULL,'
      'color INTEGER NOT NULL,'
      'sort_order INTEGER NOT NULL,'
      'created_at INTEGER NOT NULL,'
      'updated_at INTEGER NOT NULL,'
      'deleted INTEGER NOT NULL DEFAULT 0)',
    );
    raw.execute(
      'CREATE TABLE task_tags ('
      'task_id TEXT NOT NULL REFERENCES tasks (id),'
      'tag_id TEXT NOT NULL REFERENCES tags (id),'
      'PRIMARY KEY (task_id, tag_id))',
    );
    raw.execute(
      'CREATE TABLE settings ('
      'key TEXT NOT NULL PRIMARY KEY,'
      'value TEXT NOT NULL)',
    );
    raw.execute(
      'INSERT INTO projects VALUES (\'p1\', \'旧项目\', 4283215696, 0, 1000, 1000, 0)',
    );
    raw.execute(
      'INSERT INTO tasks (id, project_id, parent_id, title, description, notes, '
      'start_at, end_at, status, sort_order, created_at, updated_at, deleted) '
      'VALUES (\'legacy-1\', \'p1\', NULL, \'旧任务\', \'\', \'\', NULL, 2000, 0, 0, 1000, 1000, 0)',
    );
    raw.execute('PRAGMA user_version = 1');
    raw.dispose();

    // 2. 用 AppDatabase 打开同一文件（触发 onUpgrade 1 → 2）。
    final migrated = AppDatabase(NativeDatabase(File(dbPath)));
    addTearDown(() => migrated.close());

    // 3. 断言：priority 列存在；旧行默认 none（0）；数据完整。
    final columns = await migrated
        .customSelect('PRAGMA table_info(tasks)')
        .get();
    expect(columns.map((r) => r.data['name']), contains('priority'));

    final migratedRepo = TodoRepository(database: migrated);
    final legacy = await migratedRepo.tasks.getById('legacy-1');
    expect(legacy, isA<Task>());
    expect(legacy!.title, '旧任务');
    expect(legacy.priority, TaskPriority.none);

    // 新行可写 priority。
    final fresh = await migratedRepo.createTask(
      projectId: 'p1',
      title: '新任务',
      priority: TaskPriority.medium,
    );
    expect(fresh.priority, TaskPriority.medium);
  });

  test('v2 → v3 迁移：projects 新增 description 列，旧行默认 \'\'', () async {
    configureTestSqlite3();
    final dir = await Directory.systemTemp.createTemp('todo_migration_test');
    addTearDown(() => dir.delete(recursive: true));
    final dbPath = '${dir.path}/v2.db';

    // 1. 用原始 sqlite3 按 v2 schema 造库（user_version = 2，projects 无 description 列）。
    final raw = sqlite3.open(dbPath);
    raw.execute(
      'CREATE TABLE projects ('
      'id TEXT NOT NULL PRIMARY KEY,'
      'name TEXT NOT NULL,'
      'color INTEGER NOT NULL,'
      'sort_order INTEGER NOT NULL,'
      'created_at INTEGER NOT NULL,'
      'updated_at INTEGER NOT NULL,'
      'deleted INTEGER NOT NULL DEFAULT 0)',
    );
    raw.execute(_v2TasksDdl);
    raw.execute(
      'CREATE TABLE tags ('
      'id TEXT NOT NULL PRIMARY KEY,'
      'name TEXT NOT NULL,'
      'color INTEGER NOT NULL,'
      'sort_order INTEGER NOT NULL,'
      'created_at INTEGER NOT NULL,'
      'updated_at INTEGER NOT NULL,'
      'deleted INTEGER NOT NULL DEFAULT 0)',
    );
    raw.execute(
      'CREATE TABLE task_tags ('
      'task_id TEXT NOT NULL REFERENCES tasks (id),'
      'tag_id TEXT NOT NULL REFERENCES tags (id),'
      'PRIMARY KEY (task_id, tag_id))',
    );
    raw.execute(
      'CREATE TABLE settings ('
      'key TEXT NOT NULL PRIMARY KEY,'
      'value TEXT NOT NULL)',
    );
    raw.execute(
      'INSERT INTO projects VALUES (\'p1\', \'旧项目\', 4283215696, 0, 1000, 1000, 0)',
    );
    raw.execute('PRAGMA user_version = 2');
    raw.dispose();

    // 2. 用 AppDatabase 打开同一文件（触发 onUpgrade 2 → 3）。
    final migrated = AppDatabase(NativeDatabase(File(dbPath)));
    addTearDown(() => migrated.close());

    // 3. 断言：description 列存在；旧行默认 ''；数据完整。
    final columns = await migrated
        .customSelect('PRAGMA table_info(projects)')
        .get();
    expect(columns.map((r) => r.data['name']), contains('description'));

    final migratedRepo = TodoRepository(database: migrated);
    final legacy = await migratedRepo.projects.getById('p1');
    expect(legacy, isA<Project>());
    expect(legacy!.name, '旧项目');
    expect(legacy.color, 4283215696);
    expect(legacy.description, '');

    // 新项目可写 description。
    final fresh = await migratedRepo.createProject(
      name: '新项目',
      color: 0xFF112233,
      description: '描述',
    );
    expect(fresh.description, '描述');
  });
}
