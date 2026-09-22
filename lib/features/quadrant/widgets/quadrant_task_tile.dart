import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/priority_color.dart';
import '../../../core/utils/dates.dart';
import '../../../shared/widgets/animated_strikethrough.dart';
import '../../../shared/widgets/modern_checkbox.dart';
import '../../tasks/task_edit_page.dart';
import '../models/quadrant_models.dart';
import '../providers/quadrant_providers.dart';

/// 四象限任务条目组件。
///
/// 支持长按拖拽（[LongPressDraggable]）跨象限移动、
/// 单击弹出任务详情编辑、点击复选框标记完成/取消完成。
class QuadrantTaskTile extends ConsumerWidget {
  const QuadrantTaskTile({super.key, required this.taskView});

  final QuadrantTaskView taskView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final task = taskView.task;
    final isDone = task.status == TaskStatus.done;
    final actionController = ref.read(quadrantActionControllerProvider);

    final cardContent = _buildTileCard(
      context: context,
      theme: theme,
      colorScheme: colorScheme,
      l10n: l10n,
      isDone: isDone,
      onToggleDone: () => actionController.toggleTaskDone(task, !isDone),
      onTap: () => openTaskEdit(context, taskId: task.id),
    );

    return LongPressDraggable<QuadrantTaskView>(
      data: taskView,
      delay: AppTokens.motionNormal,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(AppTokens.radiusList),
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Opacity(
            opacity: 0.9,
            child: _buildTileCard(
              context: context,
              theme: theme,
              colorScheme: colorScheme,
              l10n: l10n,
              isDone: isDone,
              isDragging: true,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: AppTokens.alphaBorderEmphasis,
        child: cardContent,
      ),
      child: cardContent,
    );
  }

  Widget _buildTileCard({
    required BuildContext context,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required AppLocalizations l10n,
    required bool isDone,
    bool isDragging = false,
    VoidCallback? onToggleDone,
    VoidCallback? onTap,
  }) {
    final task = taskView.task;
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppTokens.spaceMicro,
        horizontal: AppTokens.spaceMicro,
      ),
      decoration: BoxDecoration(
        color: isDragging
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusList),
        border: Border.all(
          color: isDragging
              ? colorScheme.primary
              : borderColor.withValues(alpha: AppTokens.alphaBorderSubtle),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusList),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusList),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceSm,
              vertical: AppTokens.spaceXs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 完成状态复选框
                ModernCheckbox(
                  checked: isDone,
                  onChanged: onToggleDone != null
                      ? (_) => onToggleDone()
                      : null,
                  size: 18,
                  tapTargetSize: AppTokens.checkboxTapTargetSize,
                ),
                const SizedBox(width: AppTokens.spaceXs),

                // 标题与附属元信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedStrikethrough(
                        text: task.title,
                        isDone: isDone,
                        style: TextStyle(
                          fontSize: AppTokens.textBodySize,
                          fontWeight: FontWeight.w500,
                          color: isDone
                              ? colorScheme.onSurfaceVariant.withValues(
                                  alpha: AppTokens.alphaContentMuted,
                                )
                              : colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppTokens.spaceMicro),
                      _buildMetadataRow(colorScheme, l10n),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataRow(ColorScheme colorScheme, AppLocalizations l10n) {
    final task = taskView.task;
    final projectColor = taskView.projectColor != null
        ? Color(taskView.projectColor!)
        : colorScheme.primary;

    return Row(
      children: [
        // 清单标签徽标
        if (taskView.projectName != null) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: projectColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppTokens.spaceXxs),
          Flexible(
            child: Text(
              taskView.projectName!,
              style: TextStyle(
                fontSize: AppTokens.textMicroSize,
                color: colorScheme.onSurfaceVariant.withValues(
                  alpha: AppTokens.alphaContentMuted,
                ),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppTokens.spaceXs),
        ],

        // 截止日期徽标
        if (task.endAt != null) ...[
          Icon(
            Icons.schedule_outlined,
            size: 11,
            color: taskView.isOverdue
                ? colorScheme.error
                : colorScheme.onSurfaceVariant.withValues(
                    alpha: AppTokens.alphaContentMuted,
                  ),
          ),
          const SizedBox(width: AppTokens.spaceMicro),
          Text(
            formatDueDate(task.endAt!, l10n),
            style: TextStyle(
              fontSize: AppTokens.textMicroSize,
              color: taskView.isOverdue
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant.withValues(
                      alpha: AppTokens.alphaContentMuted,
                    ),
            ),
          ),
          const SizedBox(width: AppTokens.spaceXs),
        ],

        // 优先级标识圆点（高/中优显示）
        if (task.priority == TaskPriority.high ||
            task.priority == TaskPriority.medium)
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: priorityColor(task.priority),
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }
}
