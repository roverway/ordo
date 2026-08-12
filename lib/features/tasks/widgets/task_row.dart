import 'package:flutter/material.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/dates.dart';
import '../../../shared/widgets/task_progress_ring.dart';

/// 任务行渲染形态（57-task-page-polish.md §4.2，D1/D7）。
///
/// - [TaskRowStyle.cardHeader]：一级任务大卡片的头部——无自身卡片底/阴影
///   （由外层大卡片提供），拖拽目标高亮态保留；
/// - [TaskRowStyle.compact]：卡片内紧凑子任务行——无卡片底，Divider 分隔，
///   紧凑间距 + 缩小缩进（借鉴 TaskCreateSheet 行距节奏）。
enum TaskRowStyle { cardHeader, compact }

/// Task row — the core list item in project detail and task trees.
///
/// TickTick-inspired: clean circular checkbox, soft colors, subtle metadata row.
/// 卡片化（M5 批 1）：白卡片 + 圆角 16 + 轻阴影，hover 轻微抬升；
/// 视觉与 `SimpleTaskTile` 统一（55-ui-redesign-proposal.md §6）。
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

  Color _statusColor(TaskStatus status, ColorScheme colorScheme) =>
      switch (status) {
        TaskStatus.done => AppTokens.colorDone,
        TaskStatus.inProgress => AppTokens.colorInProgress,
        TaskStatus.cancelled => AppTokens.colorCancelled,
        TaskStatus.todo => colorScheme.outline,
      };

  /// 行背景：卡片头/紧凑行无自身卡片底（透明，卡片底由外层容器提供），
  /// 仅拖拽目标/拖拽中/悬停态以叠加色替代。
  Color _cardColor(ColorScheme colorScheme, bool isDark) {
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
      // 无卡片底的行：悬停给轻微底色反馈（替代抬升阴影）。
      return colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    }
    return isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCard;
  }

  /// 行内边距：紧凑行用 [AppTokens.treeIndentCompact] 缩进，头部行对齐卡片
  /// 内容区（[AppTokens.spaceMd]），无魔法值。
  EdgeInsets _contentPadding() {
    final indent =
        widget.depth *
        (widget.style == TaskRowStyle.compact
            ? AppTokens.treeIndentCompact
            : AppTokens.treeIndent);
    return switch (widget.style) {
      TaskRowStyle.cardHeader => EdgeInsets.only(
        left: AppTokens.spaceMd,
        right: AppTokens.spaceXxs,
        top: AppTokens.spaceSm,
        bottom: AppTokens.spaceXs,
      ),
      TaskRowStyle.compact => EdgeInsets.only(
        left: AppTokens.spaceMd + indent,
        right: AppTokens.spaceXxs,
        top: AppTokens.spaceXxs,
        bottom: AppTokens.spaceXxs,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final effectiveStatus = widget.derivedStatus ?? widget.task.status;
    final hasDerived = widget.derivedStatus != null;
    final isDone = effectiveStatus == TaskStatus.done;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppTokens.motionFast,
        decoration: BoxDecoration(
          color: _cardColor(colorScheme, isDark),
          borderRadius: BorderRadius.circular(
            widget.style == TaskRowStyle.compact
                ? AppTokens.radiusList
                : AppTokens.radiusCard,
          ),
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
            borderRadius: BorderRadius.circular(
              widget.style == TaskRowStyle.compact
                  ? AppTokens.radiusList
                  : AppTokens.radiusCard,
            ),
            onTap: widget.onTap,
            child: Padding(
              padding: _contentPadding(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Expand/collapse arrow.
                  SizedBox(
                    width: AppTokens.expandArrowSize + 8,
                    height: AppTokens.expandArrowSize + 8,
                    child: widget.hasChildren
                        ? GestureDetector(
                            onTap: widget.onToggleExpand,
                            child: AnimatedRotation(
                              turns: widget.isExpanded ? 0.25 : 0,
                              duration: AppTokens.motionFast,
                              child: Icon(
                                Icons.arrow_right,
                                size: AppTokens.expandArrowSize,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : null,
                  ),
                  // Checkbox.
                  SizedBox(
                    width: AppTokens.touchTarget,
                    height: AppTokens.touchTarget,
                    child: Checkbox(
                      value: isDone,
                      onChanged: (!hasDerived || widget.task.parentId == null)
                          ? widget.onToggleDone
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceXs),
                  // Title + metadata.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.task.title,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isDone
                                      ? colorScheme.onSurfaceVariant
                                      : colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Inline status icon (when derived).
                            if (hasDerived)
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: AppTokens.spaceXxs,
                                ),
                                child: Icon(
                                  _statusIcon(effectiveStatus, isDone),
                                  size: 14,
                                  color: _statusColor(
                                    effectiveStatus,
                                    colorScheme,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // Metadata row: tags + due date + progress.
                        if (widget.tags.isNotEmpty ||
                            widget.task.endAt != null ||
                            (widget.progressValue != null &&
                                widget.hasChildren))
                          Padding(
                            padding: const EdgeInsets.only(
                              top: AppTokens.spaceXxs,
                            ),
                            child: Row(
                              children: [
                                // Tag chips (up to 2).
                                ...widget.tags
                                    .take(2)
                                    .map(
                                      (tag) => Padding(
                                        padding: const EdgeInsets.only(
                                          right: AppTokens.spaceXxs,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppTokens.spaceXs,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Color(
                                              tag.color,
                                            ).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              AppTokens.radiusChip,
                                            ),
                                          ),
                                          child: Text(
                                            tag.name,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: Color(tag.color),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                if (widget.tags.length > 2)
                                  Text(
                                    '+${widget.tags.length - 2}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                                const Spacer(),
                                // Progress ring（滴答式：圆环 + 百分比，行尾）。
                                // 有子任务任务的派生完成度，55-ui-redesign §5。
                                if (widget.progressValue != null &&
                                    widget.hasChildren)
                                  TaskProgressRing(
                                    value: widget.progressValue!,
                                  ),
                                // Due date.
                                if (widget.task.endAt != null) ...[
                                  if (widget.progressValue != null)
                                    const SizedBox(width: AppTokens.spaceXs),
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 11,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: AppTokens.spaceXxs),
                                  Text(
                                    formatDueDate(widget.task.endAt!, l10n),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Drop-as-child indicator.
                  if (widget.isDragTarget &&
                      widget.dropAsChild &&
                      !widget.isInvalidDragTarget)
                    Padding(
                      padding: const EdgeInsets.only(right: AppTokens.spaceXxs),
                      child: Icon(
                        Icons.subdirectory_arrow_right,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                  // More menu.
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onPressed: () => _showMenu(context),
                    tooltip: AppLocalizations.of(context).rowActions,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: AppTokens.touchTarget,
                      minHeight: AppTokens.touchTarget,
                    ),
                  ),
                ],
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

  IconData _statusIcon(TaskStatus status, bool isDone) => switch (status) {
    TaskStatus.done => Icons.check_circle,
    TaskStatus.inProgress => Icons.radio_button_checked,
    TaskStatus.cancelled => Icons.cancel,
    TaskStatus.todo => Icons.circle_outlined,
  };
}
