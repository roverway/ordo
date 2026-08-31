// 新建任务底部弹窗（59-task-editor-optimization.md §5.2 定稿）。
//
// 弹出式容器：保持底部弹窗形态（60–65% 高、顶部圆角、遮罩、键盘 viewInsets 上移、
// enableDrag:false 避免拖拽下滑与 PopScope 拦截冲突），内容区换用共享编辑器
// [TaskEditor]（顶部栏/选项行/子任务 UI 全部由编辑器提供）。
//
// - 保存：自动保存（关闭时复用 taskFormProvider.save；内容全空直接关闭不落库；
//   有内容但标题为空 → 提示并停留；保存成功后批量创建非空子任务）。
// - 缺省收件箱逻辑（inboxProjectId / inboxProjectProvider）保留。
// - 子任务区仅 1 级任务展示（parentId 为空时）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/todo_repository.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/platform/keyboard_inset_bridge.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/priority_color.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/motion.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../projects/project_providers.dart';
import '../../tags/tag_providers.dart';
import 'priority_picker.dart';
import '../task_providers.dart';
import 'task_editor.dart';

/// 新建任务底部弹窗。
class TaskCreateSheet extends ConsumerStatefulWidget {
  const TaskCreateSheet({
    super.key,
    this.projectId,
    this.parentId,
    this.initialStartAt,
    this.initialEndAt,
    this.initialPriority,
    this.initialTagIds,
  });

  final String? projectId;
  final String? parentId;

  /// 预填开始/截止时间（UTC 毫秒，日历「点日期新建」传入）。
  final int? initialStartAt;
  final int? initialEndAt;

  /// 预填优先级（看板/筛选列「按优先级筛选」传入）。
  final TaskPriority? initialPriority;

  /// 预填关联标签（看板/筛选列「按标签筛选」传入）。
  final List<String>? initialTagIds;

  /// 打开新建任务底部弹窗（滴答式，原生逐帧键盘桥接适配）。
  ///
  /// 入场转场（docs/63-motion-polish.md §5 G）：slide-up + `motionCurve`
  /// （easeOutCubic，无过冲）+ `motionSlow`（350ms），遮罩随同一动画同步淡入
  /// （showGeneralDialog 的 barrier 用默认 linear curve 淡入）。
  /// reduced motion 自动降级：时长为零（瞬时到位）。
  ///
  /// - [projectId] 缺省时默认落入内置收件箱（产品决策 #3）；
  /// - [parentId] 非空 = 创建子任务（此时不展示子任务区，层级受 3 级上限约束）。
  static Future<void> show(
    BuildContext context, {
    String? projectId,
    String? parentId,
    int? initialStartAt,
    int? initialEndAt,
    TaskPriority? initialPriority,
    List<String>? initialTagIds,
  }) {
    final notifier = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(taskFormProvider.notifier);
    notifier.resetForNew(projectId ?? inboxProjectId, parentId);
    if (initialStartAt != null) notifier.updateStartAt(initialStartAt);
    if (initialEndAt != null) notifier.updateEndAt(initialEndAt);
    if (initialPriority != null) notifier.updatePriority(initialPriority);
    if (initialTagIds != null && initialTagIds.isNotEmpty) {
      notifier.setSelectedTags(initialTagIds);
    }

    final sheetTheme = Theme.of(context).bottomSheetTheme;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      sheetAnimationStyle: AnimationStyle(
        duration: motionSlow(context),
        reverseDuration: motionSlow(context),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation:
          sheetTheme.modalElevation ??
          sheetTheme.elevation ??
          AppTokens.elevationCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusDialog),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) {
        return KeyboardInsetBuilder(
          child: RepaintBoundary(
            child: MediaQuery.removeViewInsets(
              removeBottom: true,
              context: sheetContext,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: TaskCreateSheet(
                  projectId: projectId,
                  parentId: parentId,
                  initialStartAt: initialStartAt,
                  initialEndAt: initialEndAt,
                  initialPriority: initialPriority,
                  initialTagIds: initialTagIds,
                ),
              ),
            ),
          ),
          builder: (context, effectiveInset, bottomGap, sheetChild) {
            return Padding(
              padding: EdgeInsets.only(bottom: effectiveInset + bottomGap),
              child: sheetChild!,
            );
          },
        );
      },
    );
  }

  @override
  ConsumerState<TaskCreateSheet> createState() => _TaskCreateSheetState();
}

class _TaskCreateSheetState extends ConsumerState<TaskCreateSheet> {
  final _editorController = TaskEditorController(mode: TaskEditorMode.create);
  bool _isSaving = false;
  bool _initialized = false;

  /// 自动保存完成后置 true，放行 PopScope 的 pop（canPop 由状态驱动）。
  bool _allowPop = false;

  /// 是否在关闭弹窗时自动保存
  bool _autoSaveOnClose = true;

  @override
  void initState() {
    super.initState();
    // 首帧后初始化表单（Riverpod 禁止在 initState 中写 provider，
    // 与 task_edit_page._loadData 的 addPostFrameCallback 模式一致）。
    WidgetsBinding.instance.addPostFrameCallback((_) => _initForm());
  }

  /// 初始化表单：同步复位 + 解析项目（缺省收件箱，幂等 ensure，产品决策 #3）。
  Future<void> _initForm() async {
    if (_initialized) return;
    _initialized = true;
    final notifier = ref.read(taskFormProvider.notifier);

    // 1. 同步复位（可立即输入）：缺省项目用收件箱固定 id，幂等语义不变。
    final initialProjectId = widget.projectId ?? inboxProjectId;
    notifier.resetForNew(initialProjectId, widget.parentId);
    if (widget.initialStartAt != null) {
      notifier.updateStartAt(widget.initialStartAt);
    }
    if (widget.initialEndAt != null) {
      notifier.updateEndAt(widget.initialEndAt);
    }
    if (widget.initialPriority != null) {
      notifier.updatePriority(widget.initialPriority!);
    }
    if (widget.initialTagIds != null && widget.initialTagIds!.isNotEmpty) {
      notifier.setSelectedTags(widget.initialTagIds!);
    }

    // 2. 缺省项目时确保收件箱行存在（幂等），解析完成后仅校正项目字段。
    if (widget.projectId == null) {
      try {
        final inbox = await ref.read(inboxProjectProvider.future);
        final currentState = ref.read(taskFormProvider);
        if (currentState.projectId != inbox.id) {
          notifier.setProjectAndParent(inbox.id, widget.parentId);
        }
      } catch (_) {
        // ensure 失败极罕见（SQLite 本地库）：表单已按收件箱 id 初始化，
        // 保存时若行缺失会经 RepositoryException 走 SnackBar，不静默丢数据。
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final startAt = ref.watch(taskFormProvider.select((s) => s.startAt));
    final endAt = ref.watch(taskFormProvider.select((s) => s.endAt));
    final priority = ref.watch(taskFormProvider.select((s) => s.priority));
    final selectedTagIds = ref.watch(taskFormProvider.select((s) => s.selectedTagIds));

    final tags = ref.watch(tagsStreamProvider).value ?? const <Tag>[];
    final selectedTags = [
      for (final id in selectedTagIds)
        if (tags.any((t) => t.id == id)) tags.firstWhere((t) => t.id == id),
    ];

    ref.listen(taskFormProvider, (previous, next) {
      if (_editorController.titleController.text != next.title) {
        _editorController.titleController.text = next.title;
      }
      if (_editorController.descriptionController.text != next.description) {
        _editorController.descriptionController.text = next.description;
      }
    });

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndClose();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 顶部 Header 栏：关闭、项目选择器、保存 ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _saveAndClose();
                  },
                ),
                const Expanded(
                  child: Center(
                    child: TaskProjectSwitcher(interactive: true),
                  ),
                ),
                TextButton(
                  onPressed: _saveAndCloseExplicit,
                  child: Text(
                    l10n.save,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 12),

            // ── 任务标题输入框 ──
            TextField(
              controller: _editorController.titleController,
              focusNode: _editorController.titleFocusNode,
              autofocus: true,
              maxLines: null,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: l10n.taskTitle,
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (v) => ref.read(taskFormProvider.notifier).updateTitle(v),
            ),

            // ── 任务描述输入框 ──
            TextField(
              controller: _editorController.descriptionController,
              maxLines: 3,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: l10n.taskDescription,
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
              onChanged: (v) => ref.read(taskFormProvider.notifier).updateDescription(v),
            ),
            const SizedBox(height: 16),

            // ── 开始时间 & 结束时间胶囊按钮行 ──
            Row(
              children: [
                Expanded(
                  child: _buildTimePill(
                    isStart: true,
                    label: startAt != null
                        ? formatDueDate(startAt, l10n)
                        : l10n.taskStartTime,
                    icon: Icons.calendar_today_outlined,
                    hasValue: startAt != null,
                    onTap: () => showTaskDatePicker(context, ref),
                    onClear: () => ref.read(taskFormProvider.notifier).updateStartAt(null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimePill(
                    isStart: false,
                    label: endAt != null
                        ? formatDueDate(endAt, l10n)
                        : l10n.taskEndTime,
                    icon: Icons.flag_outlined,
                    hasValue: endAt != null,
                    onTap: () => showTaskDatePicker(context, ref),
                    onClear: () => ref.read(taskFormProvider.notifier).updateEndAt(null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── 优先级 ──
            Row(
              children: [
                Text(
                  l10n.priority,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final p in TaskPriority.values)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: _buildPrioritySegment(p, priority, l10n),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── 标签 ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  l10n.taskTags,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final tag in selectedTags)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Color(tag.color).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: Color(tag.color).withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            tag.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Color(tag.color),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: () => showTaskTagPicker(context, ref),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: colorScheme.primary,
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.label_outline, size: 14, color: colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                l10n.taskTags,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── 子任务 ──
            if (widget.parentId == null) ...[
              const SizedBox(height: 16),
              SubtaskList(
                controller: _editorController,
                onAddSubtaskAndFocus: () {
                  _editorController.addSubtask();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final rows = _editorController.subtaskRows;
                    if (rows.isNotEmpty) rows.last.focusNode.requestFocus();
                  });
                },
                onConfirmRemoveSubtask: (row) async {
                  if (row.isNew) {
                    _editorController.removeSubtask(row);
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
                    _editorController.removeSubtask(row);
                  }
                },
              ),
            ],

            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 8),

            // ── 关闭时自动保存 ──
            Row(
              children: [
                Text(
                  l10n.autoSaveOnClose,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _autoSaveOnClose,
                  onChanged: (val) {
                    setState(() {
                      _autoSaveOnClose = val;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePill({
    required bool isStart,
    required String label,
    required IconData icon,
    required bool hasValue,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasValue
              ? colorScheme.primary.withValues(alpha: 0.1)
              : (theme.brightness == Brightness.dark ? Colors.white10 : Colors.grey[100]),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: hasValue
                ? colorScheme.primary.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: hasValue ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: hasValue ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
            if (hasValue) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  onClear();
                },
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrioritySegment(TaskPriority p, TaskPriority current, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = p == current;
    final color = priorityColor(p);

    return GestureDetector(
      onTap: () {
        ref.read(taskFormProvider.notifier).updatePriority(p);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : (theme.brightness == Brightness.dark ? Colors.white10 : Colors.grey[100]),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              priorityLabel(l10n, p),
              style: theme.textTheme.bodySmall?.copyWith(
                color: isSelected ? color : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 自动保存 / 手动保存 ──

  Future<void> _saveAndCloseExplicit() async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(taskFormProvider.notifier);
    final formState = ref.read(taskFormProvider);

    if (formState.title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.titleRequired)),
      );
      return;
    }

    setState(() => _isSaving = true);
    final errorKey = await notifier.save();
    if (!mounted) return;
    if (errorKey != null) {
      final message = switch (errorKey) {
        'title_required' => l10n.titleRequired,
        'end_time_before_start' => l10n.endTimeBeforeStart,
        _ => errorKey,
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() => _isSaving = false);
      return;
    }

    await _createSubtasks();
    if (mounted) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveAndClose() async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context);
    await _initForm();
    if (!mounted) return;
    final notifier = ref.read(taskFormProvider.notifier);
    final formState = ref.read(taskFormProvider);

    if (!_autoSaveOnClose || formState.title.trim().isEmpty) {
      if (mounted) {
        setState(() => _allowPop = true);
        Navigator.of(context).pop();
      }
      return;
    }

    setState(() => _isSaving = true);
    final errorKey = await notifier.save();
    if (!mounted) return;
    if (errorKey != null) {
      final message = switch (errorKey) {
        'title_required' => l10n.titleRequired,
        'end_time_before_start' => l10n.endTimeBeforeStart,
        _ => errorKey,
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      setState(() => _isSaving = false);
      return;
    }

    await _createSubtasks();
    if (mounted) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    }
  }

  /// 保存成功后批量创建非空子任务（复用 repo.createTask，parentId 指向新任务）。
  Future<void> _createSubtasks() async {
    final repo = ref.read(todoRepositoryProvider);
    final formState = ref.read(taskFormProvider);
    final parentId = formState.id;
    if (parentId == null) return;
    try {
      for (final row in _editorController.subtaskRows) {
        final title = row.controller.text.trim();
        if (row.isNew && title.isNotEmpty) {
          await repo.createTask(
            projectId: formState.projectId,
            parentId: parentId,
            title: title,
            status: row.status,
          );
        }
      }
    } on RepositoryException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}
