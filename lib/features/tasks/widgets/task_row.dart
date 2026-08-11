import 'package:flutter/material.dart';

import '../../../core/db/database.dart';
import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';

/// 任务行（50-ui-ux.md §5.3）：勾选、标题、标签 chips、时间、状态徽标。
///
/// 每行支持长按拖拽（50-ui-ux.md §6.1）。
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

  /// 拖拽悬停在下半（成为子级）时为 true，行尾显示"成为子级"提示图标。
  final bool dropAsChild;

  /// 状态徽标颜色。
  Color _statusColor(TaskStatus status, ColorScheme colorScheme) =>
      switch (status) {
        TaskStatus.done => AppTokens.colorDone,
        TaskStatus.inProgress => AppTokens.colorInProgress,
        TaskStatus.cancelled => AppTokens.colorCancelled,
        TaskStatus.todo => colorScheme.outline,
      };

  /// 状态徽标图标。
  IconData _statusIcon(TaskStatus status) => switch (status) {
    TaskStatus.done => Icons.check_circle,
    TaskStatus.inProgress => Icons.radio_button_checked,
    TaskStatus.cancelled => Icons.cancel,
    TaskStatus.todo => Icons.circle_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveStatus = derivedStatus ?? task.status;
    final hasDerived = derivedStatus != null;
    final depthIndent = depth * 24.0;

    return AnimatedContainer(
      duration: AppTokens.motionFast,
      decoration: BoxDecoration(
        color: isInvalidDragTarget
            ? colorScheme.errorContainer.withValues(alpha: 0.5)
            : isDragTarget
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : isDragging
            ? colorScheme.surface.withValues(alpha: 0.5)
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
              left: AppTokens.spaceMd + depthIndent,
              right: AppTokens.spaceSm,
              top: AppTokens.spaceXs,
              bottom: AppTokens.spaceXs,
            ),
            child: Row(
              children: [
                // 展开/折叠箭头。
                if (hasChildren)
                  GestureDetector(
                    onTap: onToggleExpand,
                    child: AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0,
                      duration: AppTokens.motionFast,
                      child: Icon(
                        Icons.arrow_right,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 20),
                const SizedBox(width: AppTokens.spaceXs),
                // 完成勾选。
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Checkbox(
                    value: effectiveStatus == TaskStatus.done,
                    onChanged: (!hasDerived || task.parentId == null)
                        ? onToggleDone
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.spaceXs),
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceXs),
                // 标题 + 标签 + 时间。
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题行：标题 + 状态徽标。
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                decoration: effectiveStatus == TaskStatus.done
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: effectiveStatus == TaskStatus.done
                                    ? colorScheme.onSurfaceVariant
                                    : null,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 派生状态徽标。
                          if (hasDerived)
                            Icon(
                              _statusIcon(effectiveStatus),
                              size: 16,
                              color: _statusColor(effectiveStatus, colorScheme),
                            ),
                        ],
                      ),
                      // 标签 chips + 时间 + 派生进度。
                      if (tags.isNotEmpty ||
                          task.endAt != null ||
                          (progressValue != null && hasChildren))
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppTokens.spaceXxs,
                          ),
                          child: Row(
                            children: [
                              // 标签 chips。
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
                                          ).withValues(alpha: 0.15),
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
                              // 派生进度条。
                              if (progressValue != null && hasChildren)
                                SizedBox(
                                  width: 48,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppTokens.spaceXxs,
                                    ),
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
                              if (task.endAt != null) ...[
                                const SizedBox(width: AppTokens.spaceXs),
                                Icon(
                                  Icons.schedule,
                                  size: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                // 行尾：成为子级提示 + 菜单按钮。
                if (isDragTarget && dropAsChild && !isInvalidDragTarget)
                  Padding(
                    padding: const EdgeInsets.only(right: AppTokens.spaceXxs),
                    child: Icon(
                      Icons.subdirectory_arrow_right,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ),
                Semantics(
                  button: true,
                  label: l10n.rowActions,
                  child: IconButton(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onPressed: () => _showMenu(context),
                    tooltip: l10n.rowActions,
                    visualDensity: VisualDensity.compact,
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
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.edit),
              onTap: () {
                Navigator.pop(context);
                onMenuAction('edit');
              },
            ),
            if (depth < 2)
              ListTile(
                leading: const Icon(Icons.subdirectory_arrow_right),
                title: Text(l10n.newSubtask),
                onTap: () {
                  Navigator.pop(context);
                  onMenuAction('newSubtask');
                },
              ),
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: Text(l10n.moveUp),
              onTap: () {
                Navigator.pop(context);
                onMenuAction('moveUp');
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: Text(l10n.moveDown),
              onTap: () {
                Navigator.pop(context);
                onMenuAction('moveDown');
              },
            ),
            if (depth < 2)
              ListTile(
                leading: const Icon(Icons.arrow_right),
                title: Text(l10n.indent),
                onTap: () {
                  Navigator.pop(context);
                  onMenuAction('indent');
                },
              ),
            if (depth > 0)
              ListTile(
                leading: const Icon(Icons.arrow_left),
                title: Text(l10n.outdent),
                onTap: () {
                  Navigator.pop(context);
                  onMenuAction('outdent');
                },
              ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.delete, color: colorScheme.error),
              title: Text(
                l10n.delete,
                style: TextStyle(color: colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                onMenuAction('delete');
              },
            ),
          ],
        ),
      ),
    );
  }
}
