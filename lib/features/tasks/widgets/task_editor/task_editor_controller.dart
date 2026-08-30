import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/tables.dart';

/// 编辑器模式：新建（create）无删除、子任务仅新增行；编辑（edit）⋯ 菜单含删除、
/// 子任务支持管理现有行。
enum TaskEditorMode { create, edit }

/// 子任务行（编辑器内部 UI 状态；id 为空表示新建行）。
class SubtaskRow {
  SubtaskRow.newRow()
    : id = null,
      status = TaskStatus.todo,
      controller = TextEditingController(),
      focusNode = FocusNode();

  SubtaskRow.existing(Task task)
    : id = task.id,
      status = task.status,
      controller = TextEditingController(text: task.title),
      focusNode = FocusNode();

  /// 已存在子任务的 id；null = 新建行。
  final String? id;

  /// 现有子任务状态（新建行默认为 todo）。
  TaskStatus status;

  final TextEditingController controller;

  /// 行内标题输入的焦点（用户要求：添加新行后自动聚焦到新行输入框）。
  final FocusNode focusNode;

  bool get isNew => id == null;

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

/// 任务编辑器共享控制器（容器持有）。
///
/// - 表单字段：编辑器内部经 taskFormProvider 双向桥接，容器无需直接访问；
/// - 子任务：容器通过 [subtaskRows] / [removedSubtaskIds] 在保存时统一落库。
class TaskEditorController extends ChangeNotifier {
  TaskEditorController({required this.mode}) {
    hasPendingNewSubtasksNotifier = ValueNotifier<bool>(hasPendingNewSubtasks);
  }

  final TaskEditorMode mode;

  /// 标题输入框焦点节点（支持容器受控聚焦，避免入场动画中途唤起软键盘导致弹窗上跳）。
  final FocusNode titleFocusNode = FocusNode();

  /// 表单文本控制器（编辑器 ↔ taskFormProvider 的双向桥）。
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  /// 备注显示开关（⋯ 菜单控制，默认隐藏，D8）；描述默认内联展示（59 讨论定稿）。
  bool showNotes = false;

  /// 子任务行（列表顺序即最终排序顺序）。
  final List<SubtaskRow> subtaskRows = [];

  /// 编辑模式：已从界面移除、待保存时级联删除的现有子任务 id。
  final List<String> removedSubtaskIds = [];

  // 编辑模式初始快照（用于判定子任务是否有改动）。
  List<String?> _originalOrder = const [];
  Map<String, String> _originalTitles = const {};
  Map<String, TaskStatus> _originalStatuses = const {};

  /// 状态派生禁用的轻量通知源（D7）：仅当「是否存在待保存新子任务」的布尔值
  /// 发生变化时通知监听者（如工具栏状态按钮），避免每敲一个字都全量重建整棵子任务树。
  late final ValueNotifier<bool> hasPendingNewSubtasksNotifier;

  void _updatePendingNewSubtasks() {
    final newValue = hasPendingNewSubtasks;
    if (hasPendingNewSubtasksNotifier.value != newValue) {
      hasPendingNewSubtasksNotifier.value = newValue;
    }
  }

  /// 用已存在的子任务初始化（编辑模式加载完成后调用；创建模式无需调用）。
  void initializeSubtasks(List<Task> existing) {
    for (final row in subtaskRows) {
      row.dispose();
    }
    subtaskRows
      ..clear()
      ..addAll(existing.map(SubtaskRow.existing));
    removedSubtaskIds.clear();
    _originalOrder = subtaskRows.map((r) => r.id).toList();
    _originalTitles = {for (final t in existing) t.id: t.title};
    _originalStatuses = {for (final t in existing) t.id: t.status};
    _updatePendingNewSubtasks();
    notifyListeners();
  }

  /// 编辑模式：子任务相对初始快照是否有改动（新增/删除/改标题/改状态/排序）。
  bool get hasSubtaskChanges {
    if (removedSubtaskIds.isNotEmpty) return true;
    final currentIds = subtaskRows.map((r) => r.id).toList();
    if (!listEquals(currentIds, _originalOrder)) return true;
    for (final row in subtaskRows) {
      final title = row.controller.text.trim();
      if (row.isNew) {
        if (title.isNotEmpty) return true;
      } else if (title != _originalTitles[row.id] ||
          row.status != _originalStatuses[row.id]) {
        return true;
      }
    }
    return false;
  }

  /// 是否有非空新建子任务行（状态派生提示的实时依据，D7）。
  bool get hasPendingNewSubtasks =>
      subtaskRows.any((r) => r.isNew && r.controller.text.trim().isNotEmpty);

  /// 非空新建子任务标题（创建模式自动保存时批量创建用）。
  List<String> get newSubtaskTitles => [
    for (final row in subtaskRows)
      if (row.isNew && row.controller.text.trim().isNotEmpty)
        row.controller.text.trim(),
  ];

  /// 保存成功后重设子任务快照：清空删除标记并重拍原始顺序/标题/状态，
  /// 使 [hasSubtaskChanges] 归 false（保存后离开不再误弹「未保存」提示，59 评审 Bug 1）。
  void markSubtasksSaved() {
    removedSubtaskIds.clear();
    _originalOrder = subtaskRows.map((r) => r.id).toList();
    _originalTitles = {
      for (final row in subtaskRows)
        if (row.id != null) row.id!: row.controller.text.trim(),
    };
    _originalStatuses = {
      for (final row in subtaskRows)
        if (row.id != null) row.id!: row.status,
    };
    _updatePendingNewSubtasks();
    notifyListeners();
  }

  /// 切换子任务完成状态。
  void toggleSubtaskStatus(SubtaskRow row) {
    row.status = row.status == TaskStatus.done
        ? TaskStatus.todo
        : TaskStatus.done;
    _updatePendingNewSubtasks();
    notifyListeners();
  }

  void toggleNotes() {
    showNotes = !showNotes;
    notifyListeners();
  }

  void addSubtask() {
    subtaskRows.add(SubtaskRow.newRow());
    _updatePendingNewSubtasks();
    notifyListeners();
  }

  /// 移除子任务行：现有行记入 [removedSubtaskIds]（保存时级联删除）。
  void removeSubtask(SubtaskRow row) {
    if (row.id != null) removedSubtaskIds.add(row.id!);
    subtaskRows.remove(row);
    row.dispose();
    _updatePendingNewSubtasks();
    notifyListeners();
  }

  void reorderSubtasks(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final row = subtaskRows.removeAt(oldIndex);
    subtaskRows.insert(newIndex, row);
    _updatePendingNewSubtasks();
    notifyListeners();
  }

  /// 子任务输入变化通知（状态派生禁用实时依据，D7）。
  /// 仅更新 [hasPendingNewSubtasksNotifier]，不触发全局 [notifyListeners]。
  void notifySubtasksChanged() {
    _updatePendingNewSubtasks();
  }

  @override
  void dispose() {
    titleFocusNode.dispose();
    titleController.dispose();
    descriptionController.dispose();
    notesController.dispose();
    for (final row in subtaskRows) {
      row.dispose();
    }
    hasPendingNewSubtasksNotifier.dispose();
    super.dispose();
  }
}
