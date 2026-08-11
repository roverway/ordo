// Repository 集成测试（内存 DB，docs/30-architecture.md §8）。
//
// 覆盖：CRUD、级联删除（任务/项目/标签）、移动防环/深度拒绝、排序重排、
// updatedAt 统一刷新、派生状态约束。

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/repositories/todo_repository.dart';
import 'package:todo/core/db/tables.dart';

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

  /// 断言某组任务的 sortOrder 连续（0..n-1）。
  Future<void> expectSortOrderContinuous(List<Task> tasks) async {
    final sorted = [...tasks]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (var i = 0; i < sorted.length; i++) {
      expect(sorted[i].sortOrder, i, reason: 'sortOrder 应连续 0..n-1');
    }
  }

  group('CRUD', () {
    test('创建/读取/更新/删除项目', () async {
      final p = await repo.createProject(name: '工作', color: 0xFF2196F3);
      expect(p.name, '工作');
      expect(p.deleted, 0);
      expect(p.updatedAt, greaterThan(0));

      await repo.updateProject(p.id, name: '工作2');
      final updated = (await repo.projects.getById(p.id))!;
      expect(updated.name, '工作2');
      expect(updated.updatedAt, greaterThanOrEqualTo(p.updatedAt));

      await repo.deleteProject(p.id);
      expect(await repo.projects.getById(p.id), isNull);
    });

    test('创建/更新/删除任务（含时间校验）', () async {
      final p = await repo.createProject(name: 'P', color: 0);
      final t = await repo.createTask(
        projectId: p.id,
        title: '任务A',
        startAt: 1000,
        endAt: 2000,
      );
      expect(t.title, '任务A');
      expect(t.status, TaskStatus.todo);
      expect(t.sortOrder, 0);

      await repo.updateTask(t.id, title: '任务A2', status: TaskStatus.done);
      final updated = (await repo.tasks.getById(t.id))!;
      expect(updated.title, '任务A2');
      expect(updated.status, TaskStatus.done);

      // endAt < startAt 拒绝。
      expect(
        () => repo.updateTask(t.id, startAt: 3000, endAt: 1000),
        throwsA(isA<RepositoryException>()),
      );

      await repo.deleteTask(t.id);
      expect(await repo.tasks.getById(t.id), isNull);
    });

    test('项目名/任务标题长度校验', () async {
      expect(
        () => repo.createProject(name: '', color: 0),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        () => repo.createProject(name: 'x' * 101, color: 0),
        throwsA(isA<RepositoryException>()),
      );
      final p = await repo.createProject(name: 'P', color: 0);
      expect(
        () => repo.createTask(projectId: p.id, title: ''),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        () => repo.createTask(projectId: p.id, title: 'x' * 201),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('标签名不区分大小写唯一', () async {
      await repo.createTag(name: 'Work', color: 0);
      expect(
        () => repo.createTag(name: 'work', color: 0),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        () => repo.createTag(name: 'WORK', color: 0),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('settings 读写', () async {
      await repo.settings.set('theme', 'dark');
      expect(await repo.settings.get('theme'), 'dark');
      expect(await repo.settings.get('missing', fallback: 'x'), 'x');
      await repo.settings.remove('theme');
      expect(await repo.settings.get('theme'), isNull);
    });
  });

  group('级联删除', () {
    test('删除任务 → 级联删除所有后代（含 task_tags）', () async {
      final p = await repo.createProject(name: 'P', color: 0);
      final root = await repo.createTask(projectId: p.id, title: 'root');
      final child = await repo.createTask(
        projectId: p.id,
        parentId: root.id,
        title: 'child',
      );
      final grand = await repo.createTask(
        projectId: p.id,
        parentId: child.id,
        title: 'grand',
      );
      final other = await repo.createTask(projectId: p.id, title: 'other');

      final tag = await repo.createTag(name: 't', color: 0);
      await repo.tags.setTaskTags(grand.id, [tag.id]);

      await repo.deleteTask(root.id);

      expect(await repo.tasks.getById(root.id), isNull);
      expect(await repo.tasks.getById(child.id), isNull);
      expect(await repo.tasks.getById(grand.id), isNull);
      expect(await repo.tasks.getById(other.id), isNotNull);
      // 被删任务的 task_tags 引用已清理。
      expect(await repo.tags.tagIdsForTask(grand.id), isEmpty);
      // 标签本身保留。
      expect(await repo.tags.getById(tag.id), isNotNull);
    });

    test('删除项目 → 级联删除其下全部任务（含子树）', () async {
      final p = await repo.createProject(name: 'P', color: 0);
      final root = await repo.createTask(projectId: p.id, title: 'root');
      final child = await repo.createTask(
        projectId: p.id,
        parentId: root.id,
        title: 'child',
      );
      final grand = await repo.createTask(
        projectId: p.id,
        parentId: child.id,
        title: 'grand',
      );

      final p2 = await repo.createProject(name: 'P2', color: 0);
      final other = await repo.createTask(projectId: p2.id, title: 'other');

      await repo.deleteProject(p.id);

      expect(await repo.projects.getById(p.id), isNull);
      expect(await repo.tasks.getById(root.id), isNull);
      expect(await repo.tasks.getById(child.id), isNull);
      expect(await repo.tasks.getById(grand.id), isNull);
      // 其他项目不受影响。
      expect(await repo.projects.getById(p2.id), isNotNull);
      expect(await repo.tasks.getById(other.id), isNotNull);
    });

    test('删除标签 → 仅解引用，任务保留', () async {
      final p = await repo.createProject(name: 'P', color: 0);
      final t1 = await repo.createTask(projectId: p.id, title: 't1');
      final t2 = await repo.createTask(projectId: p.id, title: 't2');
      final tag = await repo.createTag(name: 'tag', color: 0);
      await repo.tags.setTaskTags(t1.id, [tag.id]);
      await repo.tags.setTaskTags(t2.id, [tag.id]);

      await repo.deleteTag(tag.id);

      expect(await repo.tags.getById(tag.id), isNull);
      expect(await repo.tasks.getById(t1.id), isNotNull);
      expect(await repo.tasks.getById(t2.id), isNotNull);
      expect(await repo.tags.tagIdsForTask(t1.id), isEmpty);
      expect(await repo.tags.tagIdsForTask(t2.id), isEmpty);
    });
  });

  group('移动任务', () {
    test('同级重排：sortOrder 连续且顺序正确', () async {
      final p = await repo.createProject(name: 'P', color: 0);
      final a = await repo.createTask(projectId: p.id, title: 'a');
      await repo.createTask(projectId: p.id, title: 'b');
      await repo.createTask(projectId: p.id, title: 'c');

      // 把 a 移到 index 2（末尾）。
      await repo.moveTask(a.id, newParentId: null, newIndex: 2);
      final roots = await repo.tasks.getDirectChildren(p.id, null);
      expect(roots.map((t) => t.title).toList(), ['b', 'c', 'a']);
      await expectSortOrderContinuous(roots);
    });

    test('跨父级移动：更新 parentId + 新旧两组重排', () async {
      final p = await repo.createProject(name: 'P', color: 0);
      final root = await repo.createTask(projectId: p.id, title: 'root');
      await repo.createTask(projectId: p.id, parentId: root.id, title: 'c1');
      await repo.createTask(projectId: p.id, parentId: root.id, title: 'c2');
      final other = await repo.createTask(projectId: p.id, title: 'other');

      // 把 other 移到 root 下 index 0。
      await repo.moveTask(other.id, newParentId: root.id, newIndex: 0);
      final children = await repo.tasks.getDirectChildren(p.id, root.id);
      expect(children.map((t) => t.title).toList(), ['other', 'c1', 'c2']);
      await expectSortOrderContinuous(children);

      // 旧组（1 级）只剩 root，sortOrder 归 0。
      final roots = await repo.tasks.getDirectChildren(p.id, null);
      expect(roots.map((t) => t.title).toList(), ['root']);
      await expectSortOrderContinuous(roots);
    });

    test('提升为 1 级：parentId 置空 + 重排', () async {
      final p = await repo.createProject(name: 'P', color: 0);
      final root = await repo.createTask(projectId: p.id, title: 'root');
      final child = await repo.createTask(
        projectId: p.id,
        parentId: root.id,
        title: 'child',
      );

      await repo.moveTask(child.id, newParentId: null, newIndex: 0);
      final moved = (await repo.tasks.getById(child.id))!;
      expect(moved.parentId, isNull);
      final roots = await repo.tasks.getDirectChildren(p.id, null);
      expect(roots.map((t) => t.title).toList(), ['child', 'root']);
      await expectSortOrderContinuous(roots);
    });

    test('防环：移动到自身被拒绝', () async {
      final p = await repo.createProject(name: 'P', color: 0);
      final a = await repo.createTask(projectId: p.id, title: 'a');
      expect(
        () => repo.moveTask(a.id, newParentId: a.id, newIndex: 0),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('防环：移动到自身后代被拒绝', () async {
      final p = await repo.createProject(name: 'P', color: 0);
      final a = await repo.createTask(projectId: p.id, title: 'a');
      final b = await repo.createTask(
        projectId: p.id,
        parentId: a.id,
        title: 'b',
      );
      final c = await repo.createTask(
        projectId: p.id,
        parentId: b.id,
        title: 'c',
      );

      expect(
        () => repo.moveTask(a.id, newParentId: c.id, newIndex: 0),
        throwsA(isA<RepositoryException>()),
      );
      // 数据未被破坏。
      expect((await repo.tasks.getById(a.id))!.parentId, isNull);
      expect((await repo.tasks.getById(b.id))!.parentId, a.id);
    });

    test('深度超限：移动后层级 > 3 被拒绝', () async {
      final p = await repo.createProject(name: 'P', color: 0);
      // a(1) → b(2) → c(3)。
      final a = await repo.createTask(projectId: p.id, title: 'a');
      final b = await repo.createTask(
        projectId: p.id,
        parentId: a.id,
        title: 'b',
      );
      await repo.createTask(projectId: p.id, parentId: b.id, title: 'c');
      // d(1) → e(2)。
      final d = await repo.createTask(projectId: p.id, title: 'd');
      final e = await repo.createTask(
        projectId: p.id,
        parentId: d.id,
        title: 'e',
      );

      // 把 d（subtreeDepth=2）移到 b（depth=2）下：2+2=4 > 3 → 拒绝。
      expect(
        () => repo.moveTask(d.id, newParentId: b.id, newIndex: 0),
        throwsA(isA<RepositoryException>()),
      );
      expect((await repo.tasks.getById(d.id))!.parentId, isNull);

      // 把 e（subtreeDepth=1）移到 b（depth=2）下：2+1=3 ≤ 3 → 允许。
      await repo.moveTask(e.id, newParentId: b.id, newIndex: 0);
      expect((await repo.tasks.getById(e.id))!.parentId, b.id);
    });

    test('创建子任务深度校验：depth 3 下不可再建', () async {
      final p = await repo.createProject(name: 'P', color: 0);
      final a = await repo.createTask(projectId: p.id, title: 'a');
      final b = await repo.createTask(
        projectId: p.id,
        parentId: a.id,
        title: 'b',
      );
      final c = await repo.createTask(
        projectId: p.id,
        parentId: b.id,
        title: 'c',
      );

      expect(
        () => repo.createTask(projectId: p.id, parentId: c.id, title: 'd'),
        throwsA(isA<RepositoryException>()),
      );
      // depth 2 下可建。
      final ok = await repo.createTask(
        projectId: p.id,
        parentId: b.id,
        title: 'ok',
      );
      expect(ok.parentId, b.id);
    });

    test('移动后 updatedAt 统一刷新', () async {
      final p = await repo.createProject(name: 'P', color: 0);
      final a = await repo.createTask(projectId: p.id, title: 'a');
      await repo.createTask(projectId: p.id, title: 'b');
      final before = (await repo.tasks.getById(a.id))!.updatedAt;

      await repo.moveTask(a.id, newParentId: null, newIndex: 1);
      final after = (await repo.tasks.getById(a.id))!.updatedAt;
      expect(after, greaterThanOrEqualTo(before));
    });
  });

  group('派生状态约束', () {
    test('有子任务的任务不可手动修改状态', () async {
      final p = await repo.createProject(name: 'P', color: 0);
      final root = await repo.createTask(projectId: p.id, title: 'root');
      await repo.createTask(projectId: p.id, parentId: root.id, title: 'child');

      expect(
        () => repo.updateTask(root.id, status: TaskStatus.done),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('无子任务的任务可修改状态', () async {
      final p = await repo.createProject(name: 'P', color: 0);
      final leaf = await repo.createTask(projectId: p.id, title: 'leaf');
      await repo.updateTask(leaf.id, status: TaskStatus.done);
      expect((await repo.tasks.getById(leaf.id))!.status, TaskStatus.done);
    });
  });

  group('项目排序', () {
    test('moveProject 重排 sortOrder', () async {
      await repo.createProject(name: 'P1', color: 0);
      await repo.createProject(name: 'P2', color: 0);
      final p3 = await repo.createProject(name: 'P3', color: 0);

      await repo.moveProject(p3.id, 0);
      final all = await repo.projects.getAll();
      expect(all.map((p) => p.name).toList(), ['P3', 'P1', 'P2']);
      for (var i = 0; i < all.length; i++) {
        expect(all[i].sortOrder, i);
      }
    });
  });
}
