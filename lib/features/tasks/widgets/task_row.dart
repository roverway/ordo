import 'task_row_actions_sheet.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/priority_color.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/motion.dart';
import '../../../shared/widgets/animated_strikethrough.dart';
import '../../../shared/widgets/modern_checkbox.dart';

/// 任务行渲染形态（57-task-page-polish.md §4.2，D1/D7；61-task-list-redesign.md §4）。
///
/// - [TaskRowStyle.cardHeader]：一级任务大卡片的头部——无自身卡片底/阴影
///   （由外层大卡片提供），拖拽目标高亮态保留；
/// - [TaskRowStyle.compact]：卡片内紧凑子任务行——无卡片底、无分割线，
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
    this.projectName,
    this.projectColor,
    this.collapseOnDone = false,
    this.derivedStatus,
    this.progressValue,
    this.isDragging = false,
    this.isDragTarget = false,
    this.isInvalidDragTarget = false,
    this.dropAsChild = false,
    this.isSelected = false,
  });

  final bool isSelected;
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
  final String? projectName;
  final int? projectColor;
  final bool collapseOnDone;
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

class _TaskRowState extends State<TaskRow> with SingleTickerProviderStateMixin {
  final ValueNotifier<bool> _hoveredNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _pressedNotifier = ValueNotifier<bool>(false);

  late bool _isLocallyDone;
  Timer? _graceTimer;
  late final AnimationController _collapseController;
  late final Animation<double> _collapseFactor;

  @override
  void initState() {
    super.initState();
    final effectiveStatus = widget.derivedStatus ?? widget.task.status;
    _isLocallyDone = effectiveStatus == TaskStatus.done;
    _collapseController = AnimationController(
      vsync: this,
      duration: AppTokens.motionCollapse,
    );
    _collapseFactor = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _collapseController,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant TaskRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldEffective = oldWidget.derivedStatus ?? oldWidget.task.status;
    final newEffective = widget.derivedStatus ?? widget.task.status;
    if (oldEffective != newEffective) {
      _graceTimer?.cancel();
      _graceTimer = null;
      _isLocallyDone = newEffective == TaskStatus.done;
      _collapseController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _graceTimer?.cancel();
    _collapseController.dispose();
    _hoveredNotifier.dispose();
    _pressedNotifier.dispose();
    super.dispose();
  }

  void _handleToggle(bool? val) {
    final targetDone = val ?? !_isLocallyDone;

    if (targetDone) {
      HapticFeedback.lightImpact();
      setState(() => _isLocallyDone = true);
      if (widget.collapseOnDone) {
        _graceTimer?.cancel();
        _graceTimer = Timer(AppTokens.motionDoneGracePeriod, () {
          if (mounted) {
            _collapseController.forward().then((_) {
              if (mounted) {
                widget.onToggleDone(true);
              }
            });
          }
        });
      } else {
        widget.onToggleDone(true);
      }
    } else {
      _graceTimer?.cancel();
      _graceTimer = null;
      _collapseController.value = 0.0;
      setState(() => _isLocallyDone = false);
      widget.onToggleDone(false);
    }
  }

  /// 行背景（61 §2/§4.7）：扁平行无自身卡片底，透明底 + 仅拖拽/悬停态叠加色。
  Color _rowColor(ColorScheme colorScheme, bool hovered) {
    if (widget.isInvalidDragTarget) {
      return colorScheme.errorContainer.withValues(
        alpha: AppTokens.alphaContentDisabled,
      );
    }
    if (widget.isDragTarget) {
      return colorScheme.primaryContainer.withValues(
        alpha: AppTokens.alphaBorderEmphasis,
      );
    }
    if (widget.isDragging) {
      return colorScheme.surfaceContainerHighest.withValues(
        alpha: AppTokens.alphaContentMuted,
      );
    }
    if (widget.isSelected) {
      return colorScheme.primary.withValues(alpha: AppTokens.alphaTintSoft);
    }
    if (hovered) {
      // 扁平行：悬停给轻微底色反馈（替代卡片阴影提升）。
      return colorScheme.surfaceContainerHighest.withValues(
        alpha: AppTokens.alphaContentDisabled,
      );
    }
    return Colors.transparent;
  }

  /// 行内边距（61 §4.1；用户打磨要求 2/3/4 逐轮收紧）：左 [AppTokens.spaceXxs]、
  /// 右 [AppTokens.spaceXxs]、垂直 padding 为 0——单行行高由勾选框触控区
  /// （[AppTokens.checkboxTapTargetSize]=44）与标题行决定，视觉留白由触控区
  /// 内部空隙提供（视觉勾选框 24 在 44 触控区内居中，上下各 10px）；
  /// 多行任务（描述/标签/日期）高度自然撑开。子任务行按深度缩进
  /// [AppTokens.treeIndentLevel]（一级行深度恒 0 不缩进）。
  /// 行内边距：左 [AppTokens.spaceXxs]、右 [AppTokens.spaceXxs]、垂直 padding 为 0。
  /// 层级缩进由外部 TaskTree 的树状连接器统一提供。
  EdgeInsets _contentPadding() {
    return const EdgeInsets.symmetric(vertical: 10);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final hasDerived = widget.derivedStatus != null;
    final isDone = _isLocallyDone;

    final dateText = formatDateRange(
      widget.task.startAt,
      widget.task.endAt,
      l10n,
    );
    final relativeText = formatRelativeStart(widget.task.startAt, l10n);
    final now = DateTime.now();
    final todayStartMs = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final isOverdue =
        widget.task.endAt != null &&
        widget.task.endAt! < todayStartMs &&
        !isDone;
    final rowRadius = widget.style == TaskRowStyle.compact
        ? AppTokens.radiusList
        : AppTokens.radiusCard;

    final (
      titleFontSize,
      titleFontWeight,
      titleFontColor,
    ) = switch (widget.depth) {
      0 => (
        AppTokens.textTaskL1Size,
        AppTokens.textTaskL1Weight,
        isDone ? colorScheme.onSurface : colorScheme.onSurface,
      ),
      1 => (
        AppTokens.textTaskL2Size,
        AppTokens.textTaskL2Weight,
        isDone
            ? colorScheme.onSurfaceVariant
            : (isDark
                  ? Colors.white.withValues(alpha: AppTokens.alphaOverlayHeavy)
                  : colorScheme.onSurface.withValues(
                      alpha: AppTokens.alphaOverlayHeavy,
                    )),
      ),
      _ => (
        AppTokens.textTaskL3Size,
        AppTokens.textTaskL3Weight,
        isDone
            ? colorScheme.onSurfaceVariant
            : (isDark
                  ? Colors.white.withValues(alpha: AppTokens.alphaOverlayHeavy)
                  : colorScheme.onSurface.withValues(
                      alpha: AppTokens.alphaOverlayHeavy,
                    )),
      ),
    };

    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: titleFontSize,
      fontWeight: titleFontWeight,
      color: isDone ? colorScheme.onSurfaceVariant : titleFontColor,
    );
    final titleText = AnimatedStrikethrough(
      text: widget.task.title,
      isDone: isDone,
      style: titleStyle,
      maxLines: null,
      overflow: TextOverflow.clip,
    );
    final titleLineHeight =
        MediaQuery.textScalerOf(context).scale(titleFontSize) *
        (titleStyle?.height ?? AppTokens.textBodyHeight);
    final titleTopPad = (AppTokens.checkboxTapTargetSize - titleLineHeight) / 2;

    final hasDescription = widget.task.description.isNotEmpty;
    final hasDate = dateText.isNotEmpty;
    final hasTags = widget.tags.isNotEmpty;
    final hasMeta = hasDescription || hasDate || hasTags;

    return FadeTransition(
      opacity: _collapseFactor,
      child: SizeTransition(
        sizeFactor: _collapseFactor,
        axisAlignment: -1.0,
        child: MouseRegion(
          onEnter: (_) {
            if (mounted) _hoveredNotifier.value = true;
          },
          onExit: (_) {
            if (mounted) _hoveredNotifier.value = false;
          },
          child: Listener(
            onPointerDown: (_) {
              if (mounted) _pressedNotifier.value = true;
            },
            onPointerUp: (_) {
              if (mounted) _pressedNotifier.value = false;
            },
            onPointerCancel: (_) {
              if (mounted) _pressedNotifier.value = false;
            },
            child: ListenableBuilder(
              listenable: Listenable.merge([
                _pressedNotifier,
                _hoveredNotifier,
              ]),
              builder: (context, _) {
                return AnimatedScale(
                  scale:
                      (_pressedNotifier.value &&
                          widget.style == TaskRowStyle.compact)
                      ? AppTokens.cardPressScaleSubtle
                      : 1,
                  duration: motionFast(context),
                  curve: motionCurve(context),
                  child: AnimatedContainer(
                    duration: motionFast(context),
                    curve: motionCurve(context),
                    decoration: BoxDecoration(
                      color: _rowColor(colorScheme, _hoveredNotifier.value),
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
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Checkbox（ModernCheckbox：有子任务的任务禁用勾选：
                              // 状态由直接子任务派生，Tooltip 解释原因，AGENTS.md §3-2 +
                              // NFR-06 语义）。触控区 = checkboxTapTargetSize（28），视觉 20/22 居中。
                              !hasDerived
                                  ? ModernCheckbox(
                                      checked: isDone,
                                      onChanged: (val) => _handleToggle(val),
                                      size: widget.style == TaskRowStyle.compact
                                          ? 20
                                          : 22,
                                      tapTargetSize:
                                          AppTokens.checkboxTapTargetSize,
                                    )
                                  : Tooltip(
                                      message: l10n.statusDerivedFromChildren,
                                      child: ModernCheckbox(
                                        checked: isDone,
                                        onChanged: null,
                                        size:
                                            widget.style == TaskRowStyle.compact
                                            ? 20
                                            : 22,
                                        tapTargetSize:
                                            AppTokens.checkboxTapTargetSize,
                                      ),
                                    ),
                              const SizedBox(
                                width: AppTokens.checkboxToTitleGap,
                              ),
                              // Title + description + tags + date（61 §4.1/§4.4）。
                              Expanded(
                                // 已完成 → 内容区整体淡化（勾选/行尾进度环/子任务数与
                                // 展开箭头保持全不透明，行仍可交互；strikethrough +
                                // onSurfaceVariant 保留）。
                                child: AnimatedOpacity(
                                  opacity: isDone
                                      ? AppTokens.doneContentOpacity
                                      : 1,
                                  duration: motionFast(context),
                                  curve: motionCurve(context),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 标题首行：计算留白使首行文本中心与复选框中心严格重合
                                      Padding(
                                        padding: EdgeInsets.only(
                                          top: titleTopPad.clamp(0.0, 8.0),
                                          bottom: hasMeta
                                              ? AppTokens.spaceXxs
                                              : titleTopPad.clamp(0.0, 8.0),
                                        ),
                                        child:
                                            widget.task.priority !=
                                                TaskPriority.none
                                            ? Row(
                                                // 旗帜与标题**首行**行内对齐：start 对齐 +
                                                // 首行行高居中补偿——标题折行时旗帜仍与
                                                // 首行/复选框对齐，而非相对整块垂直居中。
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Padding(
                                                    padding: EdgeInsets.only(
                                                      top:
                                                          (titleLineHeight -
                                                              14) /
                                                          2,
                                                    ),
                                                    child: Icon(
                                                      Icons.flag_outlined,
                                                      size: 14,
                                                      color: priorityColor(
                                                        widget.task.priority,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                    width: AppTokens.spaceXxs,
                                                  ),
                                                  Expanded(child: titleText),
                                                ],
                                              )
                                            : titleText,
                                      ),
                                      // 描述文字
                                      if (hasDescription)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                            bottom: AppTokens.spaceXxs,
                                          ),
                                          child: Text(
                                            widget.task.description,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                  fontSize:
                                                      AppTokens.textCaptionSize,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      // 统一元数据行（所属项目圆点 -> Linear 风格 #标签 -> 时间）
                                      if (widget.projectName != null ||
                                          widget.tags.isNotEmpty ||
                                          dateText.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Opacity(
                                            opacity: isDone
                                                ? AppTokens.alphaContentMuted
                                                : 1.0,
                                            child: Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              children: [
                                                // 1. 所属项目（带 7dp 项目色圆点）
                                                if (widget.projectName !=
                                                        null &&
                                                    widget
                                                        .projectName!
                                                        .isNotEmpty)
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: AppTokens
                                                            .projectDotSize,
                                                        height: AppTokens
                                                            .projectDotSize,
                                                        decoration: BoxDecoration(
                                                          color: Color(
                                                            widget.projectColor ??
                                                                AppTokens
                                                                    .seedColor
                                                                    .toARGB32(),
                                                          ),
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        widget.projectName!,
                                                        style: theme
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: colorScheme
                                                                  .onSurfaceVariant,
                                                              fontSize: AppTokens
                                                                  .textCaptionSize,
                                                            ),
                                                      ),
                                                    ],
                                                  ),

                                                // 2. Linear 风格 #标签（带微色底极细微胶囊）
                                                for (final tag
                                                    in widget.tags.take(3))
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 5,
                                                          vertical: 1,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Color(tag.color)
                                                          .withValues(
                                                            alpha: AppTokens
                                                                .alphaTintSoft,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            AppTokens
                                                                .radiusMicro,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          '#',
                                                          style: TextStyle(
                                                            color:
                                                                Color(
                                                                  tag.color,
                                                                ).withValues(
                                                                  alpha: AppTokens
                                                                      .alphaHashPrefix,
                                                                ),
                                                            fontSize: AppTokens
                                                                .textMicroSize,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                        Text(
                                                          tag.name,
                                                          style: TextStyle(
                                                            color: Color(
                                                              tag.color,
                                                            ),
                                                            fontSize: AppTokens
                                                                .textMicroSize,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                // 3. 结构化时间（tabular 数字字体，逾期自动标红）
                                                if (dateText.isNotEmpty)
                                                  Text(
                                                    dateText,
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: isOverdue
                                                              ? AppTokens
                                                                    .colorOverdue
                                                              : colorScheme
                                                                    .onSurfaceVariant,
                                                          fontSize: AppTokens
                                                              .textCaptionSize,
                                                          fontWeight: isOverdue
                                                              ? FontWeight.w600
                                                              : FontWeight.w400,
                                                          fontFeatures:
                                                              AppTokens
                                                                  .fontTabular,
                                                        ),
                                                  ),

                                                // 4. 相对时间（橙色强调）
                                                if (relativeText.isNotEmpty)
                                                  Text(
                                                    relativeText,
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: AppTokens
                                                              .colorDateRelative,
                                                          fontSize: AppTokens
                                                              .textCaptionSize,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              // 行尾组件：与首行 Checkbox 保持相同高度垂直居中
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: AppTokens.checkboxTapTargetSize,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // 子任务数 + 展开箭头（61 §4.5：行尾、菜单左侧；无子任务
                                    // 不显示）。展开 = 箭头朝下（turns 0.25），折叠 = 朝右。
                                    if (widget.hasChildren) ...[
                                      Semantics(
                                        button: true,
                                        label: widget.isExpanded
                                            ? l10n.collapse
                                            : l10n.expand,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: widget.onToggleExpand,
                                          child: ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              minWidth:
                                                  AppTokens.expandTapTargetSize,
                                              minHeight:
                                                  AppTokens.expandTapTargetSize,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '${widget.incompleteChildCount}/${widget.childCount}',
                                                  style: TextStyle(
                                                    fontSize:
                                                        AppTokens.textMicroSize,
                                                    fontFeatures:
                                                        AppTokens.fontTabular,
                                                    color: colorScheme
                                                        .onSurfaceVariant
                                                        .withValues(
                                                          alpha: AppTokens
                                                              .alphaScrim,
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 3),
                                                AnimatedRotation(
                                                  turns: widget.isExpanded
                                                      ? 0.25
                                                      : 0,
                                                  duration: motionFast(context),
                                                  curve: motionCurve(context),
                                                  child: Icon(
                                                    Icons.chevron_right,
                                                    size: 16,
                                                    color: colorScheme
                                                        .onSurfaceVariant
                                                        .withValues(
                                                          alpha: AppTokens
                                                              .alphaScrim,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppTokens.spaceXxs),
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showTaskRowActionsSheet(
      context: context,
      depth: widget.depth,
      onMenuAction: widget.onMenuAction,
    );
  }
}
