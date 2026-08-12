// 任务编辑全屏页（59-task-editor-optimization.md §5.3 定稿）。
//
// 全屏容器：AppBar（返回 + 项目名 + 下拉双箭头 + 保存按钮 + ⋯ 菜单）+ 共享编辑器
// [TaskEditor]（showTopBar/showToolbar 均关，项目切换与 ⋯ 菜单放 AppBar）。
//
// - 保存：显式保存（AppBar 保存按钮）+ 未保存离开拦截（PopScope + hasChanges，
//   含子任务改动），55 §8 现状保留（D2）。
// - 子任务管理（D3）：加载现有子任务；新增/删除/拖拽排序**延迟到保存时统一执行**
//   （与显式保存语义一致，取消编辑不产生意外数据变更）；删除现有子任务带确认。
// - 删除任务（D4）：⋯ 菜单含删除，确认后级联硬删（repo.deleteTask）。
// - 父任务（parentId 非空）：编辑器内只读信息行展示。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/repositories/todo_repository.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../projects/project_providers.dart';
import 'task_providers.dart';
import 'widgets/task_editor.dart';

/// Task edit page — unified editor, TickTick-inspired full-screen container.
class TaskEditPage extends ConsumerStatefulWidget {
  const TaskEditPage({
    super.key,
    this.taskId,
    this.projectId,
    this.parentId,
    this.initialStartAt,
    this.initialEndAt,
  });

  final String? taskId;
  final String? projectId;
  final String? parentId;

  /// 预填开始/截止时间（UTC 毫秒，M3 日历「点日期新建」传入）。
  final int? initialStartAt;
  final int? initialEndAt;

  @override
  ConsumerState<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends ConsumerState<TaskEditPage> {
  late final TaskEditorController _editorController;
  bool _hasChildren = false;
  bool _initialized = false;

  bool get _isEditing => widget.taskId != null;

  @override
  void initState() {
    super.initState();
    _editorController = TaskEditorController(
      mode: _isEditing ? TaskEditorMode.edit : TaskEditorMode.create,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (_initialized) return;
    _initialized = true;

    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(taskFormProvider.notifier);

    if (widget.taskId != null) {
      await notifier.loadTask(widget.taskId!);
      final loadedState = ref.read(taskFormProvider);

      final repo = ref.read(todoRepositoryProvider);
      final children = await repo.tasks.getDirectChildren(
        loadedState.projectId!,
        widget.taskId,
      );
      if (mounted) {
        _editorController.initializeSubtasks(children);
        setState(() => _hasChildren = children.isNotEmpty);
      }
    } else {
      if (widget.projectId == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.projectRequired)));
          context.go('/projects');
        }
        return;
      }
      notifier.resetForNew(widget.projectId!, widget.parentId);
      if (widget.initialStartAt != null) {
        notifier.updateStartAt(widget.initialStartAt);
      }
      if (widget.initialEndAt != null) {
        notifier.updateEndAt(widget.initialEndAt);
      }
    }
  }

  @override
  void dispose() {
    _editorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final formState = ref.watch(taskFormProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final notifier = ref.read(taskFormProvider.notifier);
        if (notifier.hasChanges || _editorController.hasSubtaskChanges) {
          final discard = await showConfirmDialog(
            context: context,
            title: l10n.unsavedChanges,
            message: l10n.unsavedChangesConfirm,
            confirmLabel: l10n.discard,
            confirmColor: colorScheme.error,
          );
          if (discard && context.mounted) {
            ref.read(taskFormProvider.notifier).reset();
            context.pop();
          }
        } else {
          context.pop();
        }
      },
      child: Scaffold(
        // AppBar：返回（自动 leading）+ 项目名 + 下拉双箭头 + 保存 + ⋯ 菜单。
        appBar: AppBar(
          titleSpacing: AppTokens.spaceXs,
          title: const TaskProjectSwitcher(),
          actions: [
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check, size: 18),
              label: Text(l10n.save),
            ),
            TaskEditorMenuButton(
              controller: _editorController,
              onDeleteRequested: _isEditing ? _confirmDeleteTask : null,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          child: TaskEditor(
            controller: _editorController,
            showTopBar: false,
            showToolbar: false,
            showSubtasks: formState.parentId == null,
            hasExistingChildren: _hasChildren,
            onDeleteRequested: _isEditing ? _confirmDeleteTask : null,
          ),
        ),
        // 底部工具栏常驻（键盘弹出时随 viewInsets 上移）。
        bottomNavigationBar: ListenableBuilder(
          listenable: _editorController,
          builder: (context, _) => SafeArea(
            top: false,
            child: Material(
              color: colorScheme.surface,
              elevation: AppTokens.elevationCard,
              child: TaskEditorToolbar(
                // 已有子任务或待保存的新建子任务行 → 状态由子任务派生，禁用。
                statusDisabled:
                    _hasChildren || _editorController.hasPendingNewSubtasks,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 删除任务（D4，⋯ 菜单入口，带确认弹窗）─────────────────────────

  Future<void> _confirmDeleteTask() async {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final formState = ref.read(taskFormProvider);
    final taskId = formState.id;
    if (taskId == null) return; // 新建模式不应出现删除入口。

    final title = formState.title.trim().isEmpty
        ? l10n.taskTitle
        : formState.title.trim();
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.deleteTask,
      message: '${l10n.deleteTaskConfirm(title)}\n${l10n.deleteTaskWarning}',
      confirmLabel: l10n.delete,
      confirmColor: theme.colorScheme.error,
    );
    if (!confirmed || !mounted) return;

    try {
      final repo = ref.read(todoRepositoryProvider);
      await repo.deleteTask(taskId);
      if (!mounted) return;
      ref.read(taskFormProvider.notifier).reset();
      context.pop();
    } on RepositoryException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ── 显式保存（D2）─────────────────────────────────────────────────

  Future<void> _save() async {
    final notifier = ref.read(taskFormProvider.notifier);
    final errorKey = await notifier.save();

    if (!mounted) return;

    if (errorKey != null) {
      final l10n = AppLocalizations.of(context);
      final message = switch (errorKey) {
        'title_required' => l10n.titleRequired,
        'end_time_before_start' => l10n.endTimeBeforeStart,
        _ => errorKey,
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    await _syncSubtasks();
    if (mounted) context.pop();
  }

  /// 保存成功后统一执行子任务增删改排序（D3，延迟落库）。
  ///
  /// 顺序：1) 级联删除已移除的现有子任务 → 2) 创建非空新行 → 3) 更新改名的
  /// 现有行 → 4) 按 UI 顺序左→右移动重排（moveTask 同级重排收敛）。
  /// 任一失败仅提示（父任务已保存，与新建弹窗兜底行为一致）。
  Future<void> _syncSubtasks() async {
    final repo = ref.read(todoRepositoryProvider);
    final formState = ref.read(taskFormProvider);
    final parentId = formState.id;
    final projectId = formState.projectId;
    if (parentId == null || projectId == null) return;

    final rows = _editorController.subtaskRows;
    try {
      // 1. 删除已移除的现有子任务（级联）。
      for (final id in List<String>.from(_editorController.removedSubtaskIds)) {
        await repo.deleteTask(id);
      }

      // 2. 创建非空新行（先追加到末尾，第 4 步再移动到最终位置）。
      final createdIds = <SubtaskRow, String>{};
      for (final row in rows) {
        if (!row.isNew) continue;
        final title = row.controller.text.trim();
        if (title.isEmpty) continue;
        final task = await repo.createTask(
          projectId: projectId,
          parentId: parentId,
          title: title,
        );
        createdIds[row] = task.id;
      }

      // 3. 更新改名的现有行（标题被清空时保留原标题，不做破坏性变更）。
      for (final row in rows) {
        if (row.isNew) continue;
        final title = row.controller.text.trim();
        if (title.isEmpty) continue;
        final task = await repo.tasks.getActiveById(row.id!);
        if (task != null && task.title != title) {
          await repo.updateTask(row.id!, title: title);
        }
      }

      // 4. 按 UI 顺序重排（现有行 + 新创建行；空新行不占位）。
      final orderedIds = <String>[
        for (final row in rows)
          if (row.id != null)
            row.id!
          else if (createdIds.containsKey(row))
            createdIds[row]!,
      ];
      for (var i = 0; i < orderedIds.length; i++) {
        final id = orderedIds[i];
        final siblings = await repo.tasks.getDirectChildren(
          projectId,
          parentId,
        );
        final currentIndex = siblings.indexWhere((t) => t.id == id);
        if (currentIndex == i) continue;
        await repo.moveTask(id, newParentId: parentId, newIndex: i);
      }
    } on RepositoryException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
