import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/priority_color.dart';
import '../../../shared/widgets/swipe_actions.dart';
import '../../projects/project_providers.dart';
import 'priority_picker.dart';
import 'task_editor/tag_picker_sheet.dart';

/// 任务行滑动操作业务包装（仅移动端生效，50-ui-ux.md §6.4）。
///
/// - **左滑**：露出「优先级」「标签」快捷按钮，点击弹底部弹层即点即改
///   （直接写 `TodoRepository`，不走 `taskFormProvider`）。
/// - **右滑**：滑过阈值直接切换完成状态（已完成 ↔ 未完成）；仓库层自动
///   维护 `completedAt`。有子任务的任务状态由子任务派生（AGENTS.md §3-2），
///   右滑被禁用，与勾选框禁用逻辑一致；也可用 [endSwipeEnabled] 显式关闭。
///
/// 桌面平台由 [SwipeActions] 内部原样放行 [child]，不影响右键菜单等交互。
class TaskSwipeWrapper extends ConsumerWidget {
  const TaskSwipeWrapper({
    super.key,
    required this.task,
    required this.hasChildren,
    required this.isDone,
    required this.child,
    this.endSwipeEnabled,
    this.onTaskUpdated,
  });

  final Task task;
  final bool hasChildren;

  /// 当前有效完成态（父任务传派生状态的结果）。
  final bool isDone;
  final Widget child;

  /// 显式指定右滑是否可用；null 时按 [hasChildren] 推导（父任务禁用）。
  /// 编辑器子任务行等只想暴露左滑快捷设置、完成态由别处（草稿）管理的
  /// 场景传 false。
  final bool? endSwipeEnabled;

  /// 任一直接落库的快捷设置成功后回调（带回读的最新任务快照）。
  /// 调用方（如编辑器子任务行）用它刷新本地缓存，避免下次弹层「当前项」陈旧。
  final ValueChanged<Task>? onTaskUpdated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final priorityTint = priorityColor(task.priority);

    return SwipeActions(
      endSwipeEnabled: endSwipeEnabled ?? !hasChildren,
      endSwipeIcon: isDone ? Icons.undo : Icons.check,
      onEndSwipeTriggered: () => _toggleDone(context, ref),
      startActions: [
        SwipeActionSpec(
          icon: Icons.flag_outlined,
          iconColor: priorityTint,
          backgroundColor: priorityTint.withValues(
            alpha: AppTokens.alphaTintSoft,
          ),
          tooltip: l10n.priority,
          onTap: () => _setPriority(context, ref),
        ),
        SwipeActionSpec(
          icon: Icons.label_outline,
          iconColor: AppTokens.colorNavTags,
          backgroundColor: AppTokens.colorNavTags.withValues(
            alpha: AppTokens.alphaTintSoft,
          ),
          tooltip: l10n.taskTags,
          onTap: () => _setTags(context, ref),
        ),
      ],
      child: child,
    );
  }

  /// 右滑切换完成状态（仓库自动维护 completedAt）。
  Future<void> _toggleDone(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(todoRepositoryProvider)
          .updateTask(
            task.id,
            status: isDone ? TaskStatus.todo : TaskStatus.done,
          );
      await _notifyTaskUpdated(ref);
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, e);
    }
  }

  /// 优先级快捷设置：复用现有底部弹层选择器，选中后直接落库。
  Future<void> _setPriority(BuildContext context, WidgetRef ref) async {
    final priority = await showPriorityPicker(context, current: task.priority);
    if (priority == null || priority == task.priority) return;
    if (!context.mounted) return;
    try {
      await ref
          .read(todoRepositoryProvider)
          .updateTask(task.id, priority: priority);
      await _notifyTaskUpdated(ref);
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, e);
    }
  }

  /// 标签快捷设置：底部弹层即点即改（全量替换写回）。
  Future<void> _setTags(BuildContext context, WidgetRef ref) async {
    await showTaskTagQuickPicker(context, ref, taskId: task.id);
  }

  /// 快捷设置落库成功后回读任务并通知调用方（仅在注册了回调时）。
  Future<void> _notifyTaskUpdated(WidgetRef ref) async {
    if (onTaskUpdated == null) return;
    final fresh = await ref.read(todoRepositoryProvider).tasks.getById(task.id);
    if (fresh != null) onTaskUpdated!(fresh);
  }

  void _showError(BuildContext context, Object e) {
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final message = e.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message.contains('由子任务派生')
              ? l10n.statusDerivedFromChildren
              : l10n.taskUpdateFailed,
        ),
      ),
    );
  }
}
