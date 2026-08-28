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
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/staggered_fade_slide.dart';
import '../../projects/project_providers.dart';
import '../task_edit_page.dart';
import '../task_providers.dart';
import 'task_row.dart';

/// 任务树组件（50-ui-ux.md §5.3；57-task-page-polish.md §4.2 批 2 卡片化）。
///
/// 项目作用域结构（D1）：
/// - **一级任务 = 大卡片**（白卡 `surfaceCard` + `radiusCard` + 轻阴影，默认展开 D3）；
///   卡片头部 = [TaskRow]（`cardHeader` 形态）：勾选、标题、标签 chips、时间、
///   进度环、展开/折叠箭头、行菜单。
/// - 展开区（卡片内缩进区，Divider 分隔紧凑行 D7）：二级任务 = [TaskRow]（`compact`
///   形态，借鉴 TaskCreateSheet 行距节奏）；二级有子任务时再缩进展开至 3 级。
///
/// 拖拽（D2 完整保留）：一级卡片头长按拖拽同级排序；卡片内子任务行长按拖拽
/// 排序/调级/回 1 级。`_rowKeys` 覆盖两类行（卡片头 + 内部子行），上下半命中判定
/// （`_dropAsChild`）、`_fitsDepthLimit` 深度校验、防环、非法目标红色高亮、回弹
/// 提示全部沿用；`onAccept` 仍调 `repo.moveTask`。
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

  /// H 批：一级卡片是否处于按压态（阴影抬升 + 轻微 scale 0.98）。
  bool _cardPressed = false;

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
        // 隐藏已完成任务（会话级，用户要求）：按**递归有效状态**过滤——叶子
        // 看自身 status，有子任务的**整棵子树**全部递归 done 才隐藏（F1 修复：
        // 避免「A 存储 done 但有未完成子任务」时父级被隐藏导致可见子树悬空）。
        // 在 treeNodes / 计数 / 拖拽逻辑之前过滤，整棵可见树保持一致。
        final hideDone = ref.watch(hideCompletedTasksProvider);
        final visibleTasks = hideDone
            ? _filterDoneTasks(tasks, childrenIndexAll)
            : tasks;
        if (visibleTasks.isEmpty) {
          // 任务存在但全部被隐藏（hide ON 且全部已完成）→ 专用空态，
          // 与「还没有任务」（tasks.isEmpty）区分（F4）。
          _rowKeys.clear();
          return EmptyState(
            icon: Icons.check_circle_outline,
            message: l10n.allTasksCompleted,
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
            // 66 §6 留白节奏统一：列表水平 padding 回归 spaceMd=16，
            // 与今日/搜索/设置等页面共用同一内容横距（覆盖此前 8 的旧决策）。
            horizontal: AppTokens.spaceMd,
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

  /// 一级任务大卡片（D1）：卡片头 + 展开区（Divider 分隔的紧凑子任务行）。
  ///
  /// 卡片容器提供白卡底/圆角/轻阴影；卡片头与内部子行均为独立拖拽源
  /// （各包自己的 DragTarget，几何不重叠 → 命中互不干扰）。
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
    final children = childrenOf[rootNode.task.id] ?? const <TreeNode>[];

    return Padding(
      // 用户打磨要求 4：一级卡片底部间距 spaceXxs→spaceXs，
      // 与卡片↔屏幕左右边缘距离（列表水平 padding spaceXs）相等。
      padding: const EdgeInsets.only(bottom: AppTokens.spaceXs),
      // H 批（des-4 需求 2 减弱）：卡片按压仅保留**几乎无感**的轻微 scale
      // （cardPressScaleSubtle 0.998），去掉阴影抬升；motionFast + motionCurve，
      // 抬手恢复，不影响点击/拖拽。这是卡片按压缩放的**唯一一层**——行内层
      // 的同款 scale 仅对 compact 子行生效，避免双层叠加体感明显。
      child: Listener(
        onPointerDown: (_) {
          if (mounted) setState(() => _cardPressed = true);
        },
        onPointerUp: (_) {
          if (mounted) setState(() => _cardPressed = false);
        },
        onPointerCancel: (_) {
          if (mounted) setState(() => _cardPressed = false);
        },
        child: AnimatedScale(
          scale: _cardPressed ? AppTokens.cardPressScaleSubtle : 1,
          duration: motionFast(context),
          curve: motionCurve(context),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCard,
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              border: Border.all(
                color: isDark
                    ? AppTokens.borderSubtleDark
                    : AppTokens.borderSubtleLight,
                width: 1.0,
              ),
              boxShadow: isDark
                  ? AppTokens.cardShadowDarkList
                  : AppTokens.cardShadowLight,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
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
                  // 用户打磨要求 2：去掉子行间 Divider（行间靠间距区分）。
                  // des-4 需求 3 + 评审 #3：**唯一**的 AnimatedSize 高度过渡层
                  // （motionNormal + motionCurve，clip 使行随高度渐进露出）。
                  // 任意层级（一级展开/孙级展开或折叠）的高度变化都经本层
                  // 动画（RenderAnimatedSize 在子级尺寸变化时自动重启动画），
                  // 内层不再重复包 AnimatedSize；子行不叠加自身动画，随容器
                  // 自上而下揭示（与侧边栏文件夹展开观感一致）。
                  AnimatedSize(
                    duration: motionNormal(context),
                    curve: motionCurve(context),
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.hardEdge,
                    child: rootNode.isExpanded && children.isNotEmpty
                        ? _buildChildrenSection(
                            context,
                            children,
                            childrenOf,
                            repo,
                            expandState,
                            childrenIndexAll: childrenIndexAll,
                            byIdAll: byIdAll,
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 卡片展开区：紧凑子任务行（用户打磨要求 2：无 Divider，行间靠间距
  /// 区分），有子任务的子行递归缩进展开（至 3 级）。
  ///
  /// 子行**不自带**逐项动画：高度过渡由卡片级（[_buildCard]）那一个
  /// [AnimatedSize] 统一承担，子行随容器自上而下揭示（与侧边栏文件夹
  /// 展开观感一致）；折叠时子行瞬时移除、高度快速收起。reduced motion
  /// 全瞬时。
  ///
  /// **高度过渡只有一层**（评审 #3 清理）：本方法不再内包 [AnimatedSize]，
  /// 由卡片级那一个 AnimatedSize 统一承担——`RenderAnimatedSize`
  /// 在**子级尺寸变化**时（`_layoutStable` 检测 `child.size != 目标`）会自动
  /// 重启动画追平新高度，因此**任意层级**（一级展开/孙级展开或折叠）的高度
  /// 变化都被卡片级外层覆盖；内层若再包一个，仅在顶层展开后重建时是新建的
  Widget _buildChildrenSection(
    BuildContext context,
    List<TreeNode> children,
    Map<String, List<TreeNode>> childrenOf,
    TodoRepository repo,
    Map<String, bool> expandState, {
    required Map<String?, List<Task>> childrenIndexAll,
    required Map<String, Task> byIdAll,
    int depth = 1,
    List<double> ancestorTrunks = const [],
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final lineColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : colorScheme.outlineVariant.withValues(alpha: 0.75);

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
            lineColor: lineColor,
            depth: depth,
            ancestorTrunks: ancestorTrunks,
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
    required Color lineColor,
    required int depth,
    required List<double> ancestorTrunks,
  }) {
    final isLast = index == total - 1;
    final grandChildren = childrenOf[childNode.task.id];
    final hasGrandChildren =
        childNode.isExpanded && (grandChildren?.isNotEmpty ?? false);

    // 局部坐标系中：
    // 当前主干垂线 X = 26.0（与父级复选框中心垂直共线）
    // 当前分支引线终止 X = 45.0（直达子任务 18×18 复选框左侧外边框）
    // 递归下级（孙任务）时：如果当前不是最后兄弟项，在下级局部坐标 X = -2.0 处绘制贯穿线（-2.0 + 28.0 = 26.0）
    const localTrunkX = 26.0;
    const localTargetBranchEndX = 45.0;
    final nextAncestorTrunks = isLast ? <double>[] : <double>[-2.0];

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _SubtaskTreeConnectorPainter(
              color: lineColor,
              isLast: isLast,
              ancestorTrunks: ancestorTrunks,
              currentTrunkX: localTrunkX,
              targetBranchEndX: localTargetBranchEndX,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 28.0),
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
                _buildChildrenSection(
                  context,
                  grandChildren!,
                  childrenOf,
                  repo,
                  expandState,
                  childrenIndexAll: childrenIndexAll,
                  byIdAll: byIdAll,
                  depth: depth + 1,
                  ancestorTrunks: nextAncestorTrunks,
                ),
            ],
          ),
        ),
      ],
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

/// 子任务树状层级极细浅色引导线 Painter（Linear / Things 3 极简风格）
class _SubtaskTreeConnectorPainter extends CustomPainter {
  const _SubtaskTreeConnectorPainter({
    required this.color,
    required this.isLast,
    required this.ancestorTrunks,
    required this.currentTrunkX,
    required this.targetBranchEndX,
  });

  final Color color;
  final bool isLast;
  final List<double> ancestorTrunks;
  final double currentTrunkX;
  final double targetBranchEndX;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const branchY = 22.0; // 严格对准复选框 44 触控区垂直中线 22.0

    // 1. 绘制祖先节点的连续贯穿竖线
    for (final trunkX in ancestorTrunks) {
      canvas.drawLine(Offset(trunkX, 0), Offset(trunkX, size.height), paint);
    }

    // 2. 绘制当前节点的主干线与分支线
    final trunkX = currentTrunkX;
    final endX = targetBranchEndX;

    final path = Path();
    path.moveTo(trunkX, 0);
    if (isLast) {
      path.lineTo(trunkX, branchY - 6);
      path.quadraticBezierTo(trunkX, branchY, trunkX + 6, branchY);
      path.lineTo(endX, branchY);
      canvas.drawPath(path, paint);
    } else {
      path.lineTo(trunkX, size.height);
      canvas.drawPath(path, paint);

      final branchPath = Path()
        ..moveTo(trunkX, branchY - 6)
        ..quadraticBezierTo(trunkX, branchY, trunkX + 6, branchY)
        ..lineTo(endX, branchY);
      canvas.drawPath(branchPath, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SubtaskTreeConnectorPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.isLast != isLast ||
      oldDelegate.currentTrunkX != currentTrunkX ||
      oldDelegate.targetBranchEndX != targetBranchEndX ||
      oldDelegate.ancestorTrunks != ancestorTrunks;
}
