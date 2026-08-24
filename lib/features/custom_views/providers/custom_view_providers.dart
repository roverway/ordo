import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/utils/custom_view_models.dart';
import '../../projects/project_providers.dart';
import '../../tags/tag_providers.dart';

/// 全部活跃自定义视图（StreamProvider，按 sortOrder 升序）。
final customViewsStreamProvider = StreamProvider<List<CustomView>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.customViews.watchAll();
});

/// 单个自定义视图详情（StreamProvider.family）。
final customViewDetailProvider = StreamProvider.family<CustomView?, String>((
  ref,
  id,
) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.customViews.watchById(id);
});

/// 全部活跃任务（StreamProvider，用于跨面板筛选与看板展示）。
final allActiveTasksStreamProvider = StreamProvider<List<Task>>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.tasks.watchAllActive();
});

/// 全部项目 Map 缓存（id -> Project）。
final allProjectsMapProvider = Provider<AsyncValue<Map<String, Project>>>((
  ref,
) {
  final projectsAsync = ref.watch(projectsStreamProvider);
  return projectsAsync.whenData(
    (projects) => {for (final p in projects) p.id: p},
  );
});

/// 全部标签 Map 缓存（id -> Tag）。
final allTagsMapProvider = Provider<AsyncValue<Map<String, Tag>>>((ref) {
  final tagsAsync = ref.watch(tagsStreamProvider);
  return tagsAsync.whenData((tags) => {for (final t in tags) t.id: t});
});

/// 面板任务计算结果（过滤 + 排序）。
class PanelTasksResult {
  const PanelTasksResult({required this.tasks, required this.totalCount});

  /// 排序后的扁平任务列表。
  final List<Task> tasks;

  /// 匹配的任务总数。
  final int totalCount;
}

/// 计算单个面板匹配并排序后的任务列表。
final panelTasksProvider =
    Provider.family<AsyncValue<PanelTasksResult>, CustomViewPanelConfig>((
      ref,
      panel,
    ) {
      final tasksAsync = ref.watch(allActiveTasksStreamProvider);
      final projectsMapAsync = ref.watch(allProjectsMapProvider);

      if (tasksAsync.hasError) {
        return AsyncError(
          tasksAsync.error!,
          tasksAsync.stackTrace ?? StackTrace.current,
        );
      }
      if (projectsMapAsync.hasError) {
        return AsyncError(
          projectsMapAsync.error!,
          projectsMapAsync.stackTrace ?? StackTrace.current,
        );
      }

      if (tasksAsync.isLoading || projectsMapAsync.isLoading) {
        return const AsyncLoading();
      }

      final allTasks = tasksAsync.value ?? const <Task>[];
      final projectsById = projectsMapAsync.value ?? const <String, Project>{};

      final byId = <String, Task>{for (final t in allTasks) t.id: t};
      final childrenByParent = <String?, List<Task>>{};
      for (final t in allTasks) {
        childrenByParent.putIfAbsent(t.parentId, () => []).add(t);
      }

      final nowUtcMs = DateTime.now().toUtc().millisecondsSinceEpoch;

      final matched = <Task>[];
      for (final task in allTasks) {
        final directChildren = childrenByParent[task.id] ?? const [];
        final taskTagIds = <String>{};
        if (matchesFilter(
          task,
          panel.filter,
          byId: byId,
          directChildren: directChildren,
          projectsById: projectsById,
          taskTagIds: taskTagIds,
          nowUtcMs: nowUtcMs,
        )) {
          matched.add(task);
        }
      }

      final sorted = sortPanelTasks(
        matched,
        sortBy: panel.sortBy,
        sortDirection: panel.sortDirection,
      );

      return AsyncData(
        PanelTasksResult(tasks: sorted, totalCount: sorted.length),
      );
    });

/// 跨面板拖拽智能变更结果。
enum PanelDropActionType {
  none,
  updated,
  derivedStatusBlocked,
  requiresConfirmation,
}

class PanelDropResult {
  const PanelDropResult({
    required this.actionType,
    this.message,
    this.targetStatus,
    this.targetPriority,
    this.targetProjectId,
  });

  final PanelDropActionType actionType;
  final String? message;
  final TaskStatus? targetStatus;
  final TaskPriority? targetPriority;
  final String? targetProjectId;
}

/// 自定义视图管理与操作。
class CustomViewOperations {
  CustomViewOperations(this._ref);

  final Ref _ref;

  TodoRepository get _repo => _ref.read(todoRepositoryProvider);

  /// 新建自定义视图。
  Future<CustomView> createView({
    required String name,
    String icon = 'dashboard_outlined',
    int color = 0xFF3B82F6,
    String layoutMode = 'kanban',
    required List<CustomViewPanelConfig> panels,
  }) async {
    return _repo.createCustomView(
      name: name,
      icon: icon,
      color: color,
      layoutMode: layoutMode,
      panelsJson: encodePanelsJson(panels),
    );
  }

  /// 更新自定义视图。
  Future<void> updateView(
    String id, {
    String? name,
    String? icon,
    int? color,
    String? layoutMode,
    List<CustomViewPanelConfig>? panels,
    int? sortOrder,
  }) async {
    await _repo.updateCustomView(
      id,
      name: name,
      icon: icon,
      color: color,
      layoutMode: layoutMode,
      panelsJson: panels != null ? encodePanelsJson(panels) : null,
      sortOrder: sortOrder,
    );
  }

  /// 删除自定义视图。
  Future<void> deleteView(String id) async {
    await _repo.deleteCustomView(id);
  }

  /// 批量重排自定义视图。
  Future<void> reorderViews(List<String> orderedIds) async {
    await _repo.reorderCustomViews(orderedIds);
  }

  /// 跨面板拖拽任务的智能属性变更逻辑（docs/65-custom-views-and-panels.md §3.4）。
  Future<PanelDropResult> handleTaskDroppedBetweenPanels({
    required Task task,
    required CustomViewPanelConfig sourcePanel,
    required CustomViewPanelConfig targetPanel,
    required bool hasSubtasks,
  }) async {
    final sf = sourcePanel.filter;
    final tf = targetPanel.filter;

    // 检查状态差异
    final hasStatusDiff =
        tf.statuses.isNotEmpty &&
        (sf.statuses.isEmpty || sf.statuses != tf.statuses);
    final targetStatus = tf.statuses.length == 1 ? tf.statuses.first : null;

    // 检查优先级差异
    final hasPriorityDiff =
        tf.priorities.isNotEmpty &&
        (sf.priorities.isEmpty || sf.priorities != tf.priorities);
    final targetPriority = tf.priorities.length == 1
        ? tf.priorities.first
        : null;

    // 检查项目差异
    final hasProjectDiff =
        tf.projectIds.isNotEmpty &&
        (sf.projectIds.isEmpty || sf.projectIds != tf.projectIds);
    final targetProjectId = tf.projectIds.length == 1
        ? tf.projectIds.first
        : null;

    // 1. 如果有子任务且需要修改状态 → 禁止直接修改父任务状态（AGENTS.md 硬性约束）
    if (hasStatusDiff && hasSubtasks && targetStatus != null) {
      return const PanelDropResult(
        actionType: PanelDropActionType.derivedStatusBlocked,
        message: '该任务包含子任务，状态由子任务自动派生计算',
      );
    }

    // 2. 单一维度差异判断
    final diffCount =
        (hasStatusDiff && targetStatus != null ? 1 : 0) +
        (hasPriorityDiff && targetPriority != null ? 1 : 0) +
        (hasProjectDiff && targetProjectId != null ? 1 : 0);

    if (diffCount == 1) {
      if (hasStatusDiff && targetStatus != null) {
        await _repo.updateTask(task.id, status: targetStatus);
        return PanelDropResult(
          actionType: PanelDropActionType.updated,
          targetStatus: targetStatus,
        );
      } else if (hasPriorityDiff && targetPriority != null) {
        await _repo.updateTask(task.id, priority: targetPriority);
        return PanelDropResult(
          actionType: PanelDropActionType.updated,
          targetPriority: targetPriority,
        );
      } else if (hasProjectDiff && targetProjectId != null) {
        await _repo.moveTaskToProject(task.id, targetProjectId);
        return PanelDropResult(
          actionType: PanelDropActionType.updated,
          targetProjectId: targetProjectId,
        );
      }
    }

    // 多维度差异或无法唯一定位单一目标属性
    if (diffCount > 1 ||
        (diffCount == 0 &&
            (hasStatusDiff || hasPriorityDiff || hasProjectDiff))) {
      return PanelDropResult(
        actionType: PanelDropActionType.requiresConfirmation,
        targetStatus: targetStatus,
        targetPriority: targetPriority,
        targetProjectId: targetProjectId,
      );
    }

    return const PanelDropResult(actionType: PanelDropActionType.none);
  }
}

final customViewOperationsProvider = Provider<CustomViewOperations>((ref) {
  return CustomViewOperations(ref);
});
