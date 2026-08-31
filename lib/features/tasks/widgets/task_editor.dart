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

import 'package:intl/intl.dart' as intl;

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/priority_color.dart';
import '../../../core/utils/dates.dart';
import '../../../shared/widgets/app_menu_item.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../projects/project_providers.dart';
import '../../tags/tag_providers.dart';
import '../task_providers.dart';
import 'priority_picker.dart';
import 'task_editor/project_picker_sheet.dart';
import 'task_editor/subtask_list.dart';
import 'task_editor/tag_picker_sheet.dart';
import 'task_editor/task_date_picker_dialogs.dart';
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
    this.isDetailsPage = false,
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

  /// 是否是任务详情编辑页面模式（以显示详细元数据行和底部的删除任务/已同步信息）
  final bool isDetailsPage;

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasParent = ref.watch(
      taskFormProvider.select((s) => s.parentId != null),
    );
    ref.listen(taskFormProvider, (previous, next) => _syncControllers(next));

    final projectId = ref.watch(taskFormProvider.select((s) => s.projectId));
    final projects = ref.watch(projectsStreamProvider).value ?? const <Project>[];
    final project = projects.where((p) => p.id == projectId).firstOrNull;

    if (widget.isDetailsPage) {
      final startAt = ref.watch(taskFormProvider.select((s) => s.startAt));
      final endAt = ref.watch(taskFormProvider.select((s) => s.endAt));
      final priority = ref.watch(taskFormProvider.select((s) => s.priority));
      final selectedTagIds = ref.watch(taskFormProvider.select((s) => s.selectedTagIds));
      final tags = ref.watch(tagsStreamProvider).value ?? const <Tag>[];
      final selectedTags = [
        for (final id in selectedTagIds)
          if (tags.any((t) => t.id == id)) tags.firstWhere((t) => t.id == id),
      ];

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top project capsule chip
          if (project != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(project.color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Color(project.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      project.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Color(project.color),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Title Input Field
          _buildTitleField(context, l10n),
          const SizedBox(height: 12),
          
          // Description Input Field
          TaskDescriptionNotesSection(controller: widget.controller),
          const SizedBox(height: 16),
          
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 8),
          
          // Details rows
          _DetailsRow(
            icon: Icons.calendar_today_outlined,
            label: '日期',
            value: Text(
              startAt != null || endAt != null ? formatDateRange(startAt, endAt, l10n) : '未设置',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: startAt != null || endAt != null
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            onTap: () => showTaskDatePicker(context, ref),
          ),
          
          _DetailsRow(
            icon: Icons.flag_outlined,
            label: '优先级',
            value: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (priority != TaskPriority.none)
                  Icon(Icons.flag, size: 16, color: priorityColor(priority)),
                if (priority != TaskPriority.none)
                  const SizedBox(width: 4),
                Text(
                  priorityLabel(l10n, priority),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: priority != TaskPriority.none
                        ? priorityColor(priority)
                        : colorScheme.onSurfaceVariant,
                    fontWeight: priority != TaskPriority.none ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            onTap: () => showTaskPriorityPicker(context, ref),
          ),
          
          _DetailsRow(
            icon: Icons.folder_outlined,
            label: '项目',
            value: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (project != null)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Color(project.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (project != null)
                  const SizedBox(width: 6),
                Text(
                  project?.name ?? '无',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            onTap: () => showTaskProjectPicker(context, ref),
          ),
          
          _DetailsRow(
            icon: Icons.label_outline,
            label: '标签',
            value: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedTags.isEmpty)
                  Text(
                    '无',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  Wrap(
                    spacing: 4,
                    children: [
                      for (final tag in selectedTags)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(tag.color).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Color(tag.color).withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            tag.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Color(tag.color),
                              fontSize: 11,
                            ),
                          ),
                        )
                    ],
                  )
              ],
            ),
            onTap: () => showTaskTagPicker(context, ref),
          ),
          
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 16),
          
          // Subtasks
          if (widget.showSubtasks) ...[
            Text(
              '子任务',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildSubtasks(context, l10n),
            const SizedBox(height: 24),
          ],
          
          // Delete button & Sync metadata centered at the bottom of the scroll view
          if (widget.onDeleteRequested != null) ...[
            Center(
              child: TextButton(
                onPressed: widget.onDeleteRequested,
                child: Text(
                  '删除任务',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          if (ref.watch(taskFormProvider.select((s) => s.id)) != null)
            Center(
              child: TaskMetadataFooter(
                taskId: ref.read(taskFormProvider).id!,
              ),
            ),
        ],
      );
    }

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

class _DetailsRow extends StatelessWidget {
  const _DetailsRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            value,
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskMetadataFooter extends ConsumerWidget {
  const TaskMetadataFooter({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(allActiveTasksProvider).value ?? const <Task>[];
    final task = tasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final date = DateTime.fromMillisecondsSinceEpoch(task.createdAt, isUtc: true).toLocal();
    final isZh = l10n.localeName.startsWith('zh');
    final formattedDate = isZh
        ? intl.DateFormat('M月d日').format(date)
        : intl.DateFormat('MMM d').format(date);

    return Text(
      '创建于 $formattedDate · 已同步',
      style: theme.textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        fontSize: 12,
      ),
    );
  }
}
