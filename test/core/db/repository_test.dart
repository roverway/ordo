// Repository 集成测试（内存 DB，docs/30-architecture.md §8）。
//
// 覆盖：CRUD、级联删除（任务/项目/标签）、移动防环/深度拒绝、排序重排、
// updatedAt 统一刷新、派生状态约束。

import 'package:drift/drift.dart' hide isNull, isNotNull;
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
      expect(updated.startAt, 1000, reason: '更新状态不能丢失 startAt');
      expect(updated.endAt, 2000, reason: '更新状态不能丢失 endAt');
      expect(
        updated.completedAt,
        isNotNull,
        reason: '标记为 done 应记录 completedAt',
      );

      // endAt < startAt 拒绝。
      expect(
        () => repo.updateTask(
          t.id,
          startAt: const Value(3000),
          endAt: const Value(1000),
        ),
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

    test('项目描述长度校验（最多 500 字符）', () async {
      // 空描述允许（默认 ''）。
      final p = await repo.createProject(name: 'P', color: 0, description: '');
      expect(p.description, '');

      // 500 字符以内允许并读回。
      final ok = await repo.createProject(
        name: 'P2',
        color: 0,
        description: 'x' * 500,
      );
      expect(ok.description.length, 500);

      // 超长拒绝（create 与 update 一致）。
      expect(
        () => repo.createProject(name: 'P3', color: 0, description: 'x' * 501),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        () => repo.updateProject(p.id, description: 'x' * 501),
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

    test('跨项目移动单任务：更新 projectId，清空 parentId，置于目标项目末尾', () async {
      final p1 = await repo.createProject(name: 'P1', color: 0);
      final p2 = await repo.createProject(name: 'P2', color: 0);
      final t1 = await repo.createTask(projectId: p1.id, title: 't1');
      await repo.createTask(projectId: p2.id, title: 'existing_p2');

      await repo.moveTaskToProject(t1.id, p2.id);

      final moved = (await repo.tasks.getById(t1.id))!;
      expect(moved.projectId, p2.id);
      expect(moved.parentId, isNull);
      expect(moved.sortOrder, 1);

      final p1Tasks = await repo.tasks.getByProject(p1.id);
      expect(p1Tasks, isEmpty);

      final p2Tasks = await repo.tasks.getByProject(p2.id);
      expect(p2Tasks.map((t) => t.id), contains(t1.id));
    });

    test('跨项目移动带子任务与孙任务整棵子树：级联更新所有后代 projectId 并保留内部层级', () async {
      final p1 = await repo.createProject(name: 'P1', color: 0);
      final p2 = await repo.createProject(name: 'P2', color: 0);
      final root = await repo.createTask(projectId: p1.id, title: 'root');
      final child = await repo.createTask(
        projectId: p1.id,
        parentId: root.id,
        title: 'child',
      );
      final grandChild = await repo.createTask(
        projectId: p1.id,
        parentId: child.id,
        title: 'grandChild',
      );

      await repo.moveTaskToProject(root.id, p2.id);

      final movedRoot = (await repo.tasks.getById(root.id))!;
      final movedChild = (await repo.tasks.getById(child.id))!;
      final movedGrandChild = (await repo.tasks.getById(grandChild.id))!;

      expect(movedRoot.projectId, p2.id);
      expect(movedRoot.parentId, isNull);

      expect(movedChild.projectId, p2.id);
      expect(movedChild.parentId, root.id);

      expect(movedGrandChild.projectId, p2.id);
      expect(movedGrandChild.parentId, child.id);

      // p1 下应无任何任务，全部成功转移至 p2
      expect(await repo.tasks.getAllByProject(p1.id), isEmpty);
      final p2All = await repo.tasks.getAllByProject(p2.id);
      expect(p2All.length, 3);
    });

    test('跨项目移动原为子任务的任务：清空 parentId，脱离原父级并成为目标项目根任务', () async {
      final p1 = await repo.createProject(name: 'P1', color: 0);
      final p2 = await repo.createProject(name: 'P2', color: 0);
      final parent = await repo.createTask(projectId: p1.id, title: 'parent');
      final subtask = await repo.createTask(
        projectId: p1.id,
        parentId: parent.id,
        title: 'subtask',
      );

      await repo.moveTaskToProject(subtask.id, p2.id);

      final moved = (await repo.tasks.getById(subtask.id))!;
      expect(moved.projectId, p2.id);
      expect(moved.parentId, isNull);

      final p1Tasks = await repo.tasks.getAllByProject(p1.id);
      expect(p1Tasks.length, 1);
      expect(p1Tasks.first.id, parent.id);
    });

    test('跨项目移动异常防御：任务不存在或目标项目不存在/已删除抛错', () async {
      final p1 = await repo.createProject(name: 'P1', color: 0);
      final p2 = await repo.createProject(name: 'P2', color: 0);
      final t = await repo.createTask(projectId: p1.id, title: 't');
      await repo.deleteProject(p2.id);

      expect(
        () => repo.moveTaskToProject('non_existent', p1.id),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        () => repo.moveTaskToProject(t.id, 'non_existent_project'),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        () => repo.moveTaskToProject(t.id, p2.id),
        throwsA(isA<RepositoryException>()),
      );
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

    test('无子任务的任务可修改状态，且自动维护 completedAt', () async {
      final p = await repo.createProject(name: 'P', color: 0);
      final leaf = await repo.createTask(projectId: p.id, title: 'leaf');
      expect((await repo.tasks.getById(leaf.id))!.completedAt, isNull);

      await repo.updateTask(leaf.id, status: TaskStatus.done);
      final doneTask = (await repo.tasks.getById(leaf.id))!;
      expect(doneTask.status, TaskStatus.done);
      expect(doneTask.completedAt, isNotNull);

      // 取消完成
      await repo.updateTask(leaf.id, status: TaskStatus.todo);
      final todoTask = (await repo.tasks.getById(leaf.id))!;
      expect(todoTask.status, TaskStatus.todo);
      expect(todoTask.completedAt, isNull);
    });

    test('syncSubtasks 自动维护新建与更新子任务的 completedAt', () async {
      final p = await repo.createProject(name: 'P', color: 0);
      final root = await repo.createTask(projectId: p.id, title: 'root');

      // 新建包含已完成子任务
      await repo.syncSubtasks(
        parentId: root.id,
        deleteSubtaskIds: const [],
        items: [
          (id: null, title: 'sub1', status: TaskStatus.done),
          (id: null, title: 'sub2', status: TaskStatus.todo),
        ],
      );

      final children = await repo.tasks.getDirectChildren(p.id, root.id);
      expect(children.length, 2);
      final sub1 = children.firstWhere((c) => c.title == 'sub1');
      final sub2 = children.firstWhere((c) => c.title == 'sub2');
      expect(sub1.completedAt, isNotNull);
      expect(sub2.completedAt, isNull);

      // 更新现有子任务状态
      await repo.syncSubtasks(
        parentId: root.id,
        deleteSubtaskIds: const [],
        items: [
          (id: sub1.id, title: 'sub1', status: TaskStatus.todo),
          (id: sub2.id, title: 'sub2', status: TaskStatus.done),
        ],
      );

      final updatedSub1 = (await repo.tasks.getById(sub1.id))!;
      final updatedSub2 = (await repo.tasks.getById(sub2.id))!;
      expect(updatedSub1.completedAt, isNull);
      expect(updatedSub2.completedAt, isNotNull);
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

  group('文件夹（Folder）', () {
    /// 断言某文件夹组内项目 sortOrder 连续（0..n-1）。
    Future<void> expectProjectGroupContinuous(String? folderId) async {
      final group = await repo.projects.getAllInFolder(folderId);
      for (var i = 0; i < group.length; i++) {
        expect(group[i].sortOrder, i, reason: '组内 sortOrder 应连续 0..n-1');
      }
    }

    test('createFolder：名称校验（1–50）+ sortOrder 递增', () async {
      // 空名 / 超长拒绝。
      expect(
        () => repo.createFolder(name: ''),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        () => repo.createFolder(name: 'x' * 51),
        throwsA(isA<RepositoryException>()),
      );

      final f1 = await repo.createFolder(name: '工作');
      expect(f1.deleted, 0);
      expect(f1.createdAt, greaterThan(0));
      expect(f1.sortOrder, 0);

      final f2 = await repo.createFolder(name: '生活');
      expect(f2.sortOrder, 1, reason: 'sortOrder 递增追加到末尾');

      // 50 字符边界允许，继续递增。
      final ok = await repo.createFolder(name: 'x' * 50);
      expect(ok.name.length, 50);
      expect(ok.sortOrder, 2);
    });

    test('renameFolder：正常重命名 + 不存在拒绝 + 名称校验', () async {
      final f = await repo.createFolder(name: '工作');
      await repo.renameFolder(f.id, name: '工作2');
      final renamed = (await repo.folders.getById(f.id))!;
      expect(renamed.name, '工作2');
      expect(renamed.updatedAt, greaterThanOrEqualTo(f.updatedAt));

      expect(
        () => repo.renameFolder('missing', name: 'x'),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        () => repo.renameFolder(f.id, name: ''),
        throwsA(isA<RepositoryException>()),
      );
      expect(
        () => repo.renameFolder(f.id, name: 'x' * 51),
        throwsA(isA<RepositoryException>()),
      );
      // 校验失败不改名。
      expect((await repo.folders.getById(f.id))!.name, '工作2');
    });

    test('moveProjectToFolder：入夹 / 组内重排，sortOrder 连续', () async {
      final f1 = await repo.createFolder(name: 'F1');
      final p1 = await repo.createProject(name: 'P1', color: 0);
      final p2 = await repo.createProject(name: 'P2', color: 0);
      await repo.createProject(name: 'P3', color: 0);

      // 入夹：p1、p2 → f1。
      await repo.moveProjectToFolder(p1.id, folderId: f1.id, newIndex: 0);
      await repo.moveProjectToFolder(p2.id, folderId: f1.id, newIndex: 1);
      expect((await repo.projects.getById(p1.id))!.folderId, f1.id);

      // 组内重排：p2 移到 index 0。
      await repo.moveProjectToFolder(p2.id, folderId: f1.id, newIndex: 0);
      var inF1 = await repo.projects.getAllInFolder(f1.id);
      expect(inF1.map((p) => p.name).toList(), ['P2', 'P1']);
      await expectProjectGroupContinuous(f1.id);

      // 未分组组（p3 仍在）不受影响且连续。
      await expectProjectGroupContinuous(null);

      // 不存在的目标文件夹拒绝。
      expect(
        () => repo.moveProjectToFolder(p1.id, folderId: 'nope', newIndex: 0),
        throwsA(isA<RepositoryException>()),
      );
      // 不存在的项目拒绝。
      expect(
        () => repo.moveProjectToFolder('nope', newIndex: 0),
        throwsA(isA<RepositoryException>()),
      );
      // 失败后数据未变。
      inF1 = await repo.projects.getAllInFolder(f1.id);
      expect(inF1.map((p) => p.name).toList(), ['P2', 'P1']);
    });

    test('moveProjectToFolder：出夹回未分组 + 跨组移动', () async {
      final f1 = await repo.createFolder(name: 'F1');
      final f2 = await repo.createFolder(name: 'F2');
      final p1 = await repo.createProject(name: 'P1', color: 0);
      final p2 = await repo.createProject(name: 'P2', color: 0);
      await repo.createProject(name: 'P3', color: 0);
      await repo.moveProjectToFolder(p1.id, folderId: f1.id, newIndex: 0);
      await repo.moveProjectToFolder(p2.id, folderId: f1.id, newIndex: 1);

      // 跨组移动：p1 → f2。
      await repo.moveProjectToFolder(p1.id, folderId: f2.id, newIndex: 0);
      expect((await repo.projects.getById(p1.id))!.folderId, f2.id);
      var inF1 = await repo.projects.getAllInFolder(f1.id);
      expect(inF1.map((p) => p.name).toList(), ['P2']);
      expect(inF1.single.sortOrder, 0, reason: '旧组删除空位后重排');
      var inF2 = await repo.projects.getAllInFolder(f2.id);
      expect(inF2.map((p) => p.name).toList(), ['P1']);
      expect(inF2.single.sortOrder, 0);

      // 出夹：p1 → 未分组。
      await repo.moveProjectToFolder(p1.id, folderId: null, newIndex: 0);
      expect((await repo.projects.getById(p1.id))!.folderId, isNull);
      final ungrouped = await repo.projects.getAllInFolder(null);
      expect(ungrouped.map((p) => p.name).toList(), ['P1', 'P3']);
      await expectProjectGroupContinuous(null);

      // 出夹后 f2 组为空。
      inF2 = await repo.projects.getAllInFolder(f2.id);
      expect(inF2, isEmpty);

      // 旧组 f1 保持连续。
      inF1 = await repo.projects.getAllInFolder(f1.id);
      expect(inF1.map((p) => p.name).toList(), ['P2']);
      await expectProjectGroupContinuous(f1.id);
    });

    test('moveProjectToFolder：newIndex 越界 clamp', () async {
      final f1 = await repo.createFolder(name: 'F1');
      final p1 = await repo.createProject(name: 'P1', color: 0);
      final p2 = await repo.createProject(name: 'P2', color: 0);

      // newIndex 超大 → clamp 到末尾。
      await repo.moveProjectToFolder(p1.id, folderId: f1.id, newIndex: 99);
      await repo.moveProjectToFolder(p2.id, folderId: f1.id, newIndex: 99);
      final inF1 = await repo.projects.getAllInFolder(f1.id);
      expect(inF1.map((p) => p.name).toList(), ['P1', 'P2']);
      await expectProjectGroupContinuous(f1.id);
    });

    test('deleteFolder：项目解收纳回未分组 + sortOrder 重排连续 + 墓碑写入', () async {
      final f = await repo.createFolder(name: 'F');
      final p1 = await repo.createProject(name: 'P1', color: 0);
      final p2 = await repo.createProject(name: 'P2', color: 0);
      await repo.moveProjectToFolder(p1.id, folderId: f.id, newIndex: 0);
      await repo.moveProjectToFolder(p2.id, folderId: f.id, newIndex: 1);

      await repo.deleteFolder(f.id);

      // 文件夹行已硬删。
      expect(await repo.folders.getById(f.id), isNull);
      // 项目解收纳回未分组（不级联删项目）。
      final ungrouped = await repo.projects.getAllInFolder(null);
      expect(ungrouped.map((p) => p.name).toList(), ['P1', 'P2']);
      await expectProjectGroupContinuous(null);
      expect(await repo.projects.getById(p1.id), isNotNull);
      expect(await repo.projects.getById(p2.id), isNotNull);
      // 文件夹墓碑写入（type = 'folder'）。
      final tombstones = await repo.readTombstones();
      expect(tombstones.any((t) => t.type == 'folder' && t.id == f.id), isTrue);
      // 项目未写墓碑。
      expect(
        tombstones.any(
          (t) => t.type == 'project' && (t.id == p1.id || t.id == p2.id),
        ),
        isFalse,
      );

      // 不存在文件夹拒绝。
      expect(
        () => repo.deleteFolder('missing'),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('deleteFolder：已有未分组项目与新解收纳项目整体重排连续', () async {
      final f = await repo.createFolder(name: 'F');
      // 未分组已有项目（sortOrder 0）。
      await repo.createProject(name: 'P1', color: 0);
      // 文件夹内项目（sortOrder 0）。
      final p2 = await repo.createProject(name: 'P2', color: 0);
      await repo.moveProjectToFolder(p2.id, folderId: f.id, newIndex: 0);

      await repo.deleteFolder(f.id);

      final ungrouped = await repo.projects.getAllInFolder(null);
      expect(ungrouped.map((p) => p.name).toList(), ['P1', 'P2']);
      await expectProjectGroupContinuous(null);
    });

    test('moveFolder：重排文件夹顺序且 sortOrder 连续', () async {
      final f1 = await repo.createFolder(name: 'A');
      final f2 = await repo.createFolder(name: 'B');
      await repo.createFolder(name: 'C');

      await repo.moveFolder(f1.id, newIndex: 2);
      var all = await repo.folders.getAll();
      expect(all.map((f) => f.name).toList(), ['B', 'C', 'A']);
      for (var i = 0; i < all.length; i++) {
        expect(all[i].sortOrder, i);
      }

      // 越界 clamp。
      await repo.moveFolder(f2.id, newIndex: 99);
      all = await repo.folders.getAll();
      expect(all.map((f) => f.name).toList(), ['C', 'A', 'B']);

      // 不存在文件夹拒绝。
      expect(
        () => repo.moveFolder('missing', newIndex: 0),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('exportAll 包含 folders', () async {
      final f1 = await repo.createFolder(name: 'F1');
      await repo.createFolder(name: 'F2');
      final p = await repo.createProject(name: 'P', color: 0);
      await repo.moveProjectToFolder(p.id, folderId: f1.id, newIndex: 0);

      final data = await repo.exportAll();
      expect(data.folders.map((f) => f.id).toList(), containsAll([f1.id]));
      expect(data.folders.every((f) => f.deleted == 0), isTrue);
      // 项目快照携带 folderId。
      expect(data.projects.single.folderId, f1.id);
    });

    test('applyMerged 同步路径删除文件夹：解收纳后未分组组 sortOrder 连续', () async {
      // 场景（评审发现）：设备 B 有文件夹 F 内项目 P1/P2（sortOrder 0,1），
      // 另有未分组 Q1/Q2（sortOrder 0,1）。设备 A 删除 F，B 同步合并后
      // reconcileFolderIds 已置 folderId=null，hardDeleteFolderIds 含 F。
      // 先建未分组项目（占据未分组组 sortOrder 0/1），再建项目入夹——
      // 解收纳后 P1/P2 保留组内 sortOrder 0/1 与 Q 冲突，验证重排修复。
      final f = await repo.createFolder(name: 'F');
      await repo.createProject(name: 'Q1', color: 0);
      await repo.createProject(name: 'Q2', color: 0);
      final p1 = await repo.createProject(name: 'P1', color: 0);
      final p2 = await repo.createProject(name: 'P2', color: 0);
      await repo.moveProjectToFolder(p1.id, folderId: f.id, newIndex: 0);
      await repo.moveProjectToFolder(p2.id, folderId: f.id, newIndex: 1);

      await repo.applyMerged(MergedApplyOperation(hardDeleteFolderIds: [f.id]));

      // 文件夹行已硬删。
      expect(await repo.folders.getById(f.id), isNull);
      // 项目全部解收纳回未分组（不级联删项目）。
      final ungrouped = await repo.projects.getAllInFolder(null);
      expect(
        ungrouped.map((p) => p.name).toSet(),
        {'Q1', 'Q2', 'P1', 'P2'},
        reason: '解收纳后 4 个项目都应在未分组组（顺序不依赖同值 sortOrder 的读取次序）',
      );
      // 修复核心：未分组组 sortOrder 重排连续（修复前会存在同值冲突）。
      await expectProjectGroupContinuous(null);
      expect(await repo.projects.getById(p1.id), isNotNull);
      expect(await repo.projects.getById(p2.id), isNotNull);
    });
  });

  group('收件箱（Inbox）', () {
    test('ensureInboxProject 幂等：重复调用只创建一条', () async {
      final first = await repo.ensureInboxProject('收件箱');
      expect(first.id, inboxProjectId);
      expect(first.name, '收件箱');
      expect(first.color, inboxProjectColor);
      expect(first.deleted, 0);
      expect(first.sortOrder, 0, reason: '收件箱 sortOrder 置 0（置顶）');

      final second = await repo.ensureInboxProject('收件箱');
      expect(second.id, inboxProjectId);

      final all = await repo.projects.getAll();
      expect(all.where((p) => p.id == inboxProjectId).length, 1);
    });

    test('ensureInboxProject 已存在时保留用户改名', () async {
      await repo.ensureInboxProject('收件箱');
      await repo.updateProject(inboxProjectId, name: '我的收件箱');

      final again = await repo.ensureInboxProject('收件箱');
      expect(again.name, '我的收件箱', reason: '改名不强制回退');
    });

    test('createTask 不带 projectId 默认落入收件箱', () async {
      await repo.ensureInboxProject('收件箱');

      final t = await repo.createTask(title: '待办');
      expect(t.projectId, inboxProjectId);
      expect(t.sortOrder, 0);

      final roots = await repo.tasks.getDirectChildren(inboxProjectId, null);
      expect(roots.map((r) => r.id), [t.id]);
    });

    test('createTask 不带 projectId 且收件箱缺失时自动创建', () async {
      final t = await repo.createTask(title: '待办', inboxDisplayName: '收件箱');
      expect(t.projectId, inboxProjectId);

      final inbox = (await repo.projects.getById(inboxProjectId))!;
      expect(inbox.deleted, 0);
      expect(inbox.name, '收件箱');
      expect(inbox.color, inboxProjectColor);
    });

    test('createTask 无 projectId、收件箱缺失且未传展示名时抛错', () async {
      expect(
        () => repo.createTask(title: '待办'),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('收件箱墓碑行（deleted=1）时 ensure 恢复', () async {
      await repo.ensureInboxProject('收件箱');
      // 模拟同步产生的墓碑。
      await repo.projects.updateById(
        inboxProjectId,
        ProjectsCompanion(
          deleted: const Value(1),
          updatedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
        ),
      );

      final restored = await repo.ensureInboxProject('收件箱');
      expect(restored.id, inboxProjectId);
      expect(restored.deleted, 0);
      expect(restored.name, '收件箱');
      expect(restored.color, inboxProjectColor);
    });
  });

  group('onDataChanged（编辑自动同步回调，FR-SYNC-02）', () {
    test('用户写操作依次触发回调（create/update/move/delete）', () async {
      var calls = 0;
      repo.onDataChanged = () async => calls++;

      final p = await repo.createProject(name: 'P', color: 0);
      expect(calls, 1, reason: 'createProject 触发');
      await repo.updateProject(p.id, name: 'P2');
      expect(calls, 2, reason: 'updateProject 触发');
      await repo.moveProject(p.id, 0);
      expect(calls, 3, reason: 'moveProject 触发');

      final t = await repo.createTask(projectId: p.id, title: 'T');
      expect(calls, 4, reason: 'createTask 触发');
      await repo.updateTask(t.id, title: 'T2');
      expect(calls, 5, reason: 'updateTask 触发');
      await repo.moveTask(t.id, newParentId: null, newIndex: 0);
      expect(calls, 6, reason: 'moveTask 触发');

      final tag = await repo.createTag(name: 'tag', color: 0);
      expect(calls, 7, reason: 'createTag 触发');
      await repo.updateTag(tag.id, name: 'tag2');
      expect(calls, 8, reason: 'updateTag 触发');

      await repo.deleteTask(t.id);
      expect(calls, 9, reason: 'deleteTask 触发');
      await repo.deleteTag(tag.id);
      expect(calls, 10, reason: 'deleteTag 触发');
      await repo.deleteProject(p.id);
      expect(calls, 11, reason: 'deleteProject 触发');
    });

    test('同步内部写入（applyMerged/mergeTombstones/pruneTombstones）不触发回调', () async {
      var calls = 0;
      repo.onDataChanged = () async => calls++;

      await repo.createProject(name: 'P', color: 0);
      expect(calls, 1);

      // 同步应用合并结果：不得触发（否则 同步→编辑→同步 死循环）。
      await repo.applyMerged(
        const MergedApplyOperation(
          upsertProjects: [
            Project(
              id: 'p-sync',
              name: 'P-sync',
              color: 0,
              description: '',
              sortOrder: 0,
              createdAt: 1,
              updatedAt: 1,
              deleted: 0,
            ),
          ],
        ),
      );
      expect(calls, 1, reason: 'applyMerged 是同步内部写入，不得触发回调');

      await repo.mergeTombstones([
        const TombstoneEntry(type: 'project', id: 'p-sync', updatedAt: 2),
      ]);
      expect(calls, 1, reason: 'mergeTombstones 不得触发回调');

      await repo.pruneTombstones(1);
      expect(calls, 1, reason: 'pruneTombstones 不得触发回调');
    });

    test('ensureInboxProject 实际写入时触发；已存在未删除时静默跳过', () async {
      var calls = 0;
      repo.onDataChanged = () async => calls++;

      await repo.ensureInboxProject('收件箱'); // 新建 → 触发
      expect(calls, 1);

      await repo.ensureInboxProject('收件箱'); // 已存在 → 不触发
      expect(calls, 1);
    });
  });

  group('syncSubtasks (原子子任务同步与重排)', () {
    test('原子性创建、更新、级联删除与重排 sortOrder', () async {
      final p = await repo.createProject(name: 'P', color: 0);
      final parent = await repo.createTask(projectId: p.id, title: 'Parent');

      final sub1 = await repo.createTask(
        projectId: p.id,
        parentId: parent.id,
        title: 'Sub1',
      );
      final sub2 = await repo.createTask(
        projectId: p.id,
        parentId: parent.id,
        title: 'Sub2',
      );

      var changedCount = 0;
      repo.onDataChanged = () async => changedCount++;

      await repo.syncSubtasks(
        parentId: parent.id,
        deleteSubtaskIds: [sub1.id],
        items: [
          (id: null, title: 'NewFirst', status: TaskStatus.todo),
          (id: sub2.id, title: 'Sub2Renamed', status: TaskStatus.done),
          (id: null, title: '  ', status: null), // 空标题忽略
        ],
      );

      expect(changedCount, 1, reason: '整个同步操作仅触发一次 onDataChanged');

      // sub1 已删除
      final deletedSub1 = await repo.tasks.getActiveById(sub1.id);
      expect(deletedSub1, isNull);

      // 墓碑记录已生成
      final tombstones = await repo.readTombstones();
      expect(tombstones.any((t) => t.id == sub1.id), isTrue);

      // 获取当前子任务
      final children = await repo.tasks.getDirectChildren(p.id, parent.id);
      expect(children.length, 2);

      // 验证顺序与数据
      expect(children[0].title, 'NewFirst');
      expect(children[0].status, TaskStatus.todo);
      expect(children[0].sortOrder, 0);
      expect(children[0].parentId, parent.id);

      expect(children[1].id, sub2.id);
      expect(children[1].title, 'Sub2Renamed');
      expect(children[1].status, TaskStatus.done);
      expect(children[1].sortOrder, 1);
    });

    test('父任务达到第 3 级时禁止创建新子任务', () async {
      final p = await repo.createProject(name: 'P', color: 0);
      final l1 = await repo.createTask(projectId: p.id, title: 'L1');
      final l2 = await repo.createTask(
        projectId: p.id,
        parentId: l1.id,
        title: 'L2',
      );
      final l3 = await repo.createTask(
        projectId: p.id,
        parentId: l2.id,
        title: 'L3',
      );

      expect(
        () => repo.syncSubtasks(
          parentId: l3.id,
          deleteSubtaskIds: [],
          items: [(id: null, title: 'L4_Invalid', status: null)],
        ),
        throwsA(isA<RepositoryException>()),
      );
    });
  });
}
