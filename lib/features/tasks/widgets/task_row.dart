import 'package:flutter/material.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/priority_color.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/motion.dart';
import '../../../shared/widgets/tag_chip.dart';
import '../../../shared/widgets/task_progress_ring.dart';

/// 任务行渲染形态（57-task-page-polish.md §4.2，D1/D7；61-task-list-redesign.md §4）。
///
/// - [TaskRowStyle.cardHeader]：一级任务大卡片的头部——无自身卡片底/阴影
///   （由外层大卡片提供），拖拽目标高亮态保留；
/// - [TaskRowStyle.compact]：卡片内紧凑子任务行——无卡片底、无分隔线，
///   紧凑间距 + 缩进（借鉴 TaskCreateSheet 行距节奏）。
enum TaskRowStyle { cardHeader, compact }

/// Task row — the core list item in project detail and task trees.
///
/// 扁平行式（61-task-list-redesign.md §2/§4）：任务行本身无独立卡片底/阴影，
/// 仅保留拖拽/悬停态叠加色；勾选框为**方形**并按层级着色（一级蓝、子级红）；
/// 元信息（描述/标签/日期）从标题同行改为标题下方独立行；子任务数 + 展开箭头
/// 移至行尾。
///
/// 用户打磨要求（override 61 §4.1/§4.5/§4.6）：
/// 1. 移除标题行右侧的派生状态小圆点（状态仍由 [derivedStatus] 传给勾选框）；
/// 2. 移除行尾「⋮」菜单按钮，同时**恢复整行长按拖拽**（LongPressDraggable
///    由 TaskTree 包整行，61 §4.6 语义）；行内菜单入口改为**桌面右键**
///    （InkWell.onSecondaryTap），移动端由「点击行 → 编辑页」承载
///    （编辑页内含新建子任务/删除；上移/下移/缩进/缩出由拖拽覆盖）。
/// 3. 键盘可达性取舍（用户已确认接受）：行菜单不再有键盘入口（键盘用户
///    的上移/下移/缩进/缩出仅能通过拖拽完成；LongPressDraggable 无设备
///    限制，桌面鼠标长按可拖拽调级）。
/// Supports drag-target highlight states for tree reordering.
class TaskRow extends StatefulWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.depth,
    required this.hasChildren,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onToggleDone,
    required this.onTap,
    required this.onMenuAction,
    this.style = TaskRowStyle.cardHeader,
    this.childCount = 0,
    this.incompleteChildCount = 0,
    this.tags = const [],
    this.derivedStatus,
    this.progressValue,
    this.isDragging = false,
    this.isDragTarget = false,
    this.isInvalidDragTarget = false,
    this.dropAsChild = false,
  });

  final Task task;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final ValueChanged<bool?> onToggleDone;
  final VoidCallback onTap;
  final void Function(String action) onMenuAction;
  final TaskRowStyle style;

  /// 直接子任务数量（61 §4.5：行尾「子任务数 + 展开箭头」）。
  final int childCount;

  /// 未完成直接子任务数（用户要求：行尾显示「未完成/总数」，如 2/5；
  /// 有子任务子行的有效状态按派生状态判定，仅 done 视为完成）。
  final int incompleteChildCount;

  final List<Tag> tags;
  final TaskStatus? derivedStatus;
  final double? progressValue;
  final bool isDragging;
  final bool isDragTarget;
  final bool isInvalidDragTarget;

  /// When true, drop would make dragged task a child of this row.
  final bool dropAsChild;

  @override
  State<TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<TaskRow> {
  bool _hovered = false;

  /// H 批（des-4 需求 2 减弱）：按压态仅保留几乎无感的轻微 scale
  /// （cardPressScaleSubtle 0.995），不再加深行底色。
  bool _pressed = false;

  /// 行背景（61 §2/§4.7）：扁平行无自身卡片底，透明底 + 仅拖拽/悬停态叠加色。
  Color _rowColor(ColorScheme colorScheme) {
    if (widget.isInvalidDragTarget) {
      return colorScheme.errorContainer.withValues(alpha: 0.4);
    }
    if (widget.isDragTarget) {
      return colorScheme.primaryContainer.withValues(alpha: 0.25);
    }
    if (widget.isDragging) {
      return colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    }
    if (_hovered) {
      // 扁平行：悬停给轻微底色反馈（替代卡片阴影抬升）。
      return colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    }
    return Colors.transparent;
  }

  /// 行内边距（61 §4.1；用户打磨要求 2/3/4 逐轮收紧）：左 [AppTokens.spaceXxs]、
  /// 右 [AppTokens.spaceXxs]、垂直 padding 为 0——单行行高由勾选框触控区
  /// （[AppTokens.checkboxTapTargetSize]=44）与标题行决定，视觉留白由触控区
  /// 内部空隙提供（视觉勾选框 24 在 44 触控区内居中，上下各 10px）；
  /// 多行任务（描述/标签/日期）高度自然撑开。子任务行按深度缩进
  /// [AppTokens.treeIndentLevel]（一级行深度恒 0 不缩进）。
  EdgeInsets _contentPadding() {
    final indent = widget.depth * AppTokens.treeIndentLevel;
    return switch (widget.style) {
      TaskRowStyle.cardHeader => const EdgeInsets.only(
        left: AppTokens.spaceXxs,
        right: AppTokens.spaceXxs,
      ),
      TaskRowStyle.compact => EdgeInsets.only(
        left: AppTokens.spaceXxs + indent,
        right: AppTokens.spaceXxs,
      ),
    };
  }

  /// 勾选框边框色（61 §4.2 层级着色）：完成 = 蓝填充白勾（边框被填充覆盖）；
  /// 未完成按深度着色——一级蓝 [AppTokens.colorInProgress]、子级红
  /// [AppTokens.colorPriorityHigh]。
  Color _checkboxBorderColor(bool isDone) {
    if (isDone) return AppTokens.checkboxDoneFill;
    return widget.depth == 0
        ? AppTokens.colorInProgress
        : AppTokens.colorPriorityHigh;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveStatus = widget.derivedStatus ?? widget.task.status;
    final hasDerived = widget.derivedStatus != null;
    final isDone = effectiveStatus == TaskStatus.done;

    final dateText = formatDateRange(
      widget.task.startAt,
      widget.task.endAt,
      l10n,
    );
    final relativeText = formatRelativeStart(widget.task.startAt, l10n);
    final rowRadius = widget.style == TaskRowStyle.compact
        ? AppTokens.radiusList
        : AppTokens.radiusCard;

    // 标题文本（优先级旗帜存在时与旗帜同行；strikethrough/弱色逻辑与
    // 改造前一致，maxLines 1 + ellipsis 保留）。
    final titleText = Text(
      widget.task.title,
      style: theme.textTheme.bodyLarge?.copyWith(
        decoration: isDone ? TextDecoration.lineThrough : null,
        color: isDone ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      // H 批（des-4 需求 2 减弱）：按压仅保留几乎无感的轻微 scale
      // （cardPressScaleSubtle 0.995）；抬手恢复。不改变点击/长按拖拽手势
      // （视觉变换不影响命中）。
      // mounted 守卫：整行拖拽时源行被 childWhenDragging 替换（dispose），
      // 指针 up/cancel 仍会路由到本 Listener，避免 setState after dispose。
      child: Listener(
        onPointerDown: (_) {
          if (mounted) setState(() => _pressed = true);
        },
        onPointerUp: (_) {
          if (mounted) setState(() => _pressed = false);
        },
        onPointerCancel: (_) {
          if (mounted) setState(() => _pressed = false);
        },
        child: AnimatedScale(
          scale: _pressed ? AppTokens.cardPressScaleSubtle : 1,
          duration: motionFast(context),
          curve: motionCurve(context),
          child: AnimatedContainer(
            duration: motionFast(context),
            curve: motionCurve(context),
            decoration: BoxDecoration(
              color: _rowColor(colorScheme),
              borderRadius: BorderRadius.circular(rowRadius),
              border: widget.isDragTarget
                  ? Border.all(
                      color: widget.isInvalidDragTarget
                          ? colorScheme.error
                          : colorScheme.primary,
                      width: 2,
                    )
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(rowRadius),
                onTap: widget.onTap,
                // 用户打磨要求（恢复整行拖拽）：行体**长按不再弹菜单**（与整行
                // LongPressDraggable 互斥，拖拽由 TaskTree 包整行触发）；
                // 菜单入口保留**桌面右键**（onSecondaryTap，与长按不冲突）。
                onSecondaryTap: () => _showMenu(context),
                child: Padding(
                  padding: _contentPadding(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: widget.style == TaskRowStyle.compact
                          ? AppTokens.taskRowCompactMinHeight
                          : AppTokens.taskRowMinHeight,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Checkbox（方形，61 §4.2；有子任务的子任务行禁用：
                        // 状态由父任务派生，Tooltip 解释原因，AGENTS.md §3-2 +
                        // NFR-06 语义）。触控区 = checkboxTapTargetSize（44，
                        // 用户打磨要求 4：单行行高压缩的权衡），视觉 24 居中。
                        // A 批：勾选/取消 scale 弹性脉冲（_CheckboxBounce），
                        // 勾线由 Material Checkbox 勾动画淡入。
                        SizedBox(
                          width: AppTokens.checkboxTapTargetSize,
                          height: AppTokens.checkboxTapTargetSize,
                          child: _CheckboxBounce(
                            isDone: isDone,
                            child: (!hasDerived || widget.task.parentId == null)
                                ? Checkbox(
                                    value: isDone,
                                    shape: AppTokens.checkboxShapeSquare,
                                    side: BorderSide(
                                      color: _checkboxBorderColor(isDone),
                                      width: 1.5,
                                    ),
                                    onChanged: widget.onToggleDone,
                                  )
                                : Tooltip(
                                    message: l10n.statusDerivedFromChildren,
                                    child: Checkbox(
                                      value: isDone,
                                      shape: AppTokens.checkboxShapeSquare,
                                      side: BorderSide(
                                        color: _checkboxBorderColor(isDone),
                                        width: 1.5,
                                      ),
                                      onChanged: null,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: AppTokens.spaceXxs),
                        // Title + description + tags + date（61 §4.1/§4.4）。
                        Expanded(
                          // 已完成 → 内容区整体淡化（勾选/行尾进度环/子任务数与
                          // 展开箭头保持全不透明，行仍可交互；strikethrough +
                          // onSurfaceVariant 保留）。
                          child: AnimatedOpacity(
                            opacity: isDone ? AppTokens.doneContentOpacity : 1,
                            duration: motionFast(context),
                            curve: motionCurve(context),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 用户打磨要求 1：移除派生状态小圆点（状态信息由
                                // 勾选框与进度环承载，标题行不再叠加状态图标）。
                                // 优先级旗帜（用户要求：与编辑器工具栏同一 flag
                                // 图标/配色）：有优先级时旗帜在标题左侧；无优先级
                                // 保持纯文本行布局（改造前）不变。
                                if (widget.task.priority != TaskPriority.none)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.flag_outlined,
                                        size: 14,
                                        color: priorityColor(
                                          widget.task.priority,
                                        ),
                                      ),
                                      const SizedBox(width: AppTokens.spaceXxs),
                                      Expanded(child: titleText),
                                    ],
                                  )
                                else
                                  titleText,
                                // 描述文字（61 §4.4）：标题下方灰色小字，有内容才显示。
                                if (widget.task.description.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppTokens.spaceXxs,
                                    ),
                                    child: Text(
                                      widget.task.description,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                // 日期行（61 §4.4）：标题下方独立行，日期范围灰色 +
                                // 相对时间（距开始 X 天）橙色强调。
                                if (dateText.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppTokens.spaceXxs,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_outlined,
                                          size: 11,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(
                                          width: AppTokens.spaceXxs,
                                        ),
                                        Expanded(
                                          child: Text(
                                            dateText,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (relativeText.isNotEmpty) ...[
                                          const SizedBox(
                                            width: AppTokens.spaceXs,
                                          ),
                                          Text(
                                            relativeText,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: AppTokens
                                                      .colorDateRelative,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                // 标签 chips（61 §4.4）：底部独立行（≤2 + +N）。
                                // 底部对称留白（用户要求）：bottom = top = spaceXxs，
                                // 与行内元信息行间距节奏一致（行/卡片底部不再贴边）。
                                // 每个 chip 用 Flexible 包住，使其成为内层 Row 的
                                // 可收缩子项：NFR-06 字体缩放下按份额收缩，Text 的
                                // maxLines + ellipsis 真正生效。
                                if (widget.tags.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppTokens.spaceXxs,
                                    ),
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ...widget.tags
                                                  .take(2)
                                                  .map(
                                                    (tag) => Flexible(
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              right: AppTokens
                                                                  .spaceXxs,
                                                            ),
                                                        child: TagChip(
                                                          tag: tag,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              if (widget.tags.length > 2)
                                                Text(
                                                  '+${widget.tags.length - 2}',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // Progress ring（61 §4.4：行尾，子任务数左侧）。
                        if (widget.progressValue != null &&
                            widget.hasChildren) ...[
                          TaskProgressRing(value: widget.progressValue!),
                          const SizedBox(width: AppTokens.spaceXs),
                        ],
                        // 子任务数 + 展开箭头（61 §4.5：行尾、菜单左侧；无子任务
                        // 不显示）。展开 = 箭头朝下（turns 0.25），折叠 = 朝右。
                        if (widget.hasChildren) ...[
                          Semantics(
                            // 无障碍（NFR-06）：纯图标按钮补语义标签（展开/收起）。
                            button: true,
                            label: widget.isExpanded
                                ? l10n.collapse
                                : l10n.expand,
                            child: GestureDetector(
                              // 评审修复 2：ConstrainedBox 恢复最小 32×32 触控区
                              //（改造前固定 28×28），opaque 使透明区也响应点击；
                              // Row 自身尺寸不变 → 不改变行尾对齐布局。
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onToggleExpand,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: AppTokens.expandTapTargetSize,
                                  minHeight: AppTokens.expandTapTargetSize,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${widget.incompleteChildCount}/${widget.childCount}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(width: AppTokens.spaceXxs),
                                    AnimatedRotation(
                                      turns: widget.isExpanded ? 0.25 : 0,
                                      duration: motionFast(context),
                                      curve: motionCurve(context),
                                      child: Icon(
                                        Icons.arrow_right,
                                        size: AppTokens.expandArrowSizeRow,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTokens.spaceXxs),
                        ],
                        // Drop-as-child indicator.
                        if (widget.isDragTarget &&
                            widget.dropAsChild &&
                            !widget.isInvalidDragTarget)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: AppTokens.spaceXxs,
                            ),
                            child: Icon(
                              Icons.subdirectory_arrow_right,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusDialog),
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppTokens.spaceXs),
            ListTile(
              leading: const Icon(Icons.edit, size: 20),
              title: Text(l10n.edit),
              onTap: () {
                Navigator.pop(context);
                widget.onMenuAction('edit');
              },
            ),
            if (widget.depth < 2)
              ListTile(
                leading: const Icon(Icons.subdirectory_arrow_right, size: 20),
                title: Text(l10n.newSubtask),
                onTap: () {
                  Navigator.pop(context);
                  widget.onMenuAction('newSubtask');
                },
              ),
            ListTile(
              leading: const Icon(Icons.arrow_upward, size: 20),
              title: Text(l10n.moveUp),
              onTap: () {
                Navigator.pop(context);
                widget.onMenuAction('moveUp');
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward, size: 20),
              title: Text(l10n.moveDown),
              onTap: () {
                Navigator.pop(context);
                widget.onMenuAction('moveDown');
              },
            ),
            if (widget.depth < 2)
              ListTile(
                leading: const Icon(Icons.arrow_right, size: 20),
                title: Text(l10n.indent),
                onTap: () {
                  Navigator.pop(context);
                  widget.onMenuAction('indent');
                },
              ),
            if (widget.depth > 0)
              ListTile(
                leading: const Icon(Icons.arrow_left, size: 20),
                title: Text(l10n.outdent),
                onTap: () {
                  Navigator.pop(context);
                  widget.onMenuAction('outdent');
                },
              ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.delete_outlined,
                size: 20,
                color: colorScheme.error,
              ),
              title: Text(
                l10n.delete,
                style: TextStyle(color: colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onMenuAction('delete');
              },
            ),
            const SizedBox(height: AppTokens.spaceXs),
          ],
        ),
      ),
    );
  }
}

/// 勾选弹性（docs/63-motion-polish.md §5 A）：完成态变化时对勾选框做一次
/// scale 脉冲——勾选 1 → [AppTokens.checkboxBounceScale] → 1，取消
/// 1 → [AppTokens.checkboxBounceShrink] → 1（TweenSequence 关键帧，
/// 段内曲线 [motionBounceCurve]，时长 [motionFast]）；
/// reduced motion：时长归零 → 瞬时到位（不缩放）。
class _CheckboxBounce extends StatefulWidget {
  const _CheckboxBounce({required this.isDone, required this.child});

  final bool isDone;
  final Widget child;

  @override
  State<_CheckboxBounce> createState() => _CheckboxBounceState();
}

class _CheckboxBounceState extends State<_CheckboxBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scale;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _scale = Tween<double>(begin: 1.0, end: 1.0).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    _controller.duration = motionFast(context);
    // 首帧不播放（避免进列表就弹一下）。
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _CheckboxBounce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDone == widget.isDone) return;
    if (_controller.duration == Duration.zero) {
      // reduced：瞬时到位。
      _controller.value = 1.0;
      return;
    }
    final bounce = motionBounceCurve(context);
    if (widget.isDone) {
      // 勾选：放大回弹。
      _scale = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: 1.0,
            end: AppTokens.checkboxBounceScale,
          ).chain(CurveTween(curve: bounce)),
          weight: 55,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: AppTokens.checkboxBounceScale,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 45,
        ),
      ]).animate(_controller);
    } else {
      // 取消完成：缩小回弹。
      _scale = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(
            begin: 1.0,
            end: AppTokens.checkboxBounceShrink,
          ).chain(CurveTween(curve: bounce)),
          weight: 55,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: AppTokens.checkboxBounceShrink,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 45,
        ),
      ]).animate(_controller);
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
