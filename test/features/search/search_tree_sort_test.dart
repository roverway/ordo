import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/tables.dart';
import 'package:ordo/features/search/search_providers.dart';

Task _task({
  required String id,
  required String title,
  String? parentId,
  TaskPriority priority = TaskPriority.none,
  int? endAt,
  int createdAt = 1000,
  int updatedAt = 1000,
}) {
  return Task(
    id: id,
    title: title,
    projectId: 'p1',
    parentId: parentId,
    description: '',
    notes: '',
    priority: priority,
    endAt: endAt,
    createdAt: createdAt,
    updatedAt: updatedAt,
    status: TaskStatus.todo,
    sortOrder: 0,
    deleted: 0,
  );
}

void main() {
  group('sortTasksAsTree tests', () {
    test('树状拓扑保证父任务始终在子任务之前，子任务紧随父任务其后（DFS）', () {
      // 构造父子层级：
      // Root A
      //   Child A1
      //     Grandchild A1_1
      //   Child A2
      // Root B
      //   Child B1
      final rootA = _task(id: 'rootA', title: 'Root A', updatedAt: 100);
      final childA1 = _task(
        id: 'childA1',
        title: 'Child A1',
        parentId: 'rootA',
        updatedAt: 500, // 更高 updatedAt，扁平排序时会在前面
      );
      final grandchildA11 = _task(
        id: 'gcA11',
        title: 'Grandchild A1_1',
        parentId: 'childA1',
        updatedAt: 600,
      );
      final childA2 = _task(
        id: 'childA2',
        title: 'Child A2',
        parentId: 'rootA',
        updatedAt: 200,
      );
      final rootB = _task(id: 'rootB', title: 'Root B', updatedAt: 300);
      final childB1 = _task(
        id: 'childB1',
        title: 'Child B1',
        parentId: 'rootB',
        updatedAt: 400,
      );

      // 乱序传入
      final input = [grandchildA11, childB1, rootB, childA2, rootA, childA1];

      final result = sortTasksAsTree(input, SearchSortPrinciple.title);
      final resultIds = result.map((t) => t.id).toList();

      expect(resultIds, [
        'rootA',
        'childA1',
        'gcA11',
        'childA2',
        'rootB',
        'childB1',
      ]);
    });

    test('同级根任务与同级子任务根据优先级排序', () {
      final rootLow = _task(
        id: 'rootLow',
        title: 'Root Low',
        priority: TaskPriority.low,
      );
      final rootHigh = _task(
        id: 'rootHigh',
        title: 'Root High',
        priority: TaskPriority.high,
      );
      final childHigh1 = _task(
        id: 'ch1',
        title: 'Child High 1',
        parentId: 'rootHigh',
        priority: TaskPriority.high,
      );
      final childHigh2 = _task(
        id: 'ch2',
        title: 'Child High 2',
        parentId: 'rootHigh',
        priority: TaskPriority.medium,
      );

      final result = sortTasksAsTree([
        childHigh2,
        rootLow,
        childHigh1,
        rootHigh,
      ], SearchSortPrinciple.priority);

      expect(result.map((t) => t.id).toList(), [
        'rootHigh',
        'ch1',
        'ch2',
        'rootLow',
      ]);
    });

    test('父任务不在当前集合时，子任务自动提升为可见根节点', () {
      final orphanChild = _task(
        id: 'orphan',
        title: 'Orphan',
        parentId: 'missing_parent',
      );
      final rootNormal = _task(id: 'normal', title: 'Normal');

      final result = sortTasksAsTree([
        orphanChild,
        rootNormal,
      ], SearchSortPrinciple.title);

      expect(result.map((t) => t.id).toList(), ['normal', 'orphan']);
    });
  });
}
