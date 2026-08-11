import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/repositories/todo_repository.dart';
import '../../core/db/tables.dart';
import '../../core/utils/derived.dart';
import '../../core/utils/tree.dart';
import '../projects/project_providers.dart';

/// 某项目下全部任务（StreamProvider 自动刷新）。
final projectTasksProvider = StreamProvider.family<List<Task>, String>((
  ref,
  projectId,
) {
  final repo = ref.watch(todoRepositoryProvider);
  return repo.tasks.watchByProject(projectId);
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
    this.status = TaskStatus.todo,
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
  final TaskStatus status;
  final List<String> existingTagIds;
  final List<String> selectedTagIds;
  final bool isEditing;
  final TaskFormStatus statusEnum;

  TaskFormState copyWith({
    String? id,
    String? projectId,
    String? parentId,
    String? title,
    String? description,
    String? notes,
    int? startAt,
    int? endAt,
    TaskStatus? status,
    List<String>? existingTagIds,
    List<String>? selectedTagIds,
    bool? isEditing,
    TaskFormStatus? statusEnum,
  }) {
    return TaskFormState(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      parentId: parentId ?? this.parentId,
      title: title ?? this.title,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      status: status ?? this.status,
      existingTagIds: existingTagIds ?? this.existingTagIds,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      isEditing: isEditing ?? this.isEditing,
      statusEnum: statusEnum ?? this.statusEnum,
    );
  }
}

/// 任务表单 Notifier（Riverpod 3.x Notifier 模式）。
class TaskFormNotifier extends Notifier<TaskFormState> {
  TodoRepository get _repo => ref.read(todoRepositoryProvider);

  // 用于追踪原始值（判断是否有改动）。
  String _originalTitle = '';
  String _originalDescription = '';
  String _originalNotes = '';
  int? _originalStartAt;
  int? _originalEndAt;
  TaskStatus _originalStatus = TaskStatus.todo;
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
      status: task.status,
      existingTagIds: tagIds,
      selectedTagIds: tagIds,
      isEditing: true,
    );
    _captureOriginal();
  }

  void setProjectAndParent(String projectId, String? parentId) {
    state = state.copyWith(projectId: projectId, parentId: parentId);
  }

  void _captureOriginal() {
    _originalTitle = state.title;
    _originalDescription = state.description;
    _originalNotes = state.notes;
    _originalStartAt = state.startAt;
    _originalEndAt = state.endAt;
    _originalStatus = state.status;
    _originalTagIds = List<String>.from(state.selectedTagIds);
  }

  bool get hasChanges {
    if (!state.isEditing) {
      return state.title.isNotEmpty ||
          state.description.isNotEmpty ||
          state.notes.isNotEmpty ||
          state.startAt != null ||
          state.endAt != null ||
          state.selectedTagIds.isNotEmpty;
    }
    return state.title != _originalTitle ||
        state.description != _originalDescription ||
        state.notes != _originalNotes ||
        state.startAt != _originalStartAt ||
        state.endAt != _originalEndAt ||
        state.status != _originalStatus ||
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
        // 更新任务。
        await _repo.updateTask(
          state.id!,
          title: state.title.trim(),
          description: state.description,
          notes: state.notes,
          startAt: state.startAt,
          endAt: state.endAt,
          status: state.status,
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
  void updateStatus(TaskStatus value) => state = state.copyWith(status: value);

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

/// 项目未完成任务数 Provider。
final projectUncompletedCountProvider = Provider.family<int, String>((
  ref,
  projectId,
) {
  final tasksAsync = ref.watch(projectTasksProvider(projectId));
  return tasksAsync.when(
    data: (tasks) => tasks
        .where(
          (t) =>
              t.status != TaskStatus.done && t.status != TaskStatus.cancelled,
        )
        .length,
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
