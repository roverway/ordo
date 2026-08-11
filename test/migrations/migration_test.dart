// 迁移测试基建（docs/40-data-model.md §8，70-milestones.md M1 任务 6）。
//
// M1 无实际迁移步骤（schemaVersion = 1），本文件仅验证框架：
// 1. schemaVersion = 1；
// 2. onCreate 建出全部 5 张表；
// 3. 数据写入/读取完整（迁移后数据完整性的基线）；
// 4. onUpgrade 可执行（空实现不抛错）。
//
// 后续版本新增迁移时，在此按「旧版本造数据 → 升级 → 断言数据完整」扩展。

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/repositories/todo_repository.dart';

import '../helpers/db_test_setup.dart';

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

  test('schemaVersion = 1', () {
    expect(db.schemaVersion, 1);
  });

  test('onCreate 建出全部 5 张表', () async {
    final rows = await db
        .customSelect('SELECT name FROM sqlite_master WHERE type = \'table\'')
        .get();
    final names = rows.map((r) => r.data['name'] as String).toSet();
    expect(
      names,
      containsAll(['projects', 'tasks', 'tags', 'task_tags', 'settings']),
    );
  });

  test('外键约束已开启（beforeOpen PRAGMA）', () async {
    final rows = await db.customSelect('PRAGMA foreign_keys').get();
    expect(rows.single.data.values.single, 1);
  });

  test('数据写入/读取完整（迁移后数据完整性基线）', () async {
    final p = await repo.createProject(name: '迁移项目', color: 0xFF000000);
    final t = await repo.createTask(projectId: p.id, title: '迁移任务');
    final tag = await repo.createTag(name: '迁移标签', color: 0);
    await repo.tags.setTaskTags(t.id, [tag.id]);
    await repo.settings.set('theme', 'dark');

    // 重新打开同一数据库（模拟应用重启），数据应完整。
    // 内存库无法重开，这里直接断言当前库数据完整。
    expect((await repo.projects.getById(p.id))!.name, '迁移项目');
    expect((await repo.tasks.getById(t.id))!.title, '迁移任务');
    expect((await repo.tags.tagsForTask(t.id)).single.name, '迁移标签');
    expect(await repo.settings.get('theme'), 'dark');
  });

  test('onUpgrade 空实现可执行（不抛错）', () async {
    // M1 无迁移步骤：直接调用迁移策略的 onUpgrade 回调验证框架可运行。
    final migration = db.migration;
    // 从 1 → 1 的升级路径（无操作）不应抛错。
    await migration.onUpgrade(Migrator(db), 1, 1);
    // 数据仍可读写。
    final p = await repo.createProject(name: 'P', color: 0);
    expect((await repo.projects.getById(p.id))!.name, 'P');
  });
}
