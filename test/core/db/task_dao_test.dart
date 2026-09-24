// TaskDao watchAllActive / getAllActive 集成测试（内存 DB）。
//
// 覆盖：仅返回未删除任务（墓碑行被过滤）、按 updatedAt 降序、跨项目返回全部。

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/repositories/todo_repository.dart';

import '../../helpers/db_test_setup.dart';

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

  test('watchAllActive / getAllActive：仅未删除任务，按 updatedAt 降序', () async {
    final p = await repo.createProject(name: 'P', color: 0);
    final a = await repo.createTask(projectId: p.id, title: 'a');
    final b = await repo.createTask(projectId: p.id, title: 'b');
    final c = await repo.createTask(projectId: p.id, title: 'c');
    final tomb = await repo.createTask(projectId: p.id, title: 'tomb');

    // 设置确定性 updatedAt（毫秒）；墓碑行给最大 updatedAt 验证被过滤。
    await repo.tasks.updateById(
      a.id,
      const TasksCompanion(updatedAt: Value(100)),
    );
    await repo.tasks.updateById(
      b.id,
      const TasksCompanion(updatedAt: Value(300)),
    );
    await repo.tasks.updateById(
      c.id,
      const TasksCompanion(updatedAt: Value(200)),
    );
    await repo.tasks.updateById(
      tomb.id,
      const TasksCompanion(deleted: Value(1), updatedAt: Value(400)),
    );

    final fromStream = await repo.tasks.watchAllActive().first;
    expect(fromStream.map((t) => t.id).toList(), [b.id, c.id, a.id]);
    expect(fromStream.any((t) => t.id == tomb.id), isFalse);

    final fromFuture = await repo.tasks.getAllActive();
    expect(fromFuture.map((t) => t.id).toList(), [b.id, c.id, a.id]);
    expect(fromFuture.any((t) => t.id == tomb.id), isFalse);
  });

  test('watchAllActive / getAllActive：跨项目返回全部未删除任务', () async {
    final p1 = await repo.createProject(name: 'P1', color: 0);
    final p2 = await repo.createProject(name: 'P2', color: 0);
    final t1 = await repo.createTask(projectId: p1.id, title: 't1');
    final t2 = await repo.createTask(projectId: p2.id, title: 't2');
    await repo.tasks.updateById(
      t1.id,
      const TasksCompanion(updatedAt: Value(100)),
    );
    await repo.tasks.updateById(
      t2.id,
      const TasksCompanion(updatedAt: Value(200)),
    );

    final fromStream = await repo.tasks.watchAllActive().first;
    expect(fromStream.map((t) => t.id).toSet(), {t1.id, t2.id});
    // updatedAt 降序。
    expect(fromStream.map((t) => t.id).toList(), [t2.id, t1.id]);

    final fromFuture = await repo.tasks.getAllActive();
    expect(fromFuture.map((t) => t.id).toSet(), {t1.id, t2.id});
  });

  test('watchAllActive：插入后流自动推送（含更新触发）', () async {
    final p = await repo.createProject(name: 'P', color: 0);
    final t1 = await repo.createTask(projectId: p.id, title: 't1');

    final emissions = <List<Task>>[];
    final sub = repo.tasks.watchAllActive().listen(emissions.add);
    // 等待初始推送。
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await repo.tasks.updateById(
      t1.id,
      const TasksCompanion(updatedAt: Value(500)),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await sub.cancel();
    expect(emissions.length, greaterThanOrEqualTo(2));
    expect(emissions.last.map((t) => t.id), [t1.id]);
    expect(emissions.last.single.updatedAt, 500);
  });
}
