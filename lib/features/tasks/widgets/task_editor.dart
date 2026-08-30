// 统一任务编辑器（59-task-editor-optimization.md §5.1 定稿，D1–D9）。
//
// 新建底部弹窗（TaskCreateSheet）与编辑全屏页（TaskEditPage）共用同一编辑器，
// **仅呈现容器不同**（弹出式 60–65% 高 / 全屏式 AppBar）：
//
//   顶部栏：[项目图标] 项目名 [下拉双箭头]      [⋯ 三点菜单]
//   内容区：① 任务标题（titleLarge，无边框，自动聚焦）
//           ② 描述：默认内联展示；备注：⋯ 菜单开关（D8）
//           ③ 子任务列表：○ 圆形复选框 + 文字 + ≡ 拖拽 + 删除按钮
//   底部工具栏：[日期] [状态] [标签] [优先级] [附件占位禁用]（D5/D6/D7）
//
// 职责边界：编辑器只负责**表单字段**（经 taskFormProvider 读写）与**子任务 UI 状态**
// （经 [TaskEditorController] 暴露）；保存/自动保存/子任务落库由容器执行。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_menu_item.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../projects/project_providers.dart';
import '../task_providers.dart';
import 'task_editor/project_picker_sheet.dart';
import 'task_editor/subtask_list.dart';
import 'task_editor/task_editor_controller.dart';
import 'task_editor/task_editor_toolbar.dart';

export '../../../core/platform/keyboard_inset_bridge.dart'
    show KeyboardAttachedToolbar;
export 'task_editor/project_picker_sheet.dart';
export 'task_editor/subtask_list.dart';
export 'task_editor/subtask_row_tile.dart';
export 'task_editor/tag_picker_sheet.dart';
export 'task_editor/task_date_picker_dialogs.dart';
export 'task_editor/task_editor_controller.dart';
export 'task_editor/task_editor_toolbar.dart';

/// 统一任务编辑器（共享内容区 + 顶部栏 + 底部工具栏）。
class TaskEditor extends ConsumerStatefulWidget {
  const TaskEditor({
    super.key,
    required this.controller,
    this.showTopBar = true,
    this.showToolbar = true,
    this.showSubtasks = true,
    this.hasExistingChildren = false,
    this.autofocus = true,
    this.onDeleteRequested,
  });

  /// 编辑器共享控制器（容器持有并负责 dispose）。
  final TaskEditorController controller;

  /// 是否展示顶部栏（编辑全屏页的 AppBar 已含项目切换 + ⋯ 菜单，传 false，59 §5.3）。
  final bool showTopBar;

  /// 是否在内容区末尾渲染底部工具栏（编辑全屏页由容器在 body 内自行钉底
  /// 渲染并随键盘上移，传 false；59 键盘修复）。
  final bool showToolbar;

  /// 是否展示子任务区（新建态仅 1 级任务展示；编辑态由容器按被编辑任务
  /// 自身深度 <3 判定，方案 B）。
  final bool showSubtasks;

  /// 任务当前在 DB 中是否已有子任务（状态派生禁用的静态依据）。
  final bool hasExistingChildren;

  /// 是否在挂载时自动聚焦标题（全屏页等默认为 true；底部弹窗等由容器在
  /// 入场动画完成后受控聚焦，避免动画与软键盘弹起冲突导致上跳）。
  final bool autofocus;

  /// 编辑态 ⋯ 菜单「删除」回调（容器执行确认 + 级联删除，D4）。
  final VoidCallback? onDeleteRequested;

  @override
  ConsumerState<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<TaskEditor> {
  /// 外部同步：loadTask / resetForNew 完成后把表单值同步进本地控制器。
  void _syncControllers(TaskFormState formState) {
    if (widget.controller.titleController.text != formState.title) {
      widget.controller.titleController.text = formState.title;
    }
    if (widget.controller.descriptionController.text != formState.description) {
      widget.controller.descriptionController.text = formState.description;
    }
    if (widget.controller.notesController.text != formState.notes) {
      widget.controller.notesController.text = formState.notes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasParent = ref.watch(
      taskFormProvider.select((s) => s.parentId != null),
    );
    ref.listen(taskFormProvider, (previous, next) => _syncControllers(next));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showTopBar) ...[
          _buildTopBar(context, l10n),
          const SizedBox(height: AppTokens.spaceXs),
        ],
        // 父任务只读展示（parentId 非空，59 §5.3 按空间取舍保留信息行）。
        if (hasParent) ...[
          const _ParentTaskSection(),
          const SizedBox(height: AppTokens.spaceSm),
        ],
        // ① 任务标题：大号加粗（titleLarge）、无边框、自动聚焦。
        _buildTitleField(context, l10n),
        // ② 描述：默认内联展示（59 讨论定稿，替代 ⋯ 菜单开关）；备注仍由 ⋯ 菜单开关（D8）。
        const SizedBox(height: AppTokens.spaceSm),
        TaskDescriptionNotesSection(controller: widget.controller),
        // ②.5 日期展示行：form 驱动实时展示，纯展示无交互
        const TaskDateDisplay(),
        // ②.6 已选标签 chips：form 驱动实时预览，纯展示无交互
        const TaskSelectedTagChips(),
        // ③ 子任务列表（仅 1 级任务展示）。
        if (widget.showSubtasks)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppTokens.spaceXs),
              _buildSubtasks(context, l10n),
            ],
          ),
        // 底部工具栏（常驻，替代原选项行，D5）。
        if (widget.showToolbar) ...[
          const SizedBox(height: AppTokens.spaceXs),
          ValueListenableBuilder<bool>(
            valueListenable: widget.controller.hasPendingNewSubtasksNotifier,
            builder: (context, hasPending, _) {
              return TaskEditorToolbar(
                statusDisabled: widget.hasExistingChildren || hasPending,
              );
            },
          ),
        ],
      ],
    );
  }

  // ── 顶部栏：项目切换 + ⋯ 菜单 ─────────────────────────────────────

  Widget _buildTopBar(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        const TaskProjectSwitcher(),
        const Spacer(),
        TaskEditorMenuButton(
          controller: widget.controller,
          onDeleteRequested: widget.onDeleteRequested,
        ),
      ],
    );
  }

  // ── 标题输入（无边框，自动聚焦）──────────────────────────────────

  Widget _buildTitleField(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return TextField(
      controller: widget.controller.titleController,
      focusNode: widget.controller.titleFocusNode,
      autofocus: widget.autofocus,
      scrollPadding: EdgeInsets.zero,
      // 长标题自动换行（用户要求）：maxLines: null = 不限行数，随输入自动
      // 增高；键盘回车由平台改为换行（单行 next 动作失效，无 textInputAction）。
      maxLines: null,
      // 规格：18 / w600（titleLarge = textTitleSize / textTitleWeight）。
      style: theme.textTheme.titleLarge,
      decoration: InputDecoration(
        hintText: l10n.taskTitle,
        border: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: (v) => ref.read(taskFormProvider.notifier).updateTitle(v),
    );
  }

  // ── 子任务区（圆形复选框 + 拖拽排序 + 新增行）───────────────────

  Widget _buildSubtasks(BuildContext context, AppLocalizations l10n) {
    return SubtaskList(
      controller: widget.controller,
      onAddSubtaskAndFocus: _addSubtaskAndFocus,
      onConfirmRemoveSubtask: _confirmRemoveSubtask,
    );
  }

  /// 添加子任务行并聚焦新行输入框（用户要求：点击/回车后光标直接落在新行，
  /// 等待输入子任务标题）。首帧后聚焦：新行 TextField 需先完成 build 挂载
  /// FocusNode。addSubtask 恒追加到末尾，rows.last 即新行。
  void _addSubtaskAndFocus() {
    widget.controller.addSubtask();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rows = widget.controller.subtaskRows;
      if (rows.isNotEmpty) rows.last.focusNode.requestFocus();
    });
  }

  /// 删除子任务行：新建行直接移除；现有行带确认弹窗（级联硬删）。
  Future<void> _confirmRemoveSubtask(SubtaskRow row) async {
    if (row.isNew) {
      widget.controller.removeSubtask(row);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = row.controller.text.trim().isEmpty
        ? l10n.subtasks
        : row.controller.text.trim();
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.deleteTask,
      message: '${l10n.deleteTaskConfirm(title)}\n${l10n.deleteTaskWarning}',
      confirmLabel: l10n.delete,
      confirmColor: theme.colorScheme.error,
    );
    if (confirmed && mounted) {
      widget.controller.removeSubtask(row);
    }
  }
}

/// ⋯ 菜单：备注开关；编辑态含删除（D4/D8）。描述默认内联展示，无需开关。
class TaskEditorMenuButton extends StatelessWidget {
  const TaskEditorMenuButton({
    super.key,
    required this.controller,
    this.onDeleteRequested,
  });

  final TaskEditorController controller;
  final VoidCallback? onDeleteRequested;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      tooltip: l10n.rowActions,
      onSelected: (value) {
        switch (value) {
          case 'notes':
            controller.toggleNotes();
          case 'delete':
            onDeleteRequested?.call();
        }
      },
      itemBuilder: (context) => [
        AppMenuItem(value: 'notes', label: l10n.taskNotes),
        if (onDeleteRequested != null)
          AppMenuItem(value: 'delete', label: l10n.delete, destructive: true),
      ],
    );
  }
}

/// 父任务行外层容器（细粒度订阅 parentId）。
class _ParentTaskSection extends ConsumerWidget {
  const _ParentTaskSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentId = ref.watch(taskFormProvider.select((s) => s.parentId));
    if (parentId == null) return const SizedBox.shrink();
    return _ParentTaskRow(parentId: parentId);
  }
}

/// 父任务只读行。
class _ParentTaskRow extends ConsumerWidget {
  const _ParentTaskRow({required this.parentId});

  final String parentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tasks = ref.watch(allActiveTasksProvider).value ?? const <Task>[];
    final parent = tasks.where((t) => t.id == parentId).firstOrNull;

    return Row(
      children: [
        Icon(
          Icons.subdirectory_arrow_right,
          size: 18,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(width: AppTokens.spaceXs),
        Text(
          l10n.taskParent,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: AppTokens.spaceXs),
        Expanded(
          child: Text(
            parent?.title ?? parentId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
