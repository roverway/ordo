import 'package:flutter/material.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/dates.dart';

/// Task row — the core list item in project detail and task trees.
///
/// TickTick-inspired: clean checkbox, soft colors, subtle metadata row.
/// Supports drag-target highlight states for tree reordering.
class TaskRow extends StatelessWidget {
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
  final List<Tag> tags;
  final TaskStatus? derivedStatus;
  final double? progressValue;
  final bool isDragging;
  final bool isDragTarget;
  final bool isInvalidDragTarget;

  /// When true, drop would make dragged task a child of this row.
  final bool dropAsChild;

  Color _statusColor(TaskStatus status, ColorScheme colorScheme) =>
      switch (status) {
        TaskStatus.done => AppTokens.colorDone,
        TaskStatus.inProgress => AppTokens.colorInProgress,
        TaskStatus.cancelled => AppTokens.colorCancelled,
        TaskStatus.todo => colorScheme.outline,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveStatus = derivedStatus ?? task.status;
    final hasDerived = derivedStatus != null;
    final isDone = effectiveStatus == TaskStatus.done;
    final indent = depth * AppTokens.treeIndent;

    return AnimatedContainer(
      duration: AppTokens.motionFast,
      decoration: BoxDecoration(
        color: isInvalidDragTarget
            ? colorScheme.errorContainer.withValues(alpha: 0.4)
            : isDragTarget
            ? colorScheme.primaryContainer.withValues(alpha: 0.25)
            : isDragging
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : null,
        borderRadius: BorderRadius.circular(AppTokens.radiusList),
        border: isDragTarget
            ? Border.all(
                color: isInvalidDragTarget
                    ? colorScheme.error
                    : colorScheme.primary,
                width: 2,
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusList),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.only(
              left: AppTokens.spaceSm + indent,
              right: AppTokens.spaceXxs,
              top: AppTokens.spaceXs,
              bottom: AppTokens.spaceXs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Expand/collapse arrow.
                SizedBox(
                  width: AppTokens.expandArrowSize + 8,
                  height: AppTokens.expandArrowSize + 8,
                  child: hasChildren
                      ? GestureDetector(
                          onTap: onToggleExpand,
                          child: AnimatedRotation(
                            turns: isExpanded ? 0.25 : 0,
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
                    onChanged: (!hasDerived || task.parentId == null)
                        ? onToggleDone
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
                              task.title,
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
                      if (tags.isNotEmpty ||
                          task.endAt != null ||
                          (progressValue != null && hasChildren))
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppTokens.spaceXxs,
                          ),
                          child: Row(
                            children: [
                              // Tag chips (up to 2).
                              ...tags
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
                              if (tags.length > 2)
                                Text(
                                  '+${tags.length - 2}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                              const Spacer(),
                              // Progress bar.
                              if (progressValue != null && hasChildren)
                                SizedBox(
                                  width: 40,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: progressValue,
                                      minHeight: 3,
                                      backgroundColor:
                                          colorScheme.surfaceContainerHighest,
                                      valueColor: AlwaysStoppedAnimation(
                                        progressValue! >= 1.0
                                            ? AppTokens.colorDone
                                            : AppTokens.colorInProgress,
                                      ),
                                    ),
                                  ),
                                ),
                              // Due date.
                              if (task.endAt != null) ...[
                                if (progressValue != null)
                                  const SizedBox(width: AppTokens.spaceXs),
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 11,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: AppTokens.spaceXxs),
                                Text(
                                  formatDueDate(task.endAt!, l10n),
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
                if (isDragTarget && dropAsChild && !isInvalidDragTarget)
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
                onMenuAction('edit');
              },
            ),
            if (depth < 2)
              ListTile(
                leading: const Icon(Icons.subdirectory_arrow_right, size: 20),
                title: Text(l10n.newSubtask),
                onTap: () {
                  Navigator.pop(context);
                  onMenuAction('newSubtask');
                },
              ),
            ListTile(
              leading: const Icon(Icons.arrow_upward, size: 20),
              title: Text(l10n.moveUp),
              onTap: () {
                Navigator.pop(context);
                onMenuAction('moveUp');
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward, size: 20),
              title: Text(l10n.moveDown),
              onTap: () {
                Navigator.pop(context);
                onMenuAction('moveDown');
              },
            ),
            if (depth < 2)
              ListTile(
                leading: const Icon(Icons.arrow_right, size: 20),
                title: Text(l10n.indent),
                onTap: () {
                  Navigator.pop(context);
                  onMenuAction('indent');
                },
              ),
            if (depth > 0)
              ListTile(
                leading: const Icon(Icons.arrow_left, size: 20),
                title: Text(l10n.outdent),
                onTap: () {
                  Navigator.pop(context);
                  onMenuAction('outdent');
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
                onMenuAction('delete');
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
