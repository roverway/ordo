import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/tables.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/animated_strikethrough.dart';
import '../../../shared/widgets/app_background_wrapper.dart';
import '../../../shared/widgets/modern_checkbox.dart';
import '../../tasks/task_edit_page.dart';
import '../models/quadrant_models.dart';
import '../providers/quadrant_providers.dart';

/// 四象限任务极简条目组件。
///
/// 遵循原型与设计规范：
/// 1. 彻底去卡片化：无独立外边框与卡片背景，仅由极细发丝级分割线分隔；
/// 2. 极致紧凑排版：仅保留 16dp 方形复选框与任务标题（最多两行，带省略与完成划线）；
/// 3. 支持长按拖拽（[LongPressDraggable]）跨象限移动；
/// 4. 深度接入应用主题色与壁纸系统（无魔法值）。
class QuadrantTaskTile extends ConsumerWidget {
  const QuadrantTaskTile({
    super.key,
    required this.taskView,
    this.showDivider = true,
  });

  final QuadrantTaskView taskView;
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final task = taskView.task;
    final isDone = task.status == TaskStatus.done;
    final actionController = ref.read(quadrantActionControllerProvider);

    final rowContent = _buildTaskRow(
      context: context,
      theme: theme,
      colorScheme: colorScheme,
      isDone: isDone,
      onToggleDone: () => actionController.toggleTaskDone(task, !isDone),
      onTap: () => openTaskEdit(context, taskId: task.id),
    );

    return LongPressDraggable<QuadrantTaskView>(
      data: taskView,
      delay: AppTokens.motionNormal,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        color: colorScheme.surface,
        shadowColor: Colors.black.withValues(alpha: AppTokens.alphaTintStrong),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceSm,
              vertical: AppTokens.spaceXs,
            ),
            child: _buildTaskRow(
              context: context,
              theme: theme,
              colorScheme: colorScheme,
              isDone: isDone,
              isDragging: true,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: AppTokens.alphaBorderEmphasis,
        child: rowContent,
      ),
      child: rowContent,
    );
  }

  Widget _buildTaskRow({
    required BuildContext context,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required bool isDone,
    bool isDragging = false,
    VoidCallback? onToggleDone,
    VoidCallback? onTap,
  }) {
    final task = taskView.task;
    final isDark = theme.brightness == Brightness.dark;
    final hasWallpaper = AppBackgroundScope.hasWallpaperOf(context);

    final dividerColor = isDark
        ? AppTokens.borderSubtleDark.withValues(
            alpha: AppTokens.alphaBorderSubtle,
          )
        : (hasWallpaper
              ? Colors.white.withValues(alpha: AppTokens.alphaBorderSubtle)
              : AppTokens.borderSubtleNeutralLight);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: colorScheme.primary.withValues(
              alpha: AppTokens.alphaTintSoft,
            ),
            highlightColor: colorScheme.primary.withValues(
              alpha: AppTokens.alphaTintSoft,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceSm,
                vertical: AppTokens.spaceXs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 16dp 紧凑复选框（圆角 4dp，支持壁纸与主题色联动）
                  ModernCheckbox(
                    checked: isDone,
                    onChanged: onToggleDone != null
                        ? (_) => onToggleDone()
                        : null,
                    size: 16.0,
                    borderRadius: AppTokens.sheetGrabberRadius * 2, // 4dp
                    tapTargetSize: AppTokens.checkboxTapTargetSize,
                  ),
                  const SizedBox(width: AppTokens.spaceXs),

                  // 纯粹紧凑任务标题（12sp，最多两行，带省略与划线）
                  Expanded(
                    child: AnimatedStrikethrough(
                      text: task.title,
                      isDone: isDone,
                      style: TextStyle(
                        fontSize: AppTokens.textCaptionSize,
                        fontWeight: isDone ? FontWeight.w400 : FontWeight.w500,
                        height: AppTokens.textCaptionHeight,
                        color: isDone
                            ? colorScheme.onSurfaceVariant.withValues(
                                alpha: AppTokens.alphaContentMuted,
                              )
                            : colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 极简发丝级分割线（左侧留白对齐文本区域）
        if (showDivider && !isDragging)
          Divider(
            height: 0.5,
            thickness: 0.5,
            indent: AppTokens.spaceSm + 16.0 + AppTokens.spaceXs,
            endIndent: AppTokens.spaceSm,
            color: dividerColor,
          ),
      ],
    );
  }
}
