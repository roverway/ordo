// 层级校验纯函数单测（docs/40-data-model.md §5，70-milestones.md M1 任务 3）。

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/tables.dart';
import 'package:todo/core/utils/tree.dart';

/// 构造测试用 Task（仅层级相关字段有意义）。
Task _task(String id, {String? parentId}) => Task(
  id: id,
  projectId: 'p1',
  parentId: parentId,
  title: id,
  description: '',
  notes: '',
  status: TaskStatus.todo,
  priority: TaskPriority.none,
  sortOrder: 0,
  createdAt: 0,
  updatedAt: 0,
  deleted: 0,
);

void main() {
  group('depthOf', () {
    test('根任务深度 = 1', () {
      final root = _task('a');
      expect(depthOf(root, indexTasksById([root])), 1);
    });

    test('子任务深度 = 父深度 + 1', () {
      final a = _task('a');
      final b = _task('b', parentId: 'a');
      final c = _task('c', parentId: 'b');
      final byId = indexTasksById([a, b, c]);
      expect(depthOf(a, byId), 1);
      expect(depthOf(b, byId), 2);
      expect(depthOf(c, byId), 3);
    });

    test('链条断裂时提前终止不抛异常', () {
      final c = _task('c', parentId: 'missing');
      expect(depthOf(c, indexTasksById([c])), 2);
    });
  });

  group('subtreeDepthOf', () {
    test('叶子节点 = 1', () {
      final leaf = _task('leaf');
      expect(subtreeDepthOf(leaf, indexChildrenByParent([leaf])), 1);
    });

    test('3 级链 = 3', () {
      final a = _task('a');
      final b = _task('b', parentId: 'a');
      final c = _task('c', parentId: 'b');
      final index = indexChildrenByParent([a, b, c]);
      expect(subtreeDepthOf(a, index), 3);
      expect(subtreeDepthOf(b, index), 2);
      expect(subtreeDepthOf(c, index), 1);
    });

    test('分支树取最大后代深度', () {
      final a = _task('a');
      final b = _task('b', parentId: 'a');
      final c = _task('c', parentId: 'a');
      final d = _task('d', parentId: 'c');
      final index = indexChildrenByParent([a, b, c, d]);
      expect(subtreeDepthOf(a, index), 3); // a → c → d
      expect(subtreeDepthOf(c, index), 2);
    });

    test('空子树（无子任务）', () {
      final a = _task('a');
      expect(subtreeDepthOf(a, indexChildrenByParent([a])), 1);
    });
  });

  group('isDescendantOf', () {
    test('自身不是自身的后代', () {
      final a = _task('a');
      expect(isDescendantOf(a, a, indexTasksById([a])), isFalse);
    });

    test('直接子任务是后代', () {
      final a = _task('a');
      final b = _task('b', parentId: 'a');
      final byId = indexTasksById([a, b]);
      expect(isDescendantOf(b, a, byId), isTrue);
    });

    test('孙任务是后代', () {
      final a = _task('a');
      final b = _task('b', parentId: 'a');
      final c = _task('c', parentId: 'b');
      final byId = indexTasksById([a, b, c]);
      expect(isDescendantOf(c, a, byId), isTrue);
    });

    test('兄弟/无关节点不是后代', () {
      final a = _task('a');
      final b = _task('b', parentId: 'a');
      final c = _task('c', parentId: 'a');
      final d = _task('d');
      final byId = indexTasksById([a, b, c, d]);
      expect(isDescendantOf(b, c, byId), isFalse);
      expect(isDescendantOf(d, a, byId), isFalse);
    });

    test('祖先不是后代', () {
      final a = _task('a');
      final b = _task('b', parentId: 'a');
      final byId = indexTasksById([a, b]);
      expect(isDescendantOf(a, b, byId), isFalse);
    });
  });

  group('移动校验边界（纯函数组合，§5.1）', () {
    test('depth 3 的父节点下不可再建子任务（depth(parent) >= 3 拒绝）', () {
      final a = _task('a');
      final b = _task('b', parentId: 'a');
      final c = _task('c', parentId: 'b');
      final byId = indexTasksById([a, b, c]);
      expect(depthOf(c, byId), 3);
      // 创建子任务条件：depth(parent) < 3 → c 处拒绝。
      expect(depthOf(c, byId) < 3, isFalse);
    });

    test('depth 2 的父节点下可建子任务（depth(parent) < 3 允许）', () {
      final a = _task('a');
      final b = _task('b', parentId: 'a');
      final byId = indexTasksById([a, b]);
      expect(depthOf(b, byId), 2);
      expect(depthOf(b, byId) < 3, isTrue);
    });

    test('移动深度校验：targetDepth + subtreeDepth <= 3', () {
      // a(1) → b(2) → c(3)；d(1) → e(2)。
      final a = _task('a');
      final b = _task('b', parentId: 'a');
      final c = _task('c', parentId: 'b');
      final d = _task('d');
      final e = _task('e', parentId: 'd');
      final all = [a, b, c, d, e];
      final byId = indexTasksById(all);
      final childrenIndex = indexChildrenByParent(all);

      // 把 d（subtreeDepth=2）移到 b（depth=2）下：2+2=4 > 3 → 拒绝。
      expect(
        depthOf(b, byId) + subtreeDepthOf(d, childrenIndex),
        greaterThan(3),
      );

      // 把 e（subtreeDepth=1）移到 b（depth=2）下：2+1=3 ≤ 3 → 允许。
      expect(
        depthOf(b, byId) + subtreeDepthOf(e, childrenIndex),
        lessThanOrEqualTo(3),
      );

      // 把 b（subtreeDepth=3）移到根：0+3=3 ≤ 3 → 允许。
      expect(0 + subtreeDepthOf(b, childrenIndex), lessThanOrEqualTo(3));
    });

    test('防环：移动到自身后代被拒绝（isDescendantOf 判定）', () {
      final a = _task('a');
      final b = _task('b', parentId: 'a');
      final c = _task('c', parentId: 'b');
      final byId = indexTasksById([a, b, c]);
      // 把 a 移到 c 下：c 是 a 的后代 → 拒绝。
      expect(isDescendantOf(c, a, byId), isTrue);
    });
  });
}
