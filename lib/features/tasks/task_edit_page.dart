// 任务编辑全屏页（59-task-editor-optimization.md §5.3 定稿）。
//
// 全屏容器：AppBar（返回 + 项目名 + 保存按钮 + ⋯ 菜单；新建态项目名带下拉箭头可切换，
// 编辑态只读展示）+ 共享编辑器 [TaskEditor]（showTopBar/showToolbar 均关，工具栏由本页
// 在 body 内钉底渲染并随键盘上移）。
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
import '../../core/utils/app_breakpoints.dart';
import '../../core/utils/tree.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/modal_side_sheet.dart';
import '../projects/project_providers.dart';
import 'task_providers.dart';
import 'widgets/task_editor.dart';

/// 宽屏（≥600dp）弹出右侧透明模态抽屉（Side Sheet）。
Future<void> showTaskEditSideSheet(
  BuildContext context, {
  String? taskId,
  String? projectId,
  String? parentId,
  int? initialStartAt,
  int? initialEndAt,
}) {
  return showModalSideSheet(
    context: context,
    width: AppTokens.sideSheetEditorWidth,
    child: TaskEditPage(
      taskId: taskId,
      projectId: projectId,
      parentId: parentId,
      initialStartAt: initialStartAt,
      initialEndAt: initialEndAt,
    ),
  );
}

/// 统一任务编辑/新建导航入口：
/// - 宽屏（≥600dp）：右侧浮动抽屉（Side Sheet，宽 [AppTokens.sideSheetEditorWidth]）
/// - 窄屏（<600dp）：全屏页面 push
void openTaskEdit(
  BuildContext context, {
  String? taskId,
  String? projectId,
  String? parentId,
  int? initialStartAt,
  int? initialEndAt,
}) {
  if (AppBreakpoints.isWide(context)) {
    showTaskEditSideSheet(
      context,
      taskId: taskId,
      projectId: projectId,
      parentId: parentId,
      initialStartAt: initialStartAt,
      initialEndAt: initialEndAt,
    );
  } else {
    if (taskId != null) {
      context.push('/task/$taskId');
    } else {
      final queryParams = <String, String>{};
      if (projectId != null) queryParams['projectId'] = projectId;
      if (parentId != null) queryParams['parentId'] = parentId;
      if (initialStartAt != null) {
        queryParams['startAt'] = initialStartAt.toString();
      }
      if (initialEndAt != null) {
        queryParams['endAt'] = initialEndAt.toString();
      }
      final uri = Uri(
        path: '/task/new',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      context.push(uri.toString());
    }
  }
}

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
  bool _isSaving = false;

  /// 编辑态子任务区是否展示（方案 B：自身深度 < 3 才可再创建子任务）。
  /// 加载完成前默认展示，避免「先隐藏后显示」闪烁（深度 3 的极深任务加载后隐藏）。
  bool _showSubtasks = true;

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
      // 方案 B（59 讨论定稿）：子任务区展示条件 = 被编辑任务自身深度 < 3
      // （3 级为最深，无法再创建子任务）。解决「有子任务的 2 级任务不显示子任务区」
      // 与 1 级任务显示不一致的问题（点击现有任务出现两种编辑器的根因）。
      final all = await repo.tasks.getAllByProject(loadedState.projectId!);
      final byId = indexTasksById(all);
      final taskEntry = byId[widget.taskId!];
      final depth = taskEntry != null ? depthOf(taskEntry, byId) : 1;
      if (mounted) {
        _editorController.initializeSubtasks(children);
        setState(() {
          _hasChildren = children.isNotEmpty;
          _showSubtasks = depth < 3;
        });
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

  void _doPop() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/today');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final formState = ref.watch(taskFormProvider);
    final isWide = AppBreakpoints.isWide(context);

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
            _doPop();
          }
        } else {
          _doPop();
        }
      },
      child: Scaffold(
        // 显式声明：body 高度会扣除键盘 inset（Scaffold contentBottom），
        // 底部工具栏随 body 上移，键盘弹出时不遮挡（59 修复）。
        resizeToAvoidBottomInset: true,
        // AppBar：返回 + 项目名（新建态带下拉箭头可切换，编辑态只读）+ 保存 + ⋯ 菜单。
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(isWide ? Icons.close : Icons.arrow_back_rounded),
            tooltip: isWide
                ? l10n.cancel
                : MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          titleSpacing: AppTokens.spaceXs,
          // 编辑已有任务：项目切换不落库（跨项目移动未实现），仅展示项目名；
          // 新建态保留切换入口（59 讨论定稿，消除误导）。
          title: TaskProjectSwitcher(interactive: !_isEditing),
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
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTokens.spaceMd),
                child: TaskEditor(
                  controller: _editorController,
                  showTopBar: false,
                  showToolbar: false,
                  // 编辑态：子任务区按自身深度（<3 展示，方案 B）；新建态维持「仅 1 级任务」。
                  showSubtasks: _isEditing
                      ? _showSubtasks
                      : formState.parentId == null,
                  hasExistingChildren: _hasChildren,
                  onDeleteRequested: _isEditing ? _confirmDeleteTask : null,
                ),
              ),
            ),
            // 底部工具栏常驻：作为 body 的一部分（body 高度已扣键盘 inset），
            // 键盘弹出时随 body 上移——不依赖窗口 resize（59 修复，弹窗同机制）。
            ListenableBuilder(
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
          ],
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
      // 任务已删除：重设子任务快照，避免返回被「未保存」拦截（59 评审 Bug 1）。
      _editorController.markSubtasksSaved();
      ref.read(taskFormProvider.notifier).reset();
      _doPop();
    } on RepositoryException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // ── 显式保存（D2）─────────────────────────────────────────────────

  Future<void> _save() async {
    if (_isSaving) return; // 防双击重复落库（59 评审 Bug 3）。
    _isSaving = true;
    try {
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
      if (!mounted) return;
      // 保存成功后重设子任务快照，使 hasSubtaskChanges 归 false，
      // 返回时不再误弹「未保存更改」对话框（59 评审 Bug 1）。
      _editorController.markSubtasksSaved();
      _doPop();
    } finally {
      _isSaving = false;
    }
  }

  /// 保存成功后统一执行子任务增删改排序（D3，同一事务原子同步）。
  Future<void> _syncSubtasks() async {
    final repo = ref.read(todoRepositoryProvider);
    final formState = ref.read(taskFormProvider);
    final parentId = formState.id;
    if (parentId == null) return;

    final rows = _editorController.subtaskRows;
    final items = [
      for (final row in rows) (id: row.id, title: row.controller.text.trim()),
    ];

    try {
      await repo.syncSubtasks(
        parentId: parentId,
        deleteSubtaskIds: List<String>.from(
          _editorController.removedSubtaskIds,
        ),
        items: items,
      );
    } on RepositoryException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
