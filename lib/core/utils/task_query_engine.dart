// 统一任务查询与筛选引擎（TaskQueryEngine）。
//
// 负责在纯内存中执行基于 [FilterCriteria] 的多维度任务查询与筛选。
// 支持：
// 1. filterFlat：扁平查询，直接返回符合筛选条件的任务列表；
// 2. filterTree：树形保全查询，命中子任务时自动补充其完整祖先链，确保树形视图骨架完整不发生断链。

import '../db/database.dart';
import 'custom_view_models.dart';
import 'tree.dart';

/// 统一任务查询与筛选引擎。
class TaskQueryEngine {
  const TaskQueryEngine._();

  /// 扁平匹配过滤：直接返回命中 [criteria] 的任务。
  static List<Task> filterFlat({
    required List<Task> tasks,
    required FilterCriteria criteria,
    required Map<String, Project> projectsById,
    required Map<String, Set<String>> taskTagIdsMap,
    required int nowUtcMs,
  }) {
    if (tasks.isEmpty) return <Task>[];
    if (!criteria.hasActiveFilter) return List<Task>.from(tasks);

    final byId = indexTasksById(tasks);
    final childrenIndex = indexChildrenByParent(tasks);

    return tasks.where((task) {
      final directChildren = childrenIndex[task.id] ?? const <Task>[];
      final tagIds = taskTagIdsMap[task.id] ?? const <String>{};

      return matchesFilter(
        task,
        criteria,
        byId: byId,
        directChildren: directChildren,
        projectsById: projectsById,
        taskTagIds: tagIds,
        nowUtcMs: nowUtcMs,
        childrenIndex: childrenIndex,
      );
    }).toList();
  }

  /// 树形保全过滤：命中子任务时自动带入其完整祖先链，确保树形视图不发生断链。
  static List<Task> filterTree({
    required List<Task> tasks,
    required FilterCriteria criteria,
    required Map<String, Project> projectsById,
    required Map<String, Set<String>> taskTagIdsMap,
    required int nowUtcMs,
  }) {
    if (tasks.isEmpty) return <Task>[];
    if (!criteria.hasActiveFilter) return List<Task>.from(tasks);

    final byId = indexTasksById(tasks);
    final childrenIndex = indexChildrenByParent(tasks);

    // 1. 寻找所有直接匹配条件的任务 ID
    final matchedIds = <String>{};
    for (final task in tasks) {
      final directChildren = childrenIndex[task.id] ?? const <Task>[];
      final tagIds = taskTagIdsMap[task.id] ?? const <String>{};

      if (matchesFilter(
        task,
        criteria,
        byId: byId,
        directChildren: directChildren,
        projectsById: projectsById,
        taskTagIds: tagIds,
        nowUtcMs: nowUtcMs,
        childrenIndex: childrenIndex,
      )) {
        matchedIds.add(task.id);
      }
    }

    if (matchedIds.isEmpty) return <Task>[];

    // 2. 补全祖先链
    final visibleIds = <String>{...matchedIds};
    for (final id in matchedIds) {
      var current = byId[id];
      while (current?.parentId != null) {
        visibleIds.add(current!.parentId!);
        current = byId[current.parentId];
      }
    }

    return tasks.where((t) => visibleIds.contains(t.id)).toList();
  }
}
