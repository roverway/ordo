import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/derived.dart';
import '../../../core/utils/motion.dart';
import '../../../core/utils/tree.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/filter_chips_bar.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/staggered_fade_slide.dart';
import '../../projects/project_providers.dart';
import '../task_edit_page.dart';
import '../task_providers.dart';
import 'task_row.dart';

/// 任务树组件（50-ui-ux.md §5.3；57-task-page-polish.md §4.2 批 2 卡片化）。
class TaskTree extends ConsumerStatefulWidget {
  const TaskTree({
    super.key,
    required this.projectId,
    this.filterMode = TaskFilterChipMode.all,
    this.searchQuery = '',
  });

  final String projectId;
  final TaskFilterChipMode filterMode;
  final String searchQuery;

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
  /// 覆盖两类行：一级卡片头与卡片内紧凑子行（每个任务 id 唯一）。
  final Map<String, GlobalKey> _rowKeys = {};

  GlobalKey _rowKey(String id) => _rowKeys.putIfAbsent(id, () => GlobalKey());

  void _clearDragState() {
    _draggingTaskId = null;
    _dragTargetId = null;
    _isInvalidDragTarget = false;
    _dropAsChild = false;
  }

  @override
  void dispose() {
    _rowKeys.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tasksAsync = ref.watch(projectTasksProvider(widget.projectId));
    final expandState = ref.watch(treeExpandProvider(widget.projectId));

    return tasksAsync.when(
      data: (tasks) {
        if (tasks.isEmpty) {
          _rowKeys.clear();
          return _buildEmptyState(context, l10n);
        }
        // 全量任务集索引（一次构建、整棵树共享）：_buildTaskRow 每行与
        // 隐藏过滤复用，避免每行重算 O(n) 索引（打开任务页变慢的主因）。
        final childrenIndexAll = indexChildrenByParent(tasks);
        final byIdAll = indexTasksById(tasks);

        var filteredTasks = tasks;
        if (widget.filterMode == TaskFilterChipMode.open) {
          filteredTasks = _filterDoneTasks(tasks, childrenIndexAll);
        } else if (widget.filterMode == TaskFilterChipMode.done) {
          filteredTasks = tasks
              .where((t) => t.status == TaskStatus.done)
              .toList();
        }

        if (widget.searchQuery.isNotEmpty) {
          final q = widget.searchQuery.toLowerCase();
          filteredTasks = filteredTasks.where((t) {
            return t.title.toLowerCase().contains(q) ||
                t.description.toLowerCase().contains(q);
          }).toList();
        }

        final hideDone = ref.watch(hideCompletedTasksProvider);
        final visibleTasks =
            (hideDone && widget.filterMode == TaskFilterChipMode.all)
            ? _filterDoneTasks(filteredTasks, childrenIndexAll)
            : filteredTasks;

        if (visibleTasks.isEmpty) {
          _rowKeys.clear();
          return EmptyState(
            icon: Icons.check_circle_outline,
            message: widget.searchQuery.isNotEmpty
                ? '未搜索到相关任务'
                : (widget.filterMode == TaskFilterChipMode.done
                      ? '暂无已完成任务'
                      : l10n.allTasksCompleted),
          );
        }

        // 清理已不在当前可见任务集中的 GlobalKey，防止长期增删列表导致的引用残留与内存泄漏
        final visibleIds = {for (final t in visibleTasks) t.id};
        _rowKeys.removeWhere((id, _) => !visibleIds.contains(id));

        final treeNodes = buildTreeNodes(
          tasks: visibleTasks,
          expandState: expandState,
        );
        // 一级任务 = 列表项（卡片）；内部子任务行递归渲染在卡片内。
        final roots = treeNodes.where((n) => n.depth == 0).toList();
        final childrenOf = _indexDirectChildren(treeNodes);
        final repo = ref.read(todoRepositoryProvider);

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: AppTokens.spaceXs,
          ),
          itemCount: roots.length + (_draggingTaskId != null ? 1 : 0),
          itemBuilder: (context, index) {
            // 拖拽进行时在列表末尾追加"回到 1 级"落点（FR-TSK-07）。
            if (index >= roots.length) {
              return _buildRootDropZone(
                context,
                visibleTasks,
                repo,
                l10n,
                childrenIndexAll,
              );
            }
            final root = roots[index];
            // B 批（des-4 需求 1）：一级卡片逐项错落入场——仅首次构建播放，
            // 数据刷新/拖拽重建不重放（StaggeredFadeSlide 一次性 controller）；
            // 子行随卡片一起进入，不叠加重复错落。
            return StaggeredFadeSlide(
              index: index,
              child: _buildCard(
                context,
                root,
                childrenOf,
                repo,
                expandState,
                // 派生计数/进度/拖拽落位均基于**全量**任务集索引（计数不随
                // 「隐藏已完成任务」变化；treeNodes 仍用过滤后的可见集）。
                childrenIndexAll: childrenIndexAll,
                byIdAll: byIdAll,
              ),
            );
          },
        );
      },
      loading: () => const LoadingView(),
      error: (e, st) {
        logAsyncError(e, st);
        return ErrorView(
          onRetry: () => ref.invalidate(projectTasksProvider(widget.projectId)),
        );
      },
    );
  }

  /// 过滤出未完成任务的可见集合（用户要求：隐藏已完成任务）。
  ///
  /// **递归**判定（F1 修复）：叶子按自身 status；有子任务的**整棵子树**全部
  /// 递归 done 才视为 done 并隐藏——避免「A 存储 done 但后来新增了未完成
  /// 子任务 C（createTask 不重置父级存储状态）」时 A 被隐藏、其可见子树
  /// 悬空成一级任务。cancelled ≠ done，保持可见。[childrenIndex] 为调用方
  /// 预构建的全量任务集索引（复用，避免重复 O(n) 扫描）。
  List<Task> _filterDoneTasks(
    List<Task> tasks,
    Map<String?, List<Task>> childrenIndex,
  ) {
    final doneMap = <String, bool>{};
    bool isDoneRecursive(Task t) {
      final cached = doneMap[t.id];
      if (cached != null) return cached;
      final children = childrenIndex[t.id] ?? const <Task>[];
      final done = children.isEmpty
          ? t.status == TaskStatus.done
          : children.every(isDoneRecursive);
      doneMap[t.id] = done;
      return done;
    }

    return tasks.where((t) => !isDoneRecursive(t)).toList();
  }

  /// 将扁平先序 [treeNodes] 分组成「父任务 id → 直接子节点列表」。
  ///
  /// treeNodes 为先序排列（`buildTreeNodes` 深度优先遍历，父节点必然先于其
  /// 整棵子树入列），因此可用**祖先栈**在单次遍历内完成分组：遍历时弹出所有
  /// 深度 ≥ 当前节点的栈顶（离开已完成的子树），栈顶即当前节点的父节点。
  /// 复杂度 O(n)，替代旧的 O(n²) 反向扫描（评审发现 #1）。
  Map<String, List<TreeNode>> _indexDirectChildren(List<TreeNode> treeNodes) {
    final result = <String, List<TreeNode>>{};
    // 祖先链栈：栈顶 = 当前节点之前的最近祖先（即其父节点候选）。
    final ancestors = <TreeNode>[];
    for (final node in treeNodes) {
      while (ancestors.isNotEmpty && ancestors.last.depth >= node.depth) {
        ancestors.removeLast();
      }
      if (node.depth > 0 && ancestors.isNotEmpty) {
        result.putIfAbsent(ancestors.last.task.id, () => []).add(node);
      }
      ancestors.add(node);
    }
    return result;
  }

  /// 一级任务大卡片（D1）：卡片头 + 展开区（自然梯队缩进子任务行）。
  ///
  /// 现代一体化卡片容器：1 级任务及其全部后代任务（2 级、3 级）包裹在同一个
  /// 精致白卡容器（surfaceCard + radiusCard + cardShadowLight）内，
  /// 告别生硬折线，采用纯净字阶与阶梯缩进表达层级。
  /// 一级任务行：扁平行 + 展开时的树状连线子任务区（与 tasklist.html 保持一致）。
  Widget _buildCard(
    BuildContext context,
    TreeNode rootNode,
    Map<String, List<TreeNode>> childrenOf,
    TodoRepository repo,
    Map<String, bool> expandState, {
    required Map<String?, List<Task>> childrenIndexAll,
    required Map<String, Task> byIdAll,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;
    final children = childrenOf[rootNode.task.id] ?? const <TreeNode>[];

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDraggableRow(
            context,
            rootNode,
            repo,
            expandState,
            style: TaskRowStyle.cardHeader,
            childrenIndexAll: childrenIndexAll,
            byIdAll: byIdAll,
          ),
          // 高度过渡层：子任务随容器自上而下平滑揭示
          AnimatedSize(
            duration: motionNormal(context),
            curve: motionCurve(context),
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: rootNode.isExpanded && children.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(left: 26, top: 2, bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: borderColor, width: 1),
                        ),
                      ),
                      child: _buildChildrenSection(
                        context,
                        children,
                        childrenOf,
                        repo,
                        expandState,
                        childrenIndexAll: childrenIndexAll,
                        byIdAll: byIdAll,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  /// 展开区：紧凑子任务行，有子任务的子行递归缩进展开（至 3 级）。
  Widget _buildChildrenSection(
    BuildContext context,
    List<TreeNode> children,
    Map<String, List<TreeNode>> childrenOf,
    TodoRepository repo,
    Map<String, bool> expandState, {
    required Map<String?, List<Task>> childrenIndexAll,
    required Map<String, Task> byIdAll,
    int depth = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++)
          _buildChildTreeItem(
            context,
            children[i],
            i,
            children.length,
            childrenOf,
            repo,
            expandState,
            childrenIndexAll: childrenIndexAll,
            byIdAll: byIdAll,
            depth: depth,
          ),
      ],
    );
  }

  Widget _buildChildTreeItem(
    BuildContext context,
    TreeNode childNode,
    int index,
    int total,
    Map<String, List<TreeNode>> childrenOf,
    TodoRepository repo,
    Map<String, bool> expandState, {
    required Map<String?, List<Task>> childrenIndexAll,
    required Map<String, Task> byIdAll,
    required int depth,
  }) {
    final grandChildren = childrenOf[childNode.task.id] ?? const <TreeNode>[];
    final hasGrandChildren = childNode.isExpanded && grandChildren.isNotEmpty;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDraggableRow(
            context,
            childNode,
            repo,
            expandState,
            style: TaskRowStyle.compact,
            childrenIndexAll: childrenIndexAll,
            byIdAll: byIdAll,
          ),
          if (hasGrandChildren)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 2, bottom: 6),
              child: Container(
                padding: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: borderColor, width: 1),
                  ),
                ),
                child: _buildChildrenSection(
                  context,
                  grandChildren,
                  childrenOf,
                  repo,
                  expandState,
                  childrenIndexAll: childrenIndexAll,
                  byIdAll: byIdAll,
                  depth: depth + 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 单个任务行的拖拽包装（D2 完整保留；61 §4.6 语义）：LongPressDraggable
  /// 包**整行**（长按行任意位置起拖），DragTarget 命中整行。
  ///
  /// 用户打磨要求（override 上一轮把手方案）：**恢复整行拖拽**，删除行尾
  /// 拖拽把手；行体长按不再弹菜单（与拖拽互斥），菜单入口改为桌面右键
  /// （TaskRow InkWell.onSecondaryTap）。以下逻辑全部沿用：
  /// - `_rowKeys` 按任务 id 登记（两类行共用），onMove 用其 RenderBox 换算
  ///   悬停位置（上半=同级排序，下半=成为子级 `_dropAsChild`）；
  /// - 深度校验 / 防环 / 非法目标高亮 / 回弹提示全部沿用，
  ///   `onAccept` 调 `repo.moveTask`。
  Widget _buildDraggableRow(
    BuildContext context,
    TreeNode node,
    TodoRepository repo,
    Map<String, bool> expandState, {
    required Map<String?, List<Task>> childrenIndexAll,
    required Map<String, Task> byIdAll,
    required TaskRowStyle style,
  }) {
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
        child: _buildTaskRow(
          context,
          node,
          repo,
          expandState,
          style: style,
          childrenIndexAll: childrenIndexAll,
          byIdAll: byIdAll,
          isDragging: true,
        ),
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

            // 防环/深度校验基于**全量**索引（F2 修复：隐藏已完成后可见集的
            // 子树深度会少算，可能放行超深落点）。
            final draggedTask = byIdAll[draggedId];
            final targetTask = byIdAll[targetId];
            if (draggedTask != null && targetTask != null) {
              // 检查是否是后代（防环，§5.2）。
              if (isDescendantOf(targetTask, draggedTask, byIdAll)) {
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
                byIdAll,
                childrenIndexAll,
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

            // 深度校验基于**全量**索引（F2 修复：隐藏已完成后可见集子树
            // 深度少算会放行超深落点）。
            final draggedTask = byIdAll[_draggingTaskId];
            final targetTask = byIdAll[node.task.id];
            if (draggedTask == null || targetTask == null) return;
            final fits = _fitsDepthLimit(
              draggedTask,
              targetTask,
              byIdAll,
              childrenIndexAll,
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

            final draggedTask = byIdAll[draggedId];
            final targetTask = byIdAll[targetId];

            if (draggedTask == null || targetTask == null) return;

            final String? newParentId;
            final int newIndex;
            if (_dropAsChild) {
              // 成为目标的子级：追加到目标**全量**现有子任务末尾（F2 修复：
              // 隐藏的 done 兄弟仍占位，newIndex 必须按全量计数）。
              newParentId = targetId;
              newIndex = (childrenIndexAll[targetId] ?? const <Task>[]).length;
            } else {
              // 同级排序：目标的父级作为新父级，插到目标之前（sortOrder 为
              // 全量 DB 字段，天然全量）。
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
                final l10n = AppLocalizations.of(context);
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
              repo,
              expandState,
              style: style,
              childrenIndexAll: childrenIndexAll,
              byIdAll: byIdAll,
              isDragTarget: _dragTargetId == node.task.id,
              isInvalidDragTarget:
                  _isInvalidDragTarget && _dragTargetId == node.task.id,
              isDragging: _draggingTaskId == node.task.id,
              dropAsChild: _dropAsChild && _dragTargetId == node.task.id,
            );
          },
        ),
      ),
    );
  }

  /// 深度校验（§5.1）：`depthOf(newParent) + subtreeDepthOf(node) <= 3`。
  ///
  /// [asChild] 为 true 时新父级 = 目标自身（成为子级）；
  /// false 时新父级 = 目标的父级（同级排序）。提升为 1 级恒满足。
  /// 基于**全量**索引（F2 修复：可见集子树深度在隐藏 done 子任务时会少算）。
  bool _fitsDepthLimit(
    Task dragged,
    Task target,
    Map<String, Task> byId,
    Map<String?, List<Task>> childrenIndex,
    bool asChild,
  ) {
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
    Map<String?, List<Task>> childrenIndexAll,
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
            // 追加到**全量**根级末尾（F2 修复：隐藏的 done 根仍占位，
            // 否则新行 sortOrder 会与隐藏行冲突/插错位置）。
            newIndex: (childrenIndexAll[null] ?? const <Task>[]).length,
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
    TodoRepository repo,
    Map<String, bool> expandState, {
    required Map<String?, List<Task>> childrenIndexAll,
    required Map<String, Task> byIdAll,
    TaskRowStyle style = TaskRowStyle.cardHeader,
    bool isDragTarget = false,
    bool isInvalidDragTarget = false,
    bool isDragging = false,
    bool dropAsChild = false,
  }) {
    // 派生计数/进度/完成度一律基于**全量**任务集（用户要求：子任务
    // 「未完成/总数」不随「隐藏已完成任务」开关变化）；行是否渲染仍由
    // 过滤后的 treeNodes（node.hasChildren）决定。索引由 build() 一次
    // 构建后整树共享，避免每行重算 O(n)。
    final childrenIndex = childrenIndexAll;
    final byId = byIdAll;
    final directChildren = childrenIndex[node.task.id] ?? const <Task>[];
    // 未完成子任务数：用每个子任务的有效状态（有子任务的按派生状态）判定，
    // 与勾选框/派生语义一致（AGENTS.md §3-2）；仅 done 视为完成。
    final incompleteChildren = directChildren.where((c) {
      final cChildren = childrenIndex[c.id] ?? const <Task>[];
      final eff = cChildren.isNotEmpty ? derivedStatus(c, cChildren) : c.status;
      return eff != TaskStatus.done;
    }).length;
    // 子树（进度用）：从全量索引收集，替代 getSubtreeIds 内部重复建索引
    // （F3 修复，保持每行 O(子树) 而非 O(n)）。
    final subtree = <Task>[];
    void collectSubtree(String id) {
      final t = byId[id];
      if (t != null) {
        subtree.add(t);
        for (final child in childrenIndex[id] ?? const <Task>[]) {
          collectSubtree(child.id);
        }
      }
    }

    collectSubtree(node.task.id);
    final effectiveStatus = directChildren.isNotEmpty
        ? derivedStatus(node.task, directChildren)
        : null;
    final progressValue = directChildren.isNotEmpty
        // includeSelf: false——父任务只是容器不参与进度计算，与行尾 x/y
        // 数字进度（只算子任务）一致（用户定稿 2026-08）。
        ? progress(node.task, subtree, includeSelf: false)
        : null;
    // 标签 chips：一级卡片头与紧凑子行均展示（61 §4.1/§4.4 统一规格，
    // 覆盖 57 文档 D7「紧凑子行保持精简」；参考案例子任务同样显示标签）。
    final tags =
        ref.watch(taskTagsProvider(node.task.id)).value ?? const <Tag>[];

    return TaskRow(
      task: node.task,
      depth: node.depth,
      style: style,
      hasChildren: node.hasChildren,
      isExpanded: node.isExpanded,
      childCount: directChildren.length,
      incompleteChildCount: incompleteChildren,
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
      onTap: () => openTaskEdit(context, taskId: node.task.id),
      onMenuAction: (action) => _handleMenuAction(
        context,
        action,
        node.task,
        childrenIndexAll,
        byIdAll,
        repo,
      ),
      derivedStatus: effectiveStatus,
      progressValue: progressValue,
      tags: tags,
      isDragging: isDragging,
      isDragTarget: isDragTarget,
      isInvalidDragTarget: isInvalidDragTarget,
      dropAsChild: dropAsChild,
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    String action,
    Task task,
    Map<String?, List<Task>> childrenIndexAll,
    Map<String, Task> byIdAll,
    TodoRepository repo,
  ) async {
    final l10n = AppLocalizations.of(context);
    switch (action) {
      case 'edit':
        openTaskEdit(context, taskId: task.id);
      case 'newSubtask':
        openTaskEdit(context, projectId: task.projectId, parentId: task.id);
      case 'moveUp':
        await _moveTask(task, childrenIndexAll, repo, -1, l10n);
      case 'moveDown':
        await _moveTask(task, childrenIndexAll, repo, 1, l10n);
      case 'indent':
        await _indentTask(task, childrenIndexAll, repo, l10n);
      case 'outdent':
        await _outdentTask(task, childrenIndexAll, byIdAll, repo, l10n);
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
    Map<String?, List<Task>> childrenIndexAll,
    TodoRepository repo,
    int direction,
    AppLocalizations l10n,
  ) async {
    // 兄弟列表基于**全量**索引（F2 修复：隐藏的 done 兄弟仍占位，否则
    // newIndex 相对可见集计算会插错位置）。
    final siblings = task.parentId == null
        ? (childrenIndexAll[null] ?? const <Task>[])
        : (childrenIndexAll[task.parentId] ?? const <Task>[]);
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
    Map<String?, List<Task>> childrenIndexAll,
    TodoRepository repo,
    AppLocalizations l10n,
  ) async {
    // 兄弟列表与子级计数基于**全量**索引（F2 修复，同 _moveTask）。
    final siblings = task.parentId == null
        ? (childrenIndexAll[null] ?? const <Task>[])
        : (childrenIndexAll[task.parentId] ?? const <Task>[]);
    final sortedSiblings = List<Task>.from(siblings)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final currentIndex = sortedSiblings.indexWhere((t) => t.id == task.id);
    if (currentIndex <= 0) return;

    // 新父级 = 上一个兄弟。
    final newParent = sortedSiblings[currentIndex - 1];
    final newParentChildren = childrenIndexAll[newParent.id] ?? const <Task>[];

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
    Map<String?, List<Task>> childrenIndexAll,
    Map<String, Task> byIdAll,
    TodoRepository repo,
    AppLocalizations l10n,
  ) async {
    if (task.parentId == null) return;

    final parent = byIdAll[task.parentId];
    if (parent == null) return;

    // 提升到父级的同级，排在父级之后（F2 修复：同级列表基于全量索引）。
    final grandparentChildren = parent.parentId == null
        ? (childrenIndexAll[null] ?? const <Task>[])
        : (childrenIndexAll[parent.parentId] ?? const <Task>[]);
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
