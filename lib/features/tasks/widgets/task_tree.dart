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
            horizontal: AppTokens.spaceSm,
            vertical: AppTokens.spaceXs,
          ),
          itemCount: treeNodes.length,
          itemBuilder: (context, index) {
            final node = treeNodes[index];
            return LongPressDraggable<String>(
              data: node.task.id,
              onDragStarted: () {
                setState(() => _draggingTaskId = node.task.id);
              },
              onDragEnd: (_) {
                setState(() {
                  _draggingTaskId = null;
                  _dragTargetId = null;
                  _isInvalidDragTarget = false;
                });
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

                  // 检查是否是后代。
                  final byId = indexTasksById(tasks);
                  final draggedTask = byId[draggedId];
                  final targetTask = byId[targetId];
                  if (draggedTask != null && targetTask != null) {
                    if (isDescendantOf(targetTask, draggedTask, byId)) {
                      setState(() {
                        _dragTargetId = targetId;
                        _isInvalidDragTarget = true;
                      });
                      return false;
                    }

                    // 检查深度限制。
                    final childrenIndex = indexChildrenByParent(tasks);
                    final targetDepth = depthOf(targetTask, byId);
                    final nodeSubtree = subtreeDepthOf(
                      draggedTask,
                      childrenIndex,
                    );
                    if (targetDepth + nodeSubtree > 3) {
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
                onAcceptWithDetails: (details) async {
                  final draggedId = details.data;
                  final targetId = node.task.id;

                  // 计算新的父级和索引。
                  final byId = indexTasksById(tasks);
                  final draggedTask = byId[draggedId];
                  final targetTask = byId[targetId];

                  if (draggedTask == null || targetTask == null) return;

                  // 同级排序：目标的父级作为新父级，索引为目标的 sortOrder。
                  final newParentId = targetTask.parentId;
                  final newIndex = targetTask.sortOrder;

                  try {
                    await repo.moveTask(
                      draggedId,
                      newParentId: newParentId,
                      newIndex: newIndex,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.moveFailed(e.toString()))),
                      );
                    }
                  }
                  setState(() {
                    _draggingTaskId = null;
                    _dragTargetId = null;
                    _isInvalidDragTarget = false;
                  });
                },
                onLeave: (_) {
                  setState(() {
                    _dragTargetId = null;
                    _isInvalidDragTarget = false;
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
                  );
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(e.toString())));
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
        await _moveTask(task, tasks, repo, -1);
      case 'moveDown':
        await _moveTask(task, tasks, repo, 1);
      case 'indent':
        await _indentTask(task, tasks, repo);
      case 'outdent':
        await _outdentTask(task, tasks, repo);
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
              ).showSnackBar(SnackBar(content: Text(e.toString())));
            }
          }
        }
    }
  }

  Future<void> _moveTask(
    Task task,
    List<Task> tasks,
    TodoRepository repo,
    int direction,
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
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _indentTask(
    Task task,
    List<Task> tasks,
    TodoRepository repo,
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
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _outdentTask(
    Task task,
    List<Task> tasks,
    TodoRepository repo,
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
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppTokens.spaceMd),
            Text(
              l10n.emptyProjectDetail,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
