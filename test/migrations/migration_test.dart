// 迁移测试（docs/40-data-model.md §8，70-milestones.md M1 任务 6）。
//
// schemaVersion = 4（v2：tasks 新增 priority 列；v3：projects 新增 description 列；
// v4：新增 folders 表 + projects 新增 folderId 列，docs/62-folder-nav.md §7.1）。
// 本文件验证：
// 1. schemaVersion = 4；
// 2. onCreate 建出全部 6 张表（含 tasks.priority、projects.description 与 folders）；
// 3. 数据写入/读取完整（迁移后数据完整性的基线）；
// 4. v1 → v2 真实迁移：旧版本 schema 造数据 → 升级 → 断言数据完整；
// 5. v2 → v3 真实迁移：projects 新增 description 列，旧行默认 ''；
// 6. v3 → v4 真实迁移：新增 folders 表 + projects.folderId 列，旧行默认 NULL。

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

  test('schemaVersion = 4', () {
    expect(db.schemaVersion, 4);
  });

  test(
    'onCreate 建出全部 6 张表（含 tasks.priority / projects.description / folders）',
    () async {
      final rows = await db
          .customSelect('SELECT name FROM sqlite_master WHERE type = \'table\'')
          .get();
      final names = rows.map((r) => r.data['name'] as String).toSet();
      expect(
        names,
        containsAll([
          'projects',
          'folders',
          'tasks',
          'tags',
          'task_tags',
          'settings',
        ]),
      );

      // v2 新增列（tasks.priority）。
      final taskColumns = await db
          .customSelect('PRAGMA table_info(tasks)')
          .get();
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

      // v4 新增列（projects.folder_id，FK → folders.id）。
      expect(projectColumnNames, contains('folder_id'));

      // v4 新增表（folders 含同步三字段）。
      final folderColumns = await db
          .customSelect('PRAGMA table_info(folders)')
          .get();
      final folderColumnNames = folderColumns
          .map((r) => r.data['name'])
          .toSet();
      expect(
        folderColumnNames,
        containsAll([
          'id',
          'name',
          'sort_order',
          'created_at',
          'updated_at',
          'deleted',
        ]),
      );
    },
  );

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

  test('v3 → v4 迁移：新增 folders 表 + projects.folder_id 列，旧行默认 NULL', () async {
    configureTestSqlite3();
    final dir = await Directory.systemTemp.createTemp('todo_migration_test');
    addTearDown(() => dir.delete(recursive: true));
    final dbPath = '${dir.path}/v3.db';

    // 1. 用原始 sqlite3 按 v3 schema 造库（user_version = 3，无 folders 表、
    //    projects 无 folder_id 列）。
    final raw = sqlite3.open(dbPath);
    raw.execute(
      'CREATE TABLE projects ('
      'id TEXT NOT NULL PRIMARY KEY,'
      'name TEXT NOT NULL,'
      'color INTEGER NOT NULL,'
      'description TEXT NOT NULL DEFAULT \'\','
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
      'INSERT INTO projects VALUES (\'p1\', \'旧项目\', 4283215696, \'旧描述\', 0, 1000, 1000, 0)',
    );
    raw.execute(
      'INSERT INTO projects VALUES (\'p2\', \'旧项目2\', 4283215697, \'\', 1, 1001, 1001, 0)',
    );
    raw.execute(
      'INSERT INTO tasks (id, project_id, parent_id, title, description, notes, '
      'start_at, end_at, status, priority, sort_order, created_at, updated_at, deleted) '
      'VALUES (\'legacy-3\', \'p1\', NULL, \'旧任务\', \'\', \'\', NULL, 2000, 0, 0, 0, 1000, 1000, 0)',
    );
    raw.execute('PRAGMA user_version = 3');
    raw.dispose();

    // 2. 用 AppDatabase 打开同一文件（触发 onUpgrade 3 → 4）。
    final migrated = AppDatabase(NativeDatabase(File(dbPath)));
    addTearDown(() => migrated.close());

    // 3. 断言：folders 表存在；projects.folder_id 列存在；旧行默认 NULL；原数据完整。
    final tables = await migrated
        .customSelect('SELECT name FROM sqlite_master WHERE type = \'table\'')
        .get();
    expect(
      tables.map((r) => r.data['name']),
      containsAll(['folders', 'projects']),
    );

    final columns = await migrated
        .customSelect('PRAGMA table_info(projects)')
        .get();
    final projectColumnNames = columns.map((r) => r.data['name']).toList();
    expect(projectColumnNames, contains('folder_id'));

    final migratedRepo = TodoRepository(database: migrated);
    final legacy = await migratedRepo.projects.getById('p1');
    expect(legacy, isA<Project>());
    expect(legacy!.name, '旧项目');
    expect(legacy.description, '旧描述');
    expect(legacy.folderId, isNull, reason: '旧行 folderId 默认 NULL（未分组）');
    final legacy2 = await migratedRepo.projects.getById('p2');
    expect(legacy2!.folderId, isNull);

    // 任务等其余数据完整。
    final legacyTask = await migratedRepo.tasks.getById('legacy-3');
    expect(legacyTask!.title, '旧任务');
    expect(legacyTask.priority, TaskPriority.none);

    // 4. 新 schema 可正常写：创建文件夹 + 项目入夹，读回 folderId。
    final folder = await migratedRepo.createFolder(name: '迁移文件夹');
    final fresh = await migratedRepo.createProject(
      name: '新项目',
      color: 0xFF112233,
    );
    await migratedRepo.moveProjectToFolder(
      fresh.id,
      folderId: folder.id,
      newIndex: 0,
    );
    expect(
      (await migratedRepo.projects.getById(fresh.id))!.folderId,
      folder.id,
    );
  });
}
