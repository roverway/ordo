import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/derived.dart';
import '../../../core/utils/tree.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../projects/project_providers.dart';
import '../task_providers.dart';
import 'task_row.dart';

/// 任务树组件（50-ui-ux.md §5.3）。
///
/// 缩进 + 展开/折叠；每行：勾选、标题、标签、时间、状态徽标。
/// 支持长按拖拽排序/调级 + 键盘兜底。
class TaskTree extends ConsumerStatefulWidget {
  const TaskTree({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<TaskTree> createState() => _TaskTreeState();
}

class _TaskTreeState extends ConsumerState<TaskTree> {
  String? _draggingTaskId;
  String? _dragTargetId;
  bool _isInvalidDragTarget = false;

  /// 当前拖拽悬停目标行的位置：false=上半（同级排序），true=下半（成为子级）。
  bool _dropAsChild = false;

  /// 每行 GlobalKey，用于在 onMove 时换算悬停位置（上半/下半）。
  final Map<String, GlobalKey> _rowKeys = {};

  GlobalKey _rowKey(String id) => _rowKeys.putIfAbsent(id, () => GlobalKey());

  void _clearDragState() {
    _draggingTaskId = null;
    _dragTargetId = null;
    _isInvalidDragTarget = false;
    _dropAsChild = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tasksAsync = ref.watch(projectTasksProvider(widget.projectId));
    final expandState = ref.watch(treeExpandProvider(widget.projectId));

    return tasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          return _buildEmptyState(context, l10n);
        }

        final treeNodes = buildTreeNodes(
          tasks: tasks,
          expandState: expandState,
        );
        final repo = ref.read(todoRepositoryProvider);

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceMd,
            vertical: AppTokens.spaceSm,
          ),
          itemCount: treeNodes.length + (_draggingTaskId != null ? 1 : 0),
          itemBuilder: (context, index) {
            // 拖拽进行时在列表末尾追加"回到 1 级"落点（FR-TSK-07）。
            if (index >= treeNodes.length) {
              return _buildRootDropZone(context, tasks, repo, l10n);
            }
            final node = treeNodes[index];
            return LongPressDraggable<String>(
              data: node.task.id,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              onDragStarted: () {
                setState(() => _draggingTaskId = node.task.id);
              },
              onDragEnd: (_) {
                setState(_clearDragState);
              },
              feedback: Material(
                color: Colors.transparent,
                child: Opacity(
                  opacity: 0.8,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    padding: const EdgeInsets.all(AppTokens.spaceSm),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppTokens.radiusList),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      node.task.title,
                      style: Theme.of(context).textTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.3,
                child: _buildTaskRow(context, node, tasks, repo, expandState),
              ),
              child: KeyedSubtree(
                key: _rowKey(node.task.id),
                child: DragTarget<String>(
                  onWillAcceptWithDetails: (details) {
                    final draggedId = details.data;
                    final targetId = node.task.id;

                    // 自身不能拖到自身。
                    if (draggedId == targetId) {
                      setState(() {
                        _dragTargetId = targetId;
                        _isInvalidDragTarget = true;
                      });
                      return false;
                    }

                    final byId = indexTasksById(tasks);
                    final draggedTask = byId[draggedId];
                    final targetTask = byId[targetId];
                    if (draggedTask != null && targetTask != null) {
                      // 检查是否是后代（防环，§5.2）。
                      if (isDescendantOf(targetTask, draggedTask, byId)) {
                        setState(() {
                          _dragTargetId = targetId;
                          _isInvalidDragTarget = true;
                        });
                        return false;
                      }

                      // 深度校验（§5.1）：统一用
                      // depthOf(newParent) + subtreeDepthOf(node) <= 3。
                      // 当前悬停位置决定成为子级（父=目标）还是同级（父=目标父级）。
                      if (!_fitsDepthLimit(
                        draggedTask,
                        targetTask,
                        byId,
                        tasks,
                        _dropAsChild,
                      )) {
                        setState(() {
                          _dragTargetId = targetId;
                          _isInvalidDragTarget = true;
                        });
                        return false;
                      }
                    }

                    setState(() {
                      _dragTargetId = targetId;
                      _isInvalidDragTarget = false;
                    });
                    return true;
                  },
                  onMove: (details) {
                    // 根据悬停纵向位置切换语义：
                    // 上半 = 同级排序（插到目标前），下半 = 成为子级。
                    // 注：dragAnchorStrategy 用 pointerDragAnchorStrategy，
                    // 使 details.offset 即指针全局坐标（默认的 child 策略返回的是
                    // 反馈物锚点，不能直接用于定位）。
                    final box = _rowKey(
                      node.task.id,
                    ).currentContext?.findRenderObject();
                    if (box is! RenderBox) return;
                    final local = box.globalToLocal(details.offset);
                    final isLowerHalf = local.dy > box.size.height / 2;
                    if (isLowerHalf == _dropAsChild) return;

                    final byId = indexTasksById(tasks);
                    final draggedTask = byId[_draggingTaskId];
                    final targetTask = byId[node.task.id];
                    if (draggedTask == null || targetTask == null) return;
                    final fits = _fitsDepthLimit(
                      draggedTask,
                      targetTask,
                      byId,
                      tasks,
                      isLowerHalf,
                    );
                    setState(() {
                      _dropAsChild = isLowerHalf;
                      _dragTargetId = node.task.id;
                      _isInvalidDragTarget = !fits;
                    });
                  },
                  onAcceptWithDetails: (details) async {
                    final draggedId = details.data;
                    final targetId = node.task.id;

                    // onMove 可能已将目标标记为非法（超深/防环），此时拒绝落点。
                    if (_isInvalidDragTarget && _dragTargetId == targetId) {
                      if (mounted) setState(_clearDragState);
                      return;
                    }

                    final byId = indexTasksById(tasks);
                    final draggedTask = byId[draggedId];
                    final targetTask = byId[targetId];

                    if (draggedTask == null || targetTask == null) return;

                    final String? newParentId;
                    final int newIndex;
                    if (_dropAsChild) {
                      // 成为目标的子级：追加到目标现有子任务末尾。
                      newParentId = targetId;
                      final childrenIndex = indexChildrenByParent(tasks);
                      newIndex =
                          (childrenIndex[targetId] ?? const <Task>[]).length;
                    } else {
                      // 同级排序：目标的父级作为新父级，插到目标之前。
                      newParentId = targetTask.parentId;
                      newIndex = targetTask.sortOrder;
                    }

                    try {
                      await repo.moveTask(
                        draggedId,
                        newParentId: newParentId,
                        newIndex: newIndex,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_friendlyError(l10n, e))),
                        );
                      }
                    }
                    if (mounted) setState(_clearDragState);
                  },
                  onLeave: (_) {
                    setState(() {
                      _dragTargetId = null;
                      _isInvalidDragTarget = false;
                      _dropAsChild = false;
                    });
                  },
                  builder: (context, candidateData, rejectedData) {
                    return _buildTaskRow(
                      context,
                      node,
                      tasks,
                      repo,
                      expandState,
                      isDragTarget: _dragTargetId == node.task.id,
                      isInvalidDragTarget:
                          _isInvalidDragTarget && _dragTargetId == node.task.id,
                      isDragging: _draggingTaskId == node.task.id,
                      dropAsChild:
                          _dropAsChild && _dragTargetId == node.task.id,
                    );
                  },
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }

  /// 深度校验（§5.1）：`depthOf(newParent) + subtreeDepthOf(node) <= 3`。
  ///
  /// [asChild] 为 true 时新父级 = 目标自身（成为子级）；
  /// false 时新父级 = 目标的父级（同级排序）。提升为 1 级恒满足。
  bool _fitsDepthLimit(
    Task dragged,
    Task target,
    Map<String, Task> byId,
    List<Task> tasks,
    bool asChild,
  ) {
    final childrenIndex = indexChildrenByParent(tasks);
    final nodeSubtree = subtreeDepthOf(dragged, childrenIndex);
    if (nodeSubtree > 3) return false;

    final newParentId = asChild ? target.id : target.parentId;
    if (newParentId == null) return true; // 回到 1 级恒满足。
    final parent = byId[newParentId];
    if (parent == null) return true;
    final parentDepth = depthOf(parent, byId);
    return parentDepth + nodeSubtree <= 3;
  }

  /// "回到 1 级"落点（FR-TSK-07）：拖拽时追加在列表末尾。
  Widget _buildRootDropZone(
    BuildContext context,
    List<Task> tasks,
    TodoRepository repo,
    AppLocalizations l10n,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) async {
        final byId = indexTasksById(tasks);
        final draggedTask = byId[details.data];
        if (draggedTask == null) return;
        try {
          await repo.moveTask(
            draggedTask.id,
            newParentId: null,
            newIndex:
                (indexChildrenByParent(tasks)[null] ?? const <Task>[]).length,
          );
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(_friendlyError(l10n, e))));
          }
        }
        if (mounted) setState(_clearDragState);
      },
      onLeave: (_) {
        setState(() {
          _dragTargetId = null;
          _isInvalidDragTarget = false;
          _dropAsChild = false;
        });
      },
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceSm,
            vertical: AppTokens.spaceXs,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppTokens.spaceMd),
            decoration: BoxDecoration(
              color: active
                  ? colorScheme.primaryContainer.withValues(alpha: 0.4)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppTokens.radiusList),
              border: Border.all(
                color: active
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.vertical_align_top,
                  size: 18,
                  color: active
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTokens.spaceXs),
                Text(
                  l10n.dropToRoot,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: active
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskRow(
    BuildContext context,
    TreeNode node,
    List<Task> tasks,
    TodoRepository repo,
    Map<String, bool> expandState, {
    bool isDragTarget = false,
    bool isInvalidDragTarget = false,
    bool isDragging = false,
    bool dropAsChild = false,
  }) {
    final childrenIndex = indexChildrenByParent(tasks);
    final byId = indexTasksById(tasks);
    final directChildren = childrenIndex[node.task.id] ?? const <Task>[];
    final subtree = getSubtreeIds(
      node.task.id,
      tasks,
    ).map((id) => byId[id]).whereType<Task>().toList();
    final effectiveStatus = directChildren.isNotEmpty
        ? derivedStatus(node.task, directChildren)
        : null;
    final progressValue = directChildren.isNotEmpty
        ? progress(node.task, subtree)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: TaskRow(
        task: node.task,
        depth: node.depth,
        hasChildren: node.hasChildren,
        isExpanded: node.isExpanded,
        onToggleExpand: () {
          ref
              .read(treeExpandProvider(widget.projectId).notifier)
              .toggle(node.task.id);
        },
        onToggleDone: (value) async {
          final newStatus = value == true ? TaskStatus.done : TaskStatus.todo;
          try {
            await repo.updateTask(node.task.id, status: newStatus);
          } catch (e) {
            if (context.mounted) {
              final l10n = AppLocalizations.of(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(_friendlyError(l10n, e))));
            }
          }
        },
        onTap: () => context.push('/task/${node.task.id}'),
        onMenuAction: (action) =>
            _handleMenuAction(context, action, node.task, tasks, repo),
        derivedStatus: effectiveStatus,
        progressValue: progressValue,
        isDragging: isDragging,
        isDragTarget: isDragTarget,
        isInvalidDragTarget: isInvalidDragTarget,
        dropAsChild: dropAsChild,
      ),
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    String action,
    Task task,
    List<Task> tasks,
    TodoRepository repo,
  ) async {
    final l10n = AppLocalizations.of(context);
    switch (action) {
      case 'edit':
        context.push('/task/${task.id}');
      case 'newSubtask':
        context.push(
          '/task/new?projectId=${task.projectId}&parentId=${task.id}',
        );
      case 'moveUp':
        await _moveTask(task, tasks, repo, -1, l10n);
      case 'moveDown':
        await _moveTask(task, tasks, repo, 1, l10n);
      case 'indent':
        await _indentTask(task, tasks, repo, l10n);
      case 'outdent':
        await _outdentTask(task, tasks, repo, l10n);
      case 'delete':
        final confirmed = await showConfirmDialog(
          context: context,
          title: l10n.deleteTask,
          message: l10n.deleteTaskConfirm(task.title),
          confirmLabel: l10n.delete,
          confirmColor: Theme.of(context).colorScheme.error,
        );
        if (confirmed) {
          try {
            await repo.deleteTask(task.id);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(_friendlyError(l10n, e))));
            }
          }
        }
    }
  }

  /// 将 Repository 异常映射为面向用户的 ARB 文案（避免裸抛中文异常，AGENTS.md §3-8）。
  String _friendlyError(AppLocalizations l10n, Object e) {
    final message = e.toString();
    if (message.contains('不能移动到自身')) return l10n.cannotMoveToSelf;
    if (message.contains('防环') || message.contains('子任务下')) {
      return l10n.cannotMoveToDescendant;
    }
    if (message.contains('层级超过')) return l10n.moveDepthExceeded;
    return l10n.moveFailed(e.toString());
  }

  Future<void> _moveTask(
    Task task,
    List<Task> tasks,
    TodoRepository repo,
    int direction,
    AppLocalizations l10n,
  ) async {
    final childrenIndex = indexChildrenByParent(tasks);
    final siblings = task.parentId == null
        ? (childrenIndex[null] ?? const <Task>[])
        : (childrenIndex[task.parentId] ?? const <Task>[]);
    final sortedSiblings = List<Task>.from(siblings)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final currentIndex = sortedSiblings.indexWhere((t) => t.id == task.id);
    if (currentIndex < 0) return;

    final newIndex = currentIndex + direction;
    if (newIndex < 0 || newIndex >= sortedSiblings.length) return;

    try {
      await repo.moveTask(
        task.id,
        newParentId: task.parentId,
        newIndex: newIndex,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(l10n, e))));
      }
    }
  }

  Future<void> _indentTask(
    Task task,
    List<Task> tasks,
    TodoRepository repo,
    AppLocalizations l10n,
  ) async {
    final childrenIndex = indexChildrenByParent(tasks);
    final siblings = task.parentId == null
        ? (childrenIndex[null] ?? const <Task>[])
        : (childrenIndex[task.parentId] ?? const <Task>[]);
    final sortedSiblings = List<Task>.from(siblings)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final currentIndex = sortedSiblings.indexWhere((t) => t.id == task.id);
    if (currentIndex <= 0) return;

    // 新父级 = 上一个兄弟。
    final newParent = sortedSiblings[currentIndex - 1];
    final newParentChildren = childrenIndex[newParent.id] ?? const <Task>[];

    try {
      await repo.moveTask(
        task.id,
        newParentId: newParent.id,
        newIndex: newParentChildren.length,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(l10n, e))));
      }
    }
  }

  Future<void> _outdentTask(
    Task task,
    List<Task> tasks,
    TodoRepository repo,
    AppLocalizations l10n,
  ) async {
    if (task.parentId == null) return;

    final byId = indexTasksById(tasks);
    final parent = byId[task.parentId];
    if (parent == null) return;

    // 提升到父级的同级，排在父级之后。
    final grandparentChildren = parent.parentId == null
        ? (indexChildrenByParent(tasks)[null] ?? const <Task>[])
        : (indexChildrenByParent(tasks)[parent.parentId] ?? const <Task>[]);
    final sortedGrandparent = List<Task>.from(grandparentChildren)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final parentIndex = sortedGrandparent.indexWhere((t) => t.id == parent.id);
    final newIndex = parentIndex + 1;

    try {
      await repo.moveTask(
        task.id,
        newParentId: parent.parentId,
        newIndex: newIndex,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyError(l10n, e))));
      }
    }
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return EmptyState(
      icon: Icons.checklist_outlined,
      message: l10n.emptyProjectDetail,
    );
  }
}
