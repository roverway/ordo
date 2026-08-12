// 统一任务编辑器（59-task-editor-optimization.md §5.1 定稿，D1–D9）。
//
// 新建底部弹窗（TaskCreateSheet）与编辑全屏页（TaskEditPage）共用同一编辑器，
// **仅呈现容器不同**（弹出式 60–65% 高 / 全屏式 AppBar）：
//
//   顶部栏：[项目图标] 项目名 [下拉双箭头]      [⋯ 三点菜单]
//   内容区：① 任务标题（titleLarge，无边框，自动聚焦）
//           ② 描述/备注：⋯ 菜单开关后内联展开（默认隐藏，D8/D9）
//           ③ 子任务列表：○ 圆形复选框 + 文字 + ≡ 拖拽 + 删除按钮
//   底部工具栏：[日期] [状态] [标签] [优先级] [附件占位禁用]（D5/D6/D7）
//
// 职责边界：编辑器只负责**表单字段**（经 taskFormProvider 读写）与**子任务 UI 状态**
// （经 [TaskEditorController] 暴露）；保存/自动保存/子任务落库由容器执行。
//
// - 日期（D6）：工具栏单「日期」图标 → 弹层内分设开始/截止 → 预设（今天/明天/下周/
//   自定义/清除）+ 自定义日期时间选择。
// - 状态（D7）：弹层选 4 状态；有子任务时禁用 + Tooltip 派生提示（AGENTS.md §3-2）。
// - 标签：药丸多选 + 新建；优先级：复用 showPriorityPicker。
// - 附件（D5）：占位禁用图标 + Tooltip「即将推出」（v1 数据模型无附件字段）。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/todo_repository.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../projects/project_providers.dart';
import '../../projects/widgets/project_form_dialog.dart';
import '../../tags/tag_providers.dart';
import '../../tags/tags_page.dart' show showTagFormDialog;
import '../task_providers.dart';
import 'priority_picker.dart';

/// 编辑器模式：新建（create）无删除、子任务仅新增行；编辑（edit）⋯ 菜单含删除、
/// 子任务支持管理现有行。
enum TaskEditorMode { create, edit }

/// 子任务行（编辑器内部 UI 状态；id 为空表示新建行）。
class SubtaskRow {
  SubtaskRow.newRow()
    : id = null,
      status = TaskStatus.todo,
      controller = TextEditingController();

  SubtaskRow.existing(Task task)
    : id = task.id,
      status = task.status,
      controller = TextEditingController(text: task.title);

  /// 已存在子任务的 id；null = 新建行。
  final String? id;

  /// 现有子任务状态（仅用于装饰性复选框展示；新建行恒为 todo）。
  final TaskStatus status;

  final TextEditingController controller;

  bool get isNew => id == null;
}

/// 任务编辑器共享控制器（容器持有）。
///
/// - 表单字段：编辑器内部经 taskFormProvider 双向桥接，容器无需直接访问；
/// - 子任务：容器通过 [subtaskRows] / [removedSubtaskIds] 在保存时统一落库。
class TaskEditorController extends ChangeNotifier {
  TaskEditorController({required this.mode});

  final TaskEditorMode mode;

  /// 表单文本控制器（编辑器 ↔ taskFormProvider 的双向桥）。
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  /// 描述/备注显示开关（⋯ 菜单控制，默认隐藏，D8/D9）。
  bool showDescription = false;
  bool showNotes = false;

  /// 子任务行（列表顺序即最终排序顺序）。
  final List<SubtaskRow> subtaskRows = [];

  /// 编辑模式：已从界面移除、待保存时级联删除的现有子任务 id。
  final List<String> removedSubtaskIds = [];

  // 编辑模式初始快照（用于判定子任务是否有改动）。
  List<String?> _originalOrder = const [];
  Map<String, String> _originalTitles = const {};

  /// 用已存在的子任务初始化（编辑模式加载完成后调用；创建模式无需调用）。
  void initializeSubtasks(List<Task> existing) {
    subtaskRows
      ..clear()
      ..addAll(existing.map(SubtaskRow.existing));
    removedSubtaskIds.clear();
    _originalOrder = subtaskRows.map((r) => r.id).toList();
    _originalTitles = {for (final t in existing) t.id: t.title};
    notifyListeners();
  }

  /// 编辑模式：子任务相对初始快照是否有改动（新增/删除/改标题/排序）。
  bool get hasSubtaskChanges {
    if (removedSubtaskIds.isNotEmpty) return true;
    final currentIds = subtaskRows.map((r) => r.id).toList();
    if (!listEquals(currentIds, _originalOrder)) return true;
    for (final row in subtaskRows) {
      final title = row.controller.text.trim();
      if (row.isNew) {
        if (title.isNotEmpty) return true;
      } else if (title != _originalTitles[row.id]) {
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

  /// 保存成功后重设子任务快照：清空删除标记并重拍原始顺序/标题，
  /// 使 [hasSubtaskChanges] 归 false（保存后离开不再误弹「未保存」提示，59 评审 Bug 1）。
  void markSubtasksSaved() {
    removedSubtaskIds.clear();
    _originalOrder = subtaskRows.map((r) => r.id).toList();
    _originalTitles = {
      for (final row in subtaskRows)
        if (row.id != null) row.id!: row.controller.text.trim(),
    };
    notifyListeners();
  }

  void toggleDescription() {
    showDescription = !showDescription;
    notifyListeners();
  }

  void toggleNotes() {
    showNotes = !showNotes;
    notifyListeners();
  }

  void addSubtask() {
    subtaskRows.add(SubtaskRow.newRow());
    notifyListeners();
  }

  /// 移除子任务行：现有行记入 [removedSubtaskIds]（保存时级联删除）。
  void removeSubtask(SubtaskRow row) {
    if (row.id != null) removedSubtaskIds.add(row.id!);
    subtaskRows.remove(row);
    row.controller.dispose();
    notifyListeners();
  }

  void reorderSubtasks(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final row = subtaskRows.removeAt(oldIndex);
    subtaskRows.insert(newIndex, row);
    notifyListeners();
  }

  /// 子任务输入变化通知（状态派生禁用实时依据，D7）。
  void notifySubtasksChanged() => notifyListeners();

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    notesController.dispose();
    for (final row in subtaskRows) {
      row.controller.dispose();
    }
    super.dispose();
  }
}

/// 统一任务编辑器（共享内容区 + 顶部栏 + 底部工具栏）。
class TaskEditor extends ConsumerStatefulWidget {
  const TaskEditor({
    super.key,
    required this.controller,
    this.showTopBar = true,
    this.showToolbar = true,
    this.showSubtasks = true,
    this.hasExistingChildren = false,
    this.onDeleteRequested,
  });

  /// 编辑器共享控制器（容器持有并负责 dispose）。
  final TaskEditorController controller;

  /// 是否展示顶部栏（编辑全屏页的 AppBar 已含项目切换 + ⋯ 菜单，传 false，59 §5.3）。
  final bool showTopBar;

  /// 是否在内容区末尾渲染底部工具栏（编辑全屏页改为 bottomNavigationBar 常驻，传 false）。
  final bool showToolbar;

  /// 是否展示子任务区（新建子任务 / 编辑有父任务的任务时传 false，仅 1 级任务展示）。
  final bool showSubtasks;

  /// 任务当前在 DB 中是否已有子任务（状态派生禁用的静态依据）。
  final bool hasExistingChildren;

  /// 编辑态 ⋯ 菜单「删除」回调（容器执行确认 + 级联删除，D4）。
  final VoidCallback? onDeleteRequested;

  @override
  ConsumerState<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<TaskEditor> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

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

  /// 状态禁用：已有子任务或待保存的新建子任务行（状态由子任务派生，AGENTS.md §3-2）。
  bool get _statusDisabled =>
      widget.hasExistingChildren || widget.controller.hasPendingNewSubtasks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formState = ref.watch(taskFormProvider);
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
        if (formState.parentId != null) ...[
          _ParentTaskRow(parentId: formState.parentId!),
          const SizedBox(height: AppTokens.spaceSm),
        ],
        // ① 任务标题：大号加粗（titleLarge）、无边框、自动聚焦。
        _buildTitleField(context, l10n),
        // ② 描述/备注：⋯ 菜单开关后内联展开（默认隐藏，D8/D9）。
        if (widget.controller.showDescription ||
            widget.controller.showNotes) ...[
          const SizedBox(height: AppTokens.spaceSm),
          _buildDescriptionNotes(context, l10n),
        ],
        // ③ 子任务列表（仅 1 级任务展示）。
        if (widget.showSubtasks) ...[
          const SizedBox(height: AppTokens.spaceXs),
          _buildSubtasks(context, l10n),
        ],
        // 底部工具栏（常驻，替代原选项行，D5）。
        if (widget.showToolbar) ...[
          const SizedBox(height: AppTokens.spaceXs),
          TaskEditorToolbar(statusDisabled: _statusDisabled),
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
      autofocus: true,
      // 规格：18 / w600（titleLarge = textTitleSize / textTitleWeight）。
      style: theme.textTheme.titleLarge,
      decoration: InputDecoration(
        hintText: l10n.taskTitle,
        border: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      textInputAction: TextInputAction.next,
      onChanged: (v) => ref.read(taskFormProvider.notifier).updateTitle(v),
    );
  }

  // ── 描述/备注（⋯ 菜单开关）───────────────────────────────────────

  Widget _buildDescriptionNotes(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        if (widget.controller.showDescription)
          TextField(
            controller: widget.controller.descriptionController,
            maxLines: 3,
            decoration: InputDecoration(labelText: l10n.taskDescription),
            onChanged: (v) =>
                ref.read(taskFormProvider.notifier).updateDescription(v),
          ),
        if (widget.controller.showNotes) ...[
          const SizedBox(height: AppTokens.spaceSm),
          TextField(
            controller: widget.controller.notesController,
            maxLines: 2,
            decoration: InputDecoration(labelText: l10n.taskNotes),
            onChanged: (v) =>
                ref.read(taskFormProvider.notifier).updateNotes(v),
          ),
        ],
      ],
    );
  }

  // ── 子任务区（圆形复选框 + 拖拽排序 + 新增行）───────────────────

  Widget _buildSubtasks(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.subtasks,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (widget.controller.subtaskRows.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: widget.controller.subtaskRows.length,
            onReorder: widget.controller.reorderSubtasks,
            itemBuilder: (context, index) {
              final row = widget.controller.subtaskRows[index];
              return _SubtaskRowTile(
                key: ObjectKey(row.controller),
                index: index,
                row: row,
                onRemove: () => _confirmRemoveSubtask(row),
                onSubmitted: widget.controller.addSubtask,
                // 输入即通知（状态派生禁用实时依据，D7）。
                onChanged: widget.controller.notifySubtasksChanged,
              );
            },
          ),
        TextButton.icon(
          onPressed: widget.controller.addSubtask,
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.addSubtask),
        ),
      ],
    );
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

/// 底部工具栏：[日期] [状态] [标签] [优先级] [附件占位禁用]（D5/D6/D7）。
class TaskEditorToolbar extends ConsumerWidget {
  const TaskEditorToolbar({super.key, this.statusDisabled = false});

  /// 状态按钮是否禁用（有子任务时状态由子任务派生，AGENTS.md §3-2）。
  final bool statusDisabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final formState = ref.watch(taskFormProvider);

    final hasDate = formState.startAt != null || formState.endAt != null;
    final hasTags = formState.selectedTagIds.isNotEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ToolbarAction(
          tooltip: l10n.dateAndReminder,
          icon: Icons.calendar_today_outlined,
          active: hasDate,
          onTap: () => _pickDate(context, ref),
        ),
        _ToolbarAction(
          tooltip: statusDisabled
              ? l10n.statusDerivedFromChildren
              : _statusLabel(l10n, formState.status),
          icon: _statusIcon(formState.status),
          iconColor: _statusColor(formState.status),
          active: formState.status != TaskStatus.todo,
          enabled: !statusDisabled,
          onTap: statusDisabled ? null : () => _pickStatus(context, ref),
        ),
        _ToolbarAction(
          tooltip: l10n.taskTags,
          icon: Icons.label_outline,
          active: hasTags,
          onTap: () => _pickTags(context, ref),
        ),
        _ToolbarAction(
          tooltip: l10n.priority,
          icon: Icons.flag_outlined,
          iconColor: priorityColor(formState.priority),
          active: formState.priority != TaskPriority.none,
          onTap: () => _pickPriority(context, ref),
        ),
        // 附件占位（v1 数据模型无附件字段，D5）。
        _ToolbarAction(
          tooltip: l10n.attachmentComingSoon,
          icon: Icons.attach_file,
          enabled: false,
          onTap: null,
        ),
      ],
    );
  }
}

/// 顶部栏项目切换：[项目图标] 项目名 [下拉双箭头]（编辑中直接切换所属项目）。
class TaskProjectSwitcher extends ConsumerWidget {
  const TaskProjectSwitcher({super.key, this.interactive = true});

  /// 编辑已有任务时传 false：仅展示项目名（跨项目移动未实现，编辑态隐藏
  /// 误导性切换入口；新建态保留切换，59 讨论定稿）。
  final bool interactive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formState = ref.watch(taskFormProvider);
    final projects =
        ref.watch(projectsStreamProvider).value ?? const <Project>[];
    final project = projects
        .where((p) => p.id == formState.projectId)
        .firstOrNull;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 项目图标：彩色圆点（与清单选择器一致的设计语言）。
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: project != null
                ? Color(project.color)
                : AppTokens.colorCancelled,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppTokens.spaceXs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            project?.name ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: AppTokens.textTitleWeight,
            ),
          ),
        ),
        if (interactive) ...[
          const SizedBox(width: AppTokens.spaceXxs),
          Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ],
    );

    final padding = const EdgeInsets.symmetric(
      vertical: AppTokens.spaceXs,
      horizontal: AppTokens.spaceXxs,
    );
    if (!interactive) return Padding(padding: padding, child: content);

    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radiusButton),
      onTap: () => _pickProject(context, ref),
      child: Padding(padding: padding, child: content),
    );
  }

  /// 「移动到」清单选择：搜索 + 列表（当前项对勾）+ 添加项目。
  Future<void> _pickProject(BuildContext context, WidgetRef ref) async {
    final formState = ref.read(taskFormProvider);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusDialog),
        ),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: _ProjectPickerSheet(currentProjectId: formState.projectId ?? ''),
      ),
    );
    if (result != null && context.mounted) {
      // 父任务不能跨项目：切换项目时清空 parentId（与编辑页一致）。
      ref.read(taskFormProvider.notifier).setProjectAndParent(result, null);
    }
  }
}

/// ⋯ 菜单：描述/备注开关；编辑态含删除（D4/D8/D9）。
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
          case 'description':
            controller.toggleDescription();
          case 'notes':
            controller.toggleNotes();
          case 'delete':
            onDeleteRequested?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'description', child: Text(l10n.taskDescription)),
        PopupMenuItem(value: 'notes', child: Text(l10n.taskNotes)),
        if (onDeleteRequested != null)
          PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
      ],
    );
  }
}

// ── 子任务行 ──────────────────────────────────────────────────────────

class _SubtaskRowTile extends StatelessWidget {
  const _SubtaskRowTile({
    super.key,
    required this.index,
    required this.row,
    required this.onRemove,
    required this.onSubmitted,
    required this.onChanged,
  });

  final int index;
  final SubtaskRow row;
  final VoidCallback onRemove;
  final VoidCallback onSubmitted;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        // 圆形复选框（装饰：展示任务状态，新建行默认未完成）。
        SizedBox(
          width: AppTokens.touchTarget,
          height: AppTokens.touchTarget,
          child: Checkbox(
            value: row.status == TaskStatus.done,
            onChanged: null,
          ),
        ),
        Expanded(
          child: TextField(
            controller: row.controller,
            decoration: InputDecoration(
              hintText: l10n.subtaskHint,
              border: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onSubmitted: (_) => onSubmitted(),
            onChanged: (_) => onChanged(),
          ),
        ),
        // 拖拽排序把手。
        ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.all(AppTokens.spaceXs),
            child: Icon(Icons.drag_handle, size: 18),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          visualDensity: VisualDensity.compact,
          onPressed: onRemove,
        ),
      ],
    );
  }
}

// ── 父任务只读行 ──────────────────────────────────────────────────────

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

// ── 工具栏动作项 ──────────────────────────────────────────────────────

class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({
    required this.tooltip,
    required this.icon,
    this.active = false,
    this.enabled = true,
    this.iconColor,
    this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final bool enabled;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        iconColor ??
        (active
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant);
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20, color: color),
        onPressed: enabled ? onTap : null,
      ),
    );
  }
}

// ── 各选项弹层交互 ────────────────────────────────────────────────────

/// 状态图标（工具栏 + 状态弹层共用）。
IconData _statusIcon(TaskStatus status) => switch (status) {
  TaskStatus.todo => Icons.radio_button_unchecked,
  TaskStatus.inProgress => Icons.circle,
  TaskStatus.done => Icons.check_circle,
  TaskStatus.cancelled => Icons.cancel_outlined,
};

/// 状态颜色（工具栏 + 状态弹层共用）。
Color _statusColor(TaskStatus status) => switch (status) {
  TaskStatus.todo => AppTokens.colorCancelled,
  TaskStatus.inProgress => AppTokens.colorInProgress,
  TaskStatus.done => AppTokens.colorDone,
  TaskStatus.cancelled => AppTokens.colorCancelled,
};

/// 状态本地化名称。
String _statusLabel(AppLocalizations l10n, TaskStatus status) =>
    switch (status) {
      TaskStatus.todo => l10n.statusTodo,
      TaskStatus.inProgress => l10n.statusInProgress,
      TaskStatus.done => l10n.statusDone,
      TaskStatus.cancelled => l10n.statusCancelled,
    };

/// 日期弹层（D6）：单「日期」图标 → 弹层内分设开始/截止两个入口。
Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final formState = ref.read(taskFormProvider);

  final field = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusDialog),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppTokens.spaceXs),
          ListTile(
            title: Text(
              l10n.dateAndReminder,
              style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                fontWeight: AppTokens.textTitleWeight,
              ),
            ),
          ),
          const Divider(),
          _dateFieldTile(
            sheetContext,
            label: l10n.taskStartTime,
            valueText: formState.startAt != null
                ? formatDueDate(formState.startAt!, l10n)
                : l10n.noStartTime,
            onTap: () => Navigator.of(sheetContext).pop('start'),
          ),
          _dateFieldTile(
            sheetContext,
            label: l10n.taskEndTime,
            valueText: formState.endAt != null
                ? formatDueDate(formState.endAt!, l10n)
                : l10n.noDueDate,
            onTap: () => Navigator.of(sheetContext).pop('end'),
          ),
          const SizedBox(height: AppTokens.spaceXs),
        ],
      ),
    ),
  );
  if (field == null || !context.mounted) return;
  await _pickDueDatePreset(context, ref, isStart: field == 'start');
}

Widget _dateFieldTile(
  BuildContext context, {
  required String label,
  required String valueText,
  required VoidCallback onTap,
}) {
  final theme = Theme.of(context);
  return ListTile(
    leading: const Icon(Icons.event_outlined, size: 20),
    title: Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
    subtitle: Text(valueText, style: theme.textTheme.bodyLarge),
    trailing: const Icon(Icons.chevron_right, size: 18),
    onTap: onTap,
  );
}

/// 日期预设弹层（今天/明天/下周/自定义/清除，D6；写入开始或截止）。
Future<void> _pickDueDatePreset(
  BuildContext context,
  WidgetRef ref, {
  required bool isStart,
}) async {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final choice = await showModalBottomSheet<_DueDateChoice>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusDialog),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppTokens.spaceXs),
          ListTile(
            title: Text(
              isStart ? l10n.taskStartTime : l10n.taskEndTime,
              style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                fontWeight: AppTokens.textTitleWeight,
              ),
            ),
          ),
          const Divider(),
          for (final c in _DueDateChoice.values)
            ListTile(
              title: Text(_dueDateChoiceLabel(l10n, c)),
              onTap: () => Navigator.of(sheetContext).pop(c),
            ),
          const SizedBox(height: AppTokens.spaceXs),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  final notifier = ref.read(taskFormProvider.notifier);
  switch (choice) {
    case _DueDateChoice.clear:
      if (isStart) {
        notifier.updateStartAt(null);
      } else {
        notifier.updateEndAt(null);
      }
    case _DueDateChoice.custom:
      await _pickCustomDateTime(context, notifier, isStart: isStart);
    case _DueDateChoice.today:
    case _DueDateChoice.tomorrow:
    case _DueDateChoice.nextWeek:
      final now = DateTime.now();
      final base = switch (choice) {
        _DueDateChoice.today => now,
        _DueDateChoice.tomorrow => now.add(const Duration(days: 1)),
        _DueDateChoice.nextWeek => _nextMonday(now),
        _ => now,
      };
      final ms = _dateOnlyMs(base);
      if (isStart) {
        notifier.updateStartAt(ms);
      } else {
        notifier.updateEndAt(ms);
      }
  }
}

/// 自定义日期 + 时间选择（复用编辑页 showDatePicker + showTimePicker 逻辑）。
Future<void> _pickCustomDateTime(
  BuildContext context,
  TaskFormNotifier notifier, {
  required bool isStart,
}) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: now,
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
  );
  if (date == null || !context.mounted) return;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(now),
  );
  if (time == null || !context.mounted) return;
  final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
  final ms = dt.toUtc().millisecondsSinceEpoch;
  if (isStart) {
    notifier.updateStartAt(ms);
  } else {
    notifier.updateEndAt(ms);
  }
}

/// 状态弹层：4 状态（todo/inProgress/done/cancelled），当前项蓝色对勾。
Future<void> _pickStatus(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final current = ref.read(taskFormProvider).status;
  final picked = await showModalBottomSheet<TaskStatus>(
    context: context,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusDialog),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppTokens.spaceXs),
          ListTile(
            title: Text(
              l10n.taskStatus,
              style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                fontWeight: AppTokens.textTitleWeight,
              ),
            ),
          ),
          const Divider(),
          for (final s in TaskStatus.values)
            ListTile(
              leading: Icon(_statusIcon(s), size: 20, color: _statusColor(s)),
              title: Text(_statusLabel(l10n, s)),
              trailing: s == current
                  ? const Icon(
                      Icons.check,
                      size: 20,
                      color: AppTokens.colorInProgress,
                    )
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(s),
            ),
          const SizedBox(height: AppTokens.spaceXs),
        ],
      ),
    ),
  );
  if (picked != null && context.mounted) {
    ref.read(taskFormProvider.notifier).updateStatus(picked);
  }
}

/// 标签弹层：药丸多选 + 新建（完成后整体写回表单）。
Future<void> _pickTags(BuildContext context, WidgetRef ref) async {
  final formState = ref.read(taskFormProvider);
  final result = await showModalBottomSheet<List<String>>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusDialog),
      ),
    ),
    builder: (sheetContext) =>
        _TagPickerSheet(initialSelected: formState.selectedTagIds),
  );
  if (result != null && context.mounted) {
    ref.read(taskFormProvider.notifier).setSelectedTags(result);
  }
}

/// 优先级弹层（滴答式 红/橙/蓝/无，复用 priority_picker）。
Future<void> _pickPriority(BuildContext context, WidgetRef ref) async {
  final formState = ref.read(taskFormProvider);
  final picked = await showPriorityPicker(context, current: formState.priority);
  if (picked != null && context.mounted) {
    ref.read(taskFormProvider.notifier).updatePriority(picked);
  }
}

// ── 小工具 ───────────────────────────────────────────────────────────

/// 日期型时间的 09:00 约定（与日历「点日期新建」一致，UTC 毫秒）。
int _dateOnlyMs(DateTime day) =>
    DateTime(day.year, day.month, day.day, 9).toUtc().millisecondsSinceEpoch;

/// 下一个周一（今天为周一时取下周）。
DateTime _nextMonday(DateTime today) {
  final days = (8 - today.weekday) % 7;
  return today.add(Duration(days: days == 0 ? 7 : days));
}

/// 日期预设选项。
enum _DueDateChoice { today, tomorrow, nextWeek, custom, clear }

String _dueDateChoiceLabel(AppLocalizations l10n, _DueDateChoice choice) =>
    switch (choice) {
      _DueDateChoice.today => l10n.today,
      _DueDateChoice.tomorrow => l10n.tomorrow,
      _DueDateChoice.nextWeek => l10n.nextWeek,
      _DueDateChoice.custom => l10n.custom,
      _DueDateChoice.clear => l10n.clear,
    };

/// 「移动到」清单选择弹层：搜索框 + 清单列表（当前项对勾）+ 添加项目。
class _ProjectPickerSheet extends ConsumerStatefulWidget {
  const _ProjectPickerSheet({required this.currentProjectId});

  final String currentProjectId;

  @override
  ConsumerState<_ProjectPickerSheet> createState() =>
      _ProjectPickerSheetState();
}

class _ProjectPickerSheetState extends ConsumerState<_ProjectPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final projects =
        ref.watch(projectsStreamProvider).value ?? const <Project>[];
    final filtered = projects
        .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    l10n.moveTo,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: AppTokens.textTitleWeight,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceMd),
              ],
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Row(
              children: [
                const SizedBox(width: AppTokens.spaceSm),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: l10n.searchProjects,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceSm),
              ],
            ),
            const SizedBox(height: AppTokens.spaceXs),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final project = filtered[index];
                  final isCurrent = project.id == widget.currentProjectId;
                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Color(project.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isCurrent
                        ? const Icon(
                            Icons.check,
                            size: 20,
                            color: AppTokens.colorInProgress,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(project.id),
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              dense: true,
              leading: const Icon(Icons.add, size: 20),
              title: Text(l10n.addProject),
              onTap: _createProject,
            ),
            const SizedBox(height: AppTokens.spaceXs),
          ],
        ),
      ),
    );
  }

  /// 「+ 添加项目」：复用项目表单弹窗，创建后自动选中。
  Future<void> _createProject() async {
    final data = await showProjectFormDialog(context: context);
    if (data == null || !mounted) return;
    final repo = ref.read(todoRepositoryProvider);
    final project = await repo.createProject(
      name: data.name,
      color: data.color,
      description: data.description,
    );
    if (!mounted) return;
    Navigator.of(context).pop(project.id);
  }
}

/// 标签弹层：药丸多选 + 新建标签（完成后整体写回表单）。
class _TagPickerSheet extends ConsumerStatefulWidget {
  const _TagPickerSheet({required this.initialSelected});

  final List<String> initialSelected;

  @override
  ConsumerState<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<_TagPickerSheet> {
  late final Set<String> _selected = {...widget.initialSelected};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tags = ref.watch(tagsStreamProvider).value ?? const <Tag>[];

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    l10n.taskTags,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: AppTokens.textTitleWeight,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_selected.toList()),
                  child: Text(l10n.done),
                ),
              ],
            ),
            const Divider(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceMd,
                  vertical: AppTokens.spaceXs,
                ),
                child: Wrap(
                  spacing: AppTokens.spaceXs,
                  runSpacing: AppTokens.spaceXs,
                  children: tags.map((tag) {
                    final isSelected = _selected.contains(tag.id);
                    return FilterChip(
                      label: Text(tag.name),
                      selected: isSelected,
                      onSelected: (_) => setState(() {
                        if (isSelected) {
                          _selected.remove(tag.id);
                        } else {
                          _selected.add(tag.id);
                        }
                      }),
                      avatar: isSelected
                          ? null
                          : Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Color(tag.color),
                                shape: BoxShape.circle,
                              ),
                            ),
                      selectedColor: Color(tag.color).withValues(alpha: 0.15),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),
            ),
            const Divider(),
            ListTile(
              dense: true,
              leading: const Icon(Icons.add, size: 20),
              title: Text(l10n.newTag),
              onTap: _createTag,
            ),
            const SizedBox(height: AppTokens.spaceXs),
          ],
        ),
      ),
    );
  }

  /// 新建标签（复用 tags_page 的表单弹窗，重名预检走 ARB 文案）。
  Future<void> _createTag() async {
    final data = await showTagFormDialog(context: context);
    if (data == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(todoRepositoryProvider);
    final existing = await repo.tags.getByName(data.name);
    if (existing != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.tagNameDuplicate)));
      return;
    }
    try {
      final tag = await repo.createTag(name: data.name, color: data.color);
      if (!mounted) return;
      setState(() => _selected.add(tag.id));
    } on RepositoryException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
