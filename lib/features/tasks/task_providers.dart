import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/todo_repository.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations_en.dart';
import '../../core/l10n/app_localizations_zh.dart';
import '../../core/utils/derived.dart';
import '../../core/utils/tree.dart';
import '../projects/project_providers.dart';
import '../settings/settings_providers.dart';

/// 某项目下全部任务（StreamProvider 自动刷新）。
final projectTasksProvider = StreamProvider.family<List<Task>, String>((
  ref,
  projectId,
) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.tasks.watchByProject(projectId);
});

/// 某任务关联标签（流式：DB 变更自动刷新，任务列表/日历行标签 chips 用）。
///
/// 从 calendar_providers 迁移至任务域（57-task-page-polish.md 批 2：
/// 一级任务卡片头部展示标签 chips）。
final taskTagsProvider = StreamProvider.family<List<Tag>, String>((
  ref,
  taskId,
) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.tags.watchTagsForTask(taskId);
});

/// 内置收件箱展示名（ARB 文案，随当前语言切换）。
final inboxProjectNameProvider = Provider<String>((ref) {
  final locale = ref.watch(localeProvider);
  // 显式枚举：en → 英文，其余（当前仅 zh）→ 中文。新增语言时在此扩展。
  return switch (locale.languageCode) {
    'en' => AppLocalizationsEn().inbox,
    _ => AppLocalizationsZh().inbox,
  };
});

/// 内置收件箱项目（确保存在后返回，幂等）。
///
/// 收件箱行已存在且未删除时 [ensureInboxProject] 直接返回，不改名；
/// 缺失/墓碑时自动创建或恢复。
final inboxProjectProvider = FutureProvider<Project>((ref) {
  final repo = ref.watch(todoRepositoryProvider);
  final name = ref.watch(inboxProjectNameProvider);
  return repo.ensureInboxProject(name);
});

/// 任务表单保存状态（成功/失败/空闲）。
enum TaskFormStatus { idle, saving, success, error }

/// 任务表单状态。
class TaskFormState {
  TaskFormState({
    this.id,
    this.projectId,
    this.parentId,
    this.title = '',
    this.description = '',
    this.notes = '',
    this.startAt,
    this.endAt,
    this.createdAt = 0,
    this.completedAt,
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.none,
    this.existingTagIds = const [],
    this.selectedTagIds = const [],
    this.isEditing = false,
    this.statusEnum = TaskFormStatus.idle,
  });

  final String? id;
  final String? projectId;
  final String? parentId;
  final String title;
  final String description;
  final String notes;
  final int? startAt;
  final int? endAt;
  final int createdAt;
  final int? completedAt;
  final TaskStatus status;
  final TaskPriority priority;
  final List<String> existingTagIds;
  final List<String> selectedTagIds;
  final bool isEditing;
  final TaskFormStatus statusEnum;

  /// 哨兵值：区分「未传参（保留原值）」与「显式传 null（清空可空字段）」。
  ///
  /// 修复（59 讨论定稿 Bug）：此前 copyWith 用 `?? this.x`，传 null 被当作
  /// 「保留原值」，导致 loadTask 加载一级任务/无时间任务时残留上一个任务的
  /// parentId/startAt/endAt，以及日期清除（updateXxx(null)）失效。
  static const Object _unset = Object();

  TaskFormState copyWith({
    Object? id = _unset,
    Object? projectId = _unset,
    Object? parentId = _unset,
    Object? title = _unset,
    Object? description = _unset,
    Object? notes = _unset,
    Object? startAt = _unset,
    Object? endAt = _unset,
    Object? createdAt = _unset,
    Object? completedAt = _unset,
    Object? status = _unset,
    Object? priority = _unset,
    Object? existingTagIds = _unset,
    Object? selectedTagIds = _unset,
    Object? isEditing = _unset,
    Object? statusEnum = _unset,
  }) {
    return TaskFormState(
      id: identical(id, _unset) ? this.id : id as String?,
      projectId: identical(projectId, _unset)
          ? this.projectId
          : projectId as String?,
      parentId: identical(parentId, _unset)
          ? this.parentId
          : parentId as String?,
      title: identical(title, _unset) ? this.title : title as String,
      description: identical(description, _unset)
          ? this.description
          : description as String,
      notes: identical(notes, _unset) ? this.notes : notes as String,
      startAt: identical(startAt, _unset) ? this.startAt : startAt as int?,
      endAt: identical(endAt, _unset) ? this.endAt : endAt as int?,
      createdAt: identical(createdAt, _unset)
          ? this.createdAt
          : createdAt as int,
      completedAt: identical(completedAt, _unset)
          ? this.completedAt
          : completedAt as int?,
      status: identical(status, _unset) ? this.status : status as TaskStatus,
      priority: identical(priority, _unset)
          ? this.priority
          : priority as TaskPriority,
      existingTagIds: identical(existingTagIds, _unset)
          ? this.existingTagIds
          : existingTagIds as List<String>,
      selectedTagIds: identical(selectedTagIds, _unset)
          ? this.selectedTagIds
          : selectedTagIds as List<String>,
      isEditing: identical(isEditing, _unset)
          ? this.isEditing
          : isEditing as bool,
      statusEnum: identical(statusEnum, _unset)
          ? this.statusEnum
          : statusEnum as TaskFormStatus,
    );
  }
}

/// 任务表单 Notifier（Riverpod 3.x Notifier 模式）。
class TaskFormNotifier extends Notifier<TaskFormState> {
  TodoRepository get _repo => ref.read(todoRepositoryProvider);

  // 用于追踪原始值（判断是否有改动）。
  String? _originalProjectId;
  String _originalTitle = '';
  String _originalDescription = '';
  String _originalNotes = '';
  int? _originalStartAt;
  int? _originalEndAt;
  TaskStatus _originalStatus = TaskStatus.todo;
  TaskPriority _originalPriority = TaskPriority.none;
  List<String> _originalTagIds = [];

  @override
  TaskFormState build() => TaskFormState();

  Future<void> loadTask(String taskId) async {
    final task = await _repo.tasks.getActiveById(taskId);
    if (task == null) return;
    final tagIds = await _repo.tags.tagIdsForTask(taskId);
    state = state.copyWith(
      id: task.id,
      projectId: task.projectId,
      parentId: task.parentId,
      title: task.title,
      description: task.description,
      notes: task.notes,
      startAt: task.startAt,
      endAt: task.endAt,
      createdAt: task.createdAt,
      completedAt: task.completedAt,
      status: task.status,
      priority: task.priority,
      existingTagIds: tagIds,
      selectedTagIds: tagIds,
      isEditing: true,
    );
    _captureOriginal();
  }

  void setProjectAndParent(String projectId, String? parentId) {
    // 注意：不能直接用 copyWith —— copyWith 对传 null 的字段会保留原值，
    // 无法表达「清空 parentId」（切换项目时父任务不能跨项目）。
    state = TaskFormState(
      id: state.id,
      projectId: projectId,
      parentId: parentId,
      title: state.title,
      description: state.description,
      notes: state.notes,
      startAt: state.startAt,
      endAt: state.endAt,
      createdAt: state.createdAt,
      completedAt: state.completedAt,
      status: state.status,
      priority: state.priority,
      existingTagIds: state.existingTagIds,
      selectedTagIds: state.selectedTagIds,
      isEditing: state.isEditing,
      statusEnum: state.statusEnum,
    );
  }

  /// 进入新建模式：重置表单状态，避免复用上一个已编辑任务的状态
  /// （审查发现 Bug 2：保存成功后不 reset 导致新建误改旧任务）。
  void resetForNew(String projectId, String? parentId) {
    _originalProjectId = null;
    _originalTitle = '';
    _originalDescription = '';
    _originalNotes = '';
    _originalStartAt = null;
    _originalEndAt = null;
    _originalStatus = TaskStatus.todo;
    _originalPriority = TaskPriority.none;
    _originalTagIds = [];
    state = TaskFormState(projectId: projectId, parentId: parentId);
  }

  void _captureOriginal() {
    _originalProjectId = state.projectId;
    _originalTitle = state.title;
    _originalDescription = state.description;
    _originalNotes = state.notes;
    _originalStartAt = state.startAt;
    _originalEndAt = state.endAt;
    _originalStatus = state.status;
    _originalPriority = state.priority;
    _originalTagIds = List<String>.from(state.selectedTagIds);
  }

  bool get hasChanges {
    if (!state.isEditing) {
      return state.title.isNotEmpty ||
          state.description.isNotEmpty ||
          state.notes.isNotEmpty ||
          state.startAt != null ||
          state.endAt != null ||
          state.priority != TaskPriority.none ||
          state.selectedTagIds.isNotEmpty;
    }
    return state.projectId != _originalProjectId ||
        state.title != _originalTitle ||
        state.description != _originalDescription ||
        state.notes != _originalNotes ||
        state.startAt != _originalStartAt ||
        state.endAt != _originalEndAt ||
        state.status != _originalStatus ||
        state.priority != _originalPriority ||
        !_listEquals(state.selectedTagIds, _originalTagIds);
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sortedA = List<String>.from(a)..sort();
    final sortedB = List<String>.from(b)..sort();
    for (var i = 0; i < sortedA.length; i++) {
      if (sortedA[i] != sortedB[i]) return false;
    }
    return true;
  }

  Future<String?> save() async {
    if (state.title.trim().isEmpty) return 'title_required';
    if (state.startAt != null &&
        state.endAt != null &&
        state.endAt! < state.startAt!) {
      return 'end_time_before_start';
    }

    state = state.copyWith(statusEnum: TaskFormStatus.saving);
    try {
      if (state.isEditing && state.id != null) {
        // 1. 跨项目移动（如果项目发生变更）
        if (state.projectId != null &&
            _originalProjectId != null &&
            state.projectId != _originalProjectId) {
          await _repo.moveTaskToProject(state.id!, state.projectId!);
          _originalProjectId = state.projectId;
        }

        // 2. 更新任务。
        // 有子任务的任务状态由子任务派生（AGENTS.md §3-2），此时不传 status，
        // 否则 Repository 会抛异常导致任何编辑都失败（审查发现 Bug 1）。
        final children = await _repo.tasks.getDirectChildren(
          state.projectId!,
          state.id!,
        );
        await _repo.updateTask(
          state.id!,
          title: state.title.trim(),
          description: state.description,
          notes: state.notes,
          startAt: Value(state.startAt),
          endAt: Value(state.endAt),
          status: children.isEmpty ? state.status : null,
          priority: state.priority,
        );
        // 更新标签关联（全量替换）。
        await _repo.tags.setTaskTags(state.id!, state.selectedTagIds);
      } else {
        // 新建任务。
        final task = await _repo.createTask(
          projectId: state.projectId!,
          parentId: state.parentId,
          title: state.title.trim(),
          description: state.description,
          notes: state.notes,
          startAt: state.startAt,
          endAt: state.endAt,
          status: state.status,
          priority: state.priority,
        );
        if (state.selectedTagIds.isNotEmpty) {
          await _repo.tags.setTaskTags(task.id, state.selectedTagIds);
        }
        state = state.copyWith(id: task.id, isEditing: true);
      }
      _captureOriginal();
      state = state.copyWith(statusEnum: TaskFormStatus.success);
      return null;
    } on RepositoryException catch (e) {
      state = state.copyWith(statusEnum: TaskFormStatus.error);
      return e.message;
    }
  }

  void reset() {
    state = TaskFormState();
  }

  void updateTitle(String value) => state = state.copyWith(title: value);
  void updateDescription(String value) =>
      state = state.copyWith(description: value);
  void updateNotes(String value) => state = state.copyWith(notes: value);
  void updateStartAt(int? value) => state = state.copyWith(startAt: value);
  void updateEndAt(int? value) => state = state.copyWith(endAt: value);
  void updateStatus(TaskStatus value) => state = state.copyWith(
    status: value,
    completedAt: value == TaskStatus.done
        ? (state.completedAt ?? DateTime.now().millisecondsSinceEpoch)
        : null,
  );
  void updatePriority(TaskPriority value) =>
      state = state.copyWith(priority: value);

  /// 全量替换已选标签 id 列表（标签选择弹层用）。
  void setSelectedTags(List<String> tagIds) {
    state = state.copyWith(selectedTagIds: List<String>.from(tagIds));
  }

  void toggleTag(String tagId) {
    final current = List<String>.from(state.selectedTagIds);
    if (current.contains(tagId)) {
      current.remove(tagId);
    } else {
      current.add(tagId);
    }
    state = state.copyWith(selectedTagIds: current);
  }
}

/// 任务表单 Provider。
final taskFormProvider = NotifierProvider<TaskFormNotifier, TaskFormState>(
  TaskFormNotifier.new,
);

/// 是否隐藏已完成任务（settings 表持久化，docs/64-local-preferences.md §3.2）。
///
/// 默认 false = 显示全部；仅项目任务树（TaskListPage 项目作用域）消费，
/// 切换即时生效（TaskTree 过滤在 build 内 watch 本 provider）并持久化
/// （重启保留）。settings key = `hide_completed`：'1' = 隐藏 / '0' 或缺失 = 显示。
class HideCompletedTasksNotifier extends Notifier<bool> {
  /// settings 表 key（设备本地，不同步）。
  static const String _key = 'hide_completed';

  @override
  bool build() {
    final value = ref.watch(appSettingsCacheProvider).get(_key);
    return value == '1';
  }

  /// 切换隐藏状态并持久化（写内存缓存 + 穿透 settings 表）。
  ///
  /// 评审跟进：先更新 [state]，穿透写失败仅丢失持久化、不阻断切换。
  Future<void> toggle() async {
    final cache = ref.read(appSettingsCacheProvider);
    final next = !state;
    state = next;
    try {
      await cache.set(_key, next ? '1' : '0');
    } catch (e) {
      debugPrint('hideCompleted 持久化失败：${e.runtimeType}');
    }
  }
}

final hideCompletedTasksProvider =
    NotifierProvider<HideCompletedTasksNotifier, bool>(
      HideCompletedTasksNotifier.new,
    );

/// 项目任务概览数据（未完成数、总数、完成进度）。
class ProjectTaskSummary {
  const ProjectTaskSummary({
    this.totalCount = 0,
    this.uncompletedCount = 0,
    this.progress = 0.0,
  });

  final int totalCount;
  final int uncompletedCount;
  final double progress;
}

/// 单个项目任务概览数据 Provider（未完成数、总数、完成进度）。
///
/// 将卡片原本分别监听的 3 个 Provider 聚合成 1 个基于 [projectTasksProvider] 的只读数据结构。
final projectSummaryProvider = Provider.family<ProjectTaskSummary, String>((
  ref,
  projectId,
) {
  final tasksAsync = ref.watch(projectTasksProvider(projectId));
  return tasksAsync.when(
    data: (tasks) {
      if (tasks.isEmpty) return const ProjectTaskSummary();
      final uncompleted = uncompletedCount(tasks);
      final subtree = tasks.toList();
      final roots = subtree.where((t) => t.parentId == null).toList();
      final prog = roots.isEmpty ? 0.0 : progress(roots.first, subtree);
      return ProjectTaskSummary(
        totalCount: tasks.length,
        uncompletedCount: uncompleted,
        progress: prog,
      );
    },
    loading: () => const ProjectTaskSummary(),
    error: (_, _) => const ProjectTaskSummary(),
  );
});

/// 项目未完成任务数 Provider。
///
/// 统计口径与 [projectProgressProvider] 一致：父任务按**派生状态**（§6.1）计数，
/// 全部子任务均 done/cancelled 时父任务视为完成，不再计入（审查发现 Bug 4）。
/// 计算逻辑见 [uncompletedCount]（纯函数，可单测）。
final projectUncompletedCountProvider = Provider.family<int, String>((
  ref,
  projectId,
) {
  final tasksAsync = ref.watch(projectTasksProvider(projectId));
  return tasksAsync.when(
    data: uncompletedCount,
    loading: () => 0,
    error: (_, _) => 0,
  );
});

/// 项目完成进度 Provider（0.0~1.0）。
final projectProgressProvider = Provider.family<double, String>((
  ref,
  projectId,
) {
  final tasksAsync = ref.watch(projectTasksProvider(projectId));
  return tasksAsync.when(
    data: (tasks) {
      if (tasks.isEmpty) return 0.0;
      final subtree = tasks.toList();
      final roots = subtree.where((t) => t.parentId == null).toList();
      if (roots.isEmpty) return 0.0;
      return progress(roots.first, subtree);
    },
    loading: () => 0.0,
    error: (_, _) => 0.0,
  );
});

/// 某文件夹下全部项目的未完成任务总数。
final folderUncompletedCountProvider = Provider.family<int, String>((
  ref,
  folderId,
) {
  final groupingAsync = ref.watch(projectsByFolderProvider);
  return groupingAsync.maybeWhen(
    data: (grouping) {
      final projects = grouping.folderProjects[folderId] ?? const <Project>[];
      var total = 0;
      for (final p in projects) {
        total += ref.watch(projectSummaryProvider(p.id)).uncompletedCount;
      }
      return total;
    },
    orElse: () => 0,
  );
});

/// 全局项目概览统计（总任务数、已完成任务数、总待办任务数，排除内置收件箱）。
final allProjectsOverviewSummaryProvider =
    Provider<({int total, int completed, int uncompleted})>((ref) {
      final projects =
          ref.watch(projectsStreamProvider).value ?? const <Project>[];
      var total = 0;
      var uncompleted = 0;
      for (final p in projects) {
        if (p.id == inboxProjectId) continue;
        final summary = ref.watch(projectSummaryProvider(p.id));
        total += summary.totalCount;
        uncompleted += summary.uncompletedCount;
      }
      final completed = (total - uncompleted).clamp(0, total);
      return (total: total, completed: completed, uncompleted: uncompleted);
    });

/// 展开状态管理。
class TreeExpandNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => {};

  void toggle(String taskId) {
    state = {...state, taskId: !(state[taskId] ?? true)};
  }

  void expandAll(List<String> taskIds) {
    state = {for (final id in taskIds) id: true};
  }

  void collapseAll() {
    state = {};
  }

  bool isExpanded(String taskId) => state[taskId] ?? true;
}

/// 树展开状态 Provider（按项目区分）。
final treeExpandProvider =
    NotifierProvider.family<TreeExpandNotifier, Map<String, bool>, String>(
      (ref) => TreeExpandNotifier(),
    );

/// 树节点（展开后的扁平列表用于渲染）。
class TreeNode {
  TreeNode({
    required this.task,
    required this.depth,
    required this.hasChildren,
    required this.isExpanded,
  });

  final Task task;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
}

/// 构建树的扁平渲染列表。
List<TreeNode> buildTreeNodes({
  required List<Task> tasks,
  required Map<String, bool> expandState,
}) {
  if (tasks.isEmpty) return const [];

  final childrenIndex = indexChildrenByParent(tasks);

  // 根任务（parentId == null）按 sortOrder 排序。
  final roots = childrenIndex[null] ?? const <Task>[];
  final sortedRoots = List<Task>.from(roots)
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  final result = <TreeNode>[];

  void walk(Task task, int depth) {
    final children = childrenIndex[task.id] ?? const <Task>[];
    final sortedChildren = List<Task>.from(children)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final isExpanded = expandState[task.id] ?? true;
    result.add(
      TreeNode(
        task: task,
        depth: depth,
        hasChildren: sortedChildren.isNotEmpty,
        isExpanded: isExpanded,
      ),
    );
    if (isExpanded) {
      for (final child in sortedChildren) {
        walk(child, depth + 1);
      }
    }
  }

  for (final root in sortedRoots) {
    walk(root, 0);
  }

  return result;
}

/// 获取某任务的子树 ID（含自身）。
List<String> getSubtreeIds(String taskId, List<Task> tasks) {
  final childrenIndex = indexChildrenByParent(tasks);
  final ids = <String>[];
  void collect(String id) {
    ids.add(id);
    for (final child in childrenIndex[id] ?? const <Task>[]) {
      collect(child.id);
    }
  }

  collect(taskId);
  return ids;
}
