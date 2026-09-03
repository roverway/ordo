import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/tables.dart';
import 'package:todo/core/utils/custom_view_models.dart';
import 'package:todo/core/utils/task_query_engine.dart';

void main() {
  final now = DateTime(2026, 9, 3, 12, 0, 0);
  final nowUtcMs = now.toUtc().millisecondsSinceEpoch;
  final todayStartUtcMs = DateTime(
    2026,
    9,
    3,
    0,
    0,
    0,
  ).toUtc().millisecondsSinceEpoch;
  final yesterdayUtcMs = DateTime(
    2026,
    9,
    2,
    10,
    0,
    0,
  ).toUtc().millisecondsSinceEpoch;

  final projectA = Project(
    id: 'p1',
    name: '项目1',
    color: 0xFF123456,
    description: '',
    sortOrder: 0,
    createdAt: 0,
    updatedAt: 0,
    deleted: 0,
  );

  Task createTask(
    String id, {
    String? parentId,
    String title = 'task',
    TaskStatus status = TaskStatus.todo,
    TaskPriority priority = TaskPriority.none,
    int? startAt,
    int? endAt,
    int? completedAt,
    int updatedAt = 0,
  }) => Task(
    id: id,
    projectId: 'p1',
    parentId: parentId,
    title: title,
    description: '',
    notes: '',
    startAt: startAt,
    endAt: endAt,
    completedAt: completedAt,
    status: status,
    priority: priority,
    sortOrder: 0,
    createdAt: 0,
    updatedAt: updatedAt,
    deleted: 0,
  );

  group('TaskQueryEngine.filterFlat', () {
    test('派生状态过滤：父任务子任务全 done，自身能被 done 筛选命中', () {
      final tasks = [
        createTask('root', status: TaskStatus.todo),
        createTask('c1', parentId: 'root', status: TaskStatus.done),
        createTask('c2', parentId: 'root', status: TaskStatus.done),
      ];

      final results = TaskQueryEngine.filterFlat(
        tasks: tasks,
        criteria: const FilterCriteria(statuses: [TaskStatus.done]),
        projectsById: {'p1': projectA},
        taskTagIdsMap: const {},
        nowUtcMs: nowUtcMs,
      );

      expect(results.map((t) => t.id).toSet(), {'root', 'c1', 'c2'});
    });

    test('completedToday：仅命中今天完成的任务，排除昨天完成的任务', () {
      final tasks = [
        createTask(
          'done_today',
          status: TaskStatus.done,
          completedAt: todayStartUtcMs + 3600000,
        ),
        createTask(
          'done_yesterday',
          status: TaskStatus.done,
          completedAt: yesterdayUtcMs,
          endAt: todayStartUtcMs + 7200000, // 截止日是今天但昨天就完成了
        ),
        createTask(
          'todo_today',
          status: TaskStatus.todo,
          endAt: todayStartUtcMs,
        ),
      ];

      final results = TaskQueryEngine.filterFlat(
        tasks: tasks,
        criteria: const FilterCriteria(dateScope: DateScopeEnum.completedToday),
        projectsById: {'p1': projectA},
        taskTagIdsMap: const {},
        nowUtcMs: nowUtcMs,
      );

      expect(results.map((t) => t.id).toList(), ['done_today']);
    });
  });

  group('TaskQueryEngine.filterTree', () {
    test('子任务命中时，自动带出其父节点和祖先节点保持树形结构', () {
      final tasks = [
        createTask('root', title: '父任务'),
        createTask('child', parentId: 'root', title: '子任务'),
        createTask(
          'grandchild',
          parentId: 'child',
          title: '已完成的目标孙任务',
          status: TaskStatus.done,
        ),
        createTask('other_root', title: '未命中根任务'),
      ];

      final results = TaskQueryEngine.filterTree(
        tasks: tasks,
        criteria: const FilterCriteria(statuses: [TaskStatus.done]),
        projectsById: {'p1': projectA},
        taskTagIdsMap: const {},
        nowUtcMs: nowUtcMs,
      );

      // grandchild 命中 done，其父级 child 和 root 均被保留，形成完整祖先树
      expect(results.map((t) => t.id).toSet(), {'root', 'child', 'grandchild'});
    });
  });
}
