// 派生状态纯函数单测（docs/40-data-model.md §6，70-milestones.md M1 任务 4）。

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/tables.dart';
import 'package:todo/core/utils/derived.dart';

/// 构造测试用 Task。
Task _task(
  String id,
  TaskStatus status, {
  String? parentId,
  int sortOrder = 0,
  int deleted = 0,
}) => Task(
  id: id,
  projectId: 'p1',
  parentId: parentId,
  title: id,
  description: '',
  notes: '',
  status: status,
  sortOrder: sortOrder,
  createdAt: 0,
  updatedAt: 0,
  deleted: deleted,
);

void main() {
  group('derivedStatus（§6.1）', () {
    test('无子任务 → 返回 parent.status（手动状态）', () {
      final parent = _task('p', TaskStatus.inProgress);
      expect(derivedStatus(parent, const []), TaskStatus.inProgress);
    });

    test('全部 done → done', () {
      final parent = _task('p', TaskStatus.todo);
      final children = [
        _task('c1', TaskStatus.done),
        _task('c2', TaskStatus.done),
      ];
      expect(derivedStatus(parent, children), TaskStatus.done);
    });

    test('存在 inProgress → inProgress（即使有 done）', () {
      final parent = _task('p', TaskStatus.todo);
      final children = [
        _task('c1', TaskStatus.done),
        _task('c2', TaskStatus.inProgress),
      ];
      expect(derivedStatus(parent, children), TaskStatus.inProgress);
    });

    test('全部 cancelled → cancelled', () {
      final parent = _task('p', TaskStatus.todo);
      final children = [
        _task('c1', TaskStatus.cancelled),
        _task('c2', TaskStatus.cancelled),
      ];
      expect(derivedStatus(parent, children), TaskStatus.cancelled);
    });

    test('混合（todo + done）→ todo', () {
      final parent = _task('p', TaskStatus.todo);
      final children = [
        _task('c1', TaskStatus.done),
        _task('c2', TaskStatus.todo),
      ];
      expect(derivedStatus(parent, children), TaskStatus.todo);
    });

    test('排除 deleted 子任务', () {
      final parent = _task('p', TaskStatus.todo);
      final children = [
        _task('c1', TaskStatus.done, deleted: 1),
        _task('c2', TaskStatus.done),
      ];
      // 排除 deleted 后只剩 c2(done) → done。
      expect(derivedStatus(parent, children), TaskStatus.done);
    });

    test('全部子任务 deleted → 视为无子任务，返回 parent.status', () {
      final parent = _task('p', TaskStatus.cancelled);
      final children = [
        _task('c1', TaskStatus.done, deleted: 1),
        _task('c2', TaskStatus.done, deleted: 1),
      ];
      expect(derivedStatus(parent, children), TaskStatus.cancelled);
    });
  });

  group('progress（§6.2）', () {
    test('空子树 → 0.0', () {
      final root = _task('r', TaskStatus.todo);
      expect(progress(root, const []), 0.0);
    });

    test('全 done → 1.0', () {
      final root = _task('r', TaskStatus.done);
      final subtree = [
        root,
        _task('c1', TaskStatus.done),
        _task('c2', TaskStatus.done),
      ];
      expect(progress(root, subtree), 1.0);
    });

    test('混入 inProgress → 部分完成', () {
      final root = _task('r', TaskStatus.todo);
      final subtree = [
        root,
        _task('c1', TaskStatus.done),
        _task('c2', TaskStatus.inProgress),
        _task('c3', TaskStatus.todo),
      ];
      // total=4, done=1 → 0.25。
      expect(progress(root, subtree), closeTo(0.25, 1e-9));
    });

    test('全 cancelled → 0.0', () {
      final root = _task('r', TaskStatus.cancelled);
      final subtree = [
        root,
        _task('c1', TaskStatus.cancelled),
        _task('c2', TaskStatus.cancelled),
      ];
      expect(progress(root, subtree), 0.0);
    });

    test('排除 cancelled 与 deleted', () {
      final root = _task('r', TaskStatus.todo);
      final subtree = [
        root,
        _task('c1', TaskStatus.done),
        _task('c2', TaskStatus.cancelled), // 排除
        _task('c3', TaskStatus.done, deleted: 1), // 排除
        _task('c4', TaskStatus.todo),
      ];
      // total=3（root + c1 + c4），done=1 → 1/3。
      expect(progress(root, subtree), closeTo(1 / 3, 1e-9));
    });

    test('全部被排除 → 0.0', () {
      final root = _task('r', TaskStatus.cancelled);
      final subtree = [
        root,
        _task('c1', TaskStatus.cancelled),
        _task('c2', TaskStatus.done, deleted: 1),
      ];
      expect(progress(root, subtree), 0.0);
    });
  });

  group('uncompletedCount（§6.1 派生口径，Bug 4 回归）', () {
    test('父任务全部子任务完成时不再计入', () {
      final count = uncompletedCount([
        _task('parent', TaskStatus.todo),
        _task('c1', TaskStatus.done, parentId: 'parent', sortOrder: 1),
        _task('c2', TaskStatus.done, parentId: 'parent', sortOrder: 2),
      ]);
      // 父任务派生 done + 子任务 done → 0。
      expect(count, 0);
    });

    test('父任务有未完成子任务时计入父与子', () {
      final count = uncompletedCount([
        _task('parent', TaskStatus.todo),
        _task('c1', TaskStatus.done, parentId: 'parent', sortOrder: 1),
        _task(
          'c2',
          TaskStatus.inProgress,
          parentId: 'parent',
          sortOrder: 2,
        ),
      ]);
      // 父派生 inProgress（计入）+ c2（计入）→ 2。
      expect(count, 2);
    });

    test('cancelled 任务不计入', () {
      final count = uncompletedCount([
        _task('t1', TaskStatus.cancelled),
        _task('t2', TaskStatus.todo),
      ]);
      expect(count, 1);
    });

    test('deleted 任务不计入', () {
      final count = uncompletedCount([
        _task('t1', TaskStatus.todo, deleted: 1),
        _task('t2', TaskStatus.todo),
      ]);
      expect(count, 1);
    });
  });
}
