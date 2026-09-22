import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/utils/derived.dart';
import '../../../core/utils/tree.dart';
import '../../projects/project_providers.dart';
import '../models/quadrant_models.dart';

/// 四象限视图模式管理（2x2 矩阵 vs 列表模式）。
class QuadrantViewModeNotifier extends Notifier<QuadrantViewMode> {
  @override
  QuadrantViewMode build() => QuadrantViewMode.matrix;

  void setMode(QuadrantViewMode mode) => state = mode;
  void toggleMode() => state = state == QuadrantViewMode.matrix
      ? QuadrantViewMode.list
      : QuadrantViewMode.matrix;
}

final quadrantViewModeProvider =
    NotifierProvider<QuadrantViewModeNotifier, QuadrantViewMode>(
      QuadrantViewModeNotifier.new,
    );

/// 聚焦列表模式下选中的象限（null 表示全部象限）。
class QuadrantFocusTabNotifier extends Notifier<QuadrantType?> {
  @override
  QuadrantType? build() => null;

  void select(QuadrantType? type) => state = type;
  void setTab(QuadrantType? type) => select(type);
}

final quadrantFocusTabProvider =
    NotifierProvider<QuadrantFocusTabNotifier, QuadrantType?>(
      QuadrantFocusTabNotifier.new,
    );

/// 四象限筛选器状态管理器。
class QuadrantFilterNotifier extends Notifier<QuadrantFilterState> {
  @override
  QuadrantFilterState build() => const QuadrantFilterState();

  /// 设置特定的清单集合（null 表示全量全部清单）。
  void setProjectSelection(Set<String>? projectIds) {
    state = state.copyWith(
      selectedProjectIds: projectIds,
      clearProjectIds: projectIds == null,
    );
  }

  /// 切换单个清单的选择状态。
  void toggleProject(String projectId, Set<String> allAvailableProjectIds) {
    final current = state.selectedProjectIds != null
        ? Set<String>.from(state.selectedProjectIds!)
        : Set<String>.from(allAvailableProjectIds);

    if (current.contains(projectId)) {
      current.remove(projectId);
    } else {
      current.add(projectId);
    }

    if (current.length == allAvailableProjectIds.length) {
      // 包含所有可用清单，等价于未限制全量状态
      state = state.copyWith(clearProjectIds: true);
    } else {
      state = state.copyWith(selectedProjectIds: current);
    }
  }

  /// 批量切换某个文件夹下所有清单的选择状态。
  ///
  /// 如果该文件夹下项目未全选，则全选；如果已全选，则全部取消勾选。
  void toggleFolder(
    List<String> folderProjectIds,
    Set<String> allAvailableProjectIds,
  ) {
    if (folderProjectIds.isEmpty) return;

    final current = state.selectedProjectIds != null
        ? Set<String>.from(state.selectedProjectIds!)
        : Set<String>.from(allAvailableProjectIds);

    final allSelected = folderProjectIds.every(current.contains);

    if (allSelected) {
      current.removeAll(folderProjectIds);
    } else {
      current.addAll(folderProjectIds);
    }

    if (current.length == allAvailableProjectIds.length) {
      state = state.copyWith(clearProjectIds: true);
    } else {
      state = state.copyWith(selectedProjectIds: current);
    }
  }

  /// 重置为全量无限制范围。
  void resetAll() {
    state = state.copyWith(clearProjectIds: true);
  }

  /// 切换是否显示已完成任务。
  void toggleShowCompleted() {
    state = state.copyWith(showCompleted: !state.showCompleted);
  }
}

final quadrantFilterProvider =
    NotifierProvider<QuadrantFilterNotifier, QuadrantFilterState>(
      QuadrantFilterNotifier.new,
    );

/// 纯函数：根据当前任务数据与筛选条件计算四象限聚合展示数据（可单测）。
QuadrantData buildQuadrantData({
  required List<Task> tasks,
  required DateTime now,
  required QuadrantFilterState filter,
  required Map<String, List<Tag>> taskTagsMap,
  required List<Project> projects,
}) {
  final projectsMap = {for (final p in projects) p.id: p};
  final parentIds = <String>{
    for (final t in tasks)
      if (t.parentId != null) t.parentId!,
  };
  final childrenIndex = indexChildrenByParent(tasks);

  final q1 = <QuadrantTaskView>[];
  final q2 = <QuadrantTaskView>[];
  final q3 = <QuadrantTaskView>[];
  final q4 = <QuadrantTaskView>[];

  final todayStartMs = DateTime(
    now.year,
    now.month,
    now.day,
  ).millisecondsSinceEpoch;

  int completedCount = 0;
  for (final task in tasks) {
    if (task.status == TaskStatus.done) completedCount++;

    // 清单范围过滤
    if (!filter.matches(task)) continue;

    final directChildren = childrenIndex[task.id] ?? const <Task>[];
    final effectiveStatus = derivedStatus(task, directChildren, childrenIndex);

    // 取消的任务不纳入四象限
    if (effectiveStatus == TaskStatus.cancelled) continue;

    // 默认不展示已完成任务
    if (!filter.showCompleted && effectiveStatus == TaskStatus.done) continue;

    final tags = taskTagsMap[task.id] ?? const [];
    final project = projectsMap[task.projectId];
    final isParent = parentIds.contains(task.id);
    final counts = isParent ? taskSubtreeCounts(task, tasks) : null;
    final isPastDeadline = task.endAt != null && task.endAt! < todayStartMs;

    final quadrant = classifyTask(task, now);
    final viewItem = QuadrantTaskView(
      task: task,
      quadrant: quadrant,
      tags: tags,
      effectiveStatus: effectiveStatus,
      hasChildren: isParent,
      isOverdue: isPastDeadline && effectiveStatus != TaskStatus.done,
      projectName: project?.name,
      projectColor: project?.color,
      progressValue: isParent ? taskProgress(task, tasks) : null,
      subtaskProgressText: counts != null
          ? '${counts.done}/${counts.total}'
          : null,
    );
    switch (quadrant) {
      case QuadrantType.urgentImportant:
        q1.add(viewItem);
        break;
      case QuadrantType.notUrgentImportant:
        q2.add(viewItem);
        break;
      case QuadrantType.urgentUnimportant:
        q3.add(viewItem);
        break;
      case QuadrantType.notUrgentUnimportant:
        q4.add(viewItem);
        break;
    }
  }

  // 象限内排序：
  // Q1 (重要紧急): 截止时间升序（最紧急在前），再按更新时间降序
  q1.sort((a, b) {
    final aEnd = a.task.endAt;
    final bEnd = b.task.endAt;
    if (aEnd != null && bEnd != null) {
      final cmp = aEnd.compareTo(bEnd);
      if (cmp != 0) return cmp;
    } else if (aEnd != null) {
      return -1;
    } else if (bEnd != null) {
      return 1;
    }
    return b.task.updatedAt.compareTo(a.task.updatedAt);
  });

  // Q2 (重要不紧急): 优先级降序（High 在 Medium 前），再按更新时间降序
  q2.sort((a, b) {
    final pA = a.task.priority.index;
    final pB = b.task.priority.index;
    final cmp = pB.compareTo(pA);
    if (cmp != 0) return cmp;
    return b.task.updatedAt.compareTo(a.task.updatedAt);
  });

  // Q3 (不重要紧急): 截止时间升序，再按更新时间降序
  q3.sort((a, b) {
    final aEnd = a.task.endAt;
    final bEnd = b.task.endAt;
    if (aEnd != null && bEnd != null) {
      final cmp = aEnd.compareTo(bEnd);
      if (cmp != 0) return cmp;
    } else if (aEnd != null) {
      return -1;
    } else if (bEnd != null) {
      return 1;
    }
    return b.task.updatedAt.compareTo(a.task.updatedAt);
  });

  // Q4 (不重要不紧急): 更新时间降序
  q4.sort((a, b) => b.task.updatedAt.compareTo(a.task.updatedAt));

  return QuadrantData(
    q1UrgentImportant: q1,
    q2NotUrgentImportant: q2,
    q3UrgentUnimportant: q3,
    q4NotUrgentUnimportant: q4,
    totalAllCount: tasks.length,
    completedCount: completedCount,
  );
}

/// 四象限数据流式 Provider。
final quadrantDataProvider = StreamProvider<QuadrantData>((ref) async* {
  final repo = ref.watch(todoRepositoryProvider);
  final filter = ref.watch(quadrantFilterProvider);

  yield* repo.tasks.watchAllActive().asyncMap((tasks) async {
    final projects = await repo.projects.getAll();
    final allTags = await repo.tags.getAll();
    final allTaskTags = await repo.tags.getAllTaskTags();

    final tagsById = {for (final t in allTags) t.id: t};
    final taskTagsMap = <String, List<Tag>>{};
    for (final tt in allTaskTags) {
      final tag = tagsById[tt.tagId];
      if (tag != null) {
        taskTagsMap.putIfAbsent(tt.taskId, () => []).add(tag);
      }
    }

    return buildQuadrantData(
      tasks: tasks,
      now: DateTime.now(),
      filter: filter,
      taskTagsMap: taskTagsMap,
      projects: projects,
    );
  });
});

/// 四象限动作原子控制器。
class QuadrantActionController {
  QuadrantActionController(this._repo);

  final TodoRepository _repo;

  /// 跨象限移动已有任务。
  ///
  /// **关键准则**：仅修改 [Task.priority] 与 [Task.endAt]，
  /// 绝不更改任务原有的所属清单 [Task.projectId] 或父子层级关系 [Task.parentId]。
  Future<void> moveTaskToQuadrant(Task task, QuadrantType target) async {
    final mutation = calculateQuadrantMutation(target, task, DateTime.now());

    // 防御性处理：如果变更后的 endAt 小于现有的 startAt，清除冲突的 startAt 以免验证失败
    Value<int?> startAtValue = const Value.absent();
    if (mutation.endAt != null &&
        task.startAt != null &&
        task.startAt! > mutation.endAt!) {
      startAtValue = const Value(null);
    }

    await _repo.updateTask(
      task.id,
      priority: mutation.priority,
      endAt: Value(mutation.endAt),
      startAt: startAtValue,
    );
  }

  /// 切换任务完成状态。
  Future<void> toggleTaskDone(Task task, bool isDone) async {
    final newStatus = isDone ? TaskStatus.done : TaskStatus.todo;
    await _repo.updateTask(task.id, status: newStatus);
  }

  /// 删除任务（软删除）。
  Future<void> deleteTask(String taskId) async {
    await _repo.deleteTask(taskId);
  }
}

final quadrantActionControllerProvider = Provider<QuadrantActionController>((
  ref,
) {
  final repo = ref.watch(todoRepositoryProvider);
  return QuadrantActionController(repo);
});
