import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/dates.dart';

/// 收件箱任务行（56-task-scope-page.md §3.4：从 inbox_page 抽取为共享组件）。
///
/// 展示：圆形勾选 + 标题 + 到期日期（逾期标红）+ 行尾 chevron。
/// 视觉与 `SimpleTaskTile` 统一（M5 批 1）：白卡片化行（圆角 16 + 轻阴影，
/// hover/按压轻微抬升），圆形复选框走 AppTheme。
///
/// - [hasChildren]：有子任务时勾选禁用 + Tooltip 派生提示（AGENTS.md §3-2）。
class InboxTaskTile extends StatefulWidget {
  const InboxTaskTile({
    super.key,
    required this.task,
    required this.hasChildren,
    required this.onToggleDone,
    required this.onTap,
  });

  final Task task;
  final bool hasChildren;
  final ValueChanged<bool?> onToggleDone;
  final VoidCallback onTap;

  @override
  State<InboxTaskTile> createState() => _InboxTaskTileState();
}

class _InboxTaskTileState extends State<InboxTaskTile> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _raised => _hovered || _pressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isDone = widget.task.status == TaskStatus.done;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceXxs),
        child: AnimatedContainer(
          duration: AppTokens.motionFast,
          curve: AppTokens.motionSpring,
          decoration: BoxDecoration(
            color: isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCard,
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            boxShadow: [
              BoxShadow(
                color: _raised
                    ? (isDark
                          ? AppTokens.shadowCardDarkElevated
                          : AppTokens.shadowCardElevated)
                    : (isDark
                          ? AppTokens.shadowCardDark
                          : AppTokens.shadowCard),
                blurRadius: _raised
                    ? AppTokens.shadowBlurElevated
                    : AppTokens.shadowBlurRest,
                offset: Offset(
                  0,
                  _raised
                      ? AppTokens.shadowOffsetYElevated
                      : AppTokens.shadowOffsetY,
                ),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              onTap: widget.onTap,
              onHighlightChanged: (v) => setState(() => _pressed = v),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceMd,
                  vertical: AppTokens.spaceSm,
                ),
                child: Row(
                  children: [
                    // Checkbox
                    SizedBox(
                      width: AppTokens.touchTarget,
                      height: AppTokens.touchTarget,
                      child: widget.hasChildren
                          ? Tooltip(
                              message: AppLocalizations.of(
                                context,
                              ).statusDerivedFromChildren,
                              child: Checkbox(value: isDone, onChanged: null),
                            )
                          : Checkbox(
                              value: isDone,
                              onChanged: widget.onToggleDone,
                            ),
                    ),
                    const SizedBox(width: AppTokens.spaceXs),
                    // Title + due date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.task.title,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isDone
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.task.endAt != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppTokens.spaceXxs,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 12,
                                    color: _dueDateColor(
                                      widget.task.endAt!,
                                      colorScheme,
                                    ),
                                  ),
                                  const SizedBox(width: AppTokens.spaceXxs),
                                  Text(
                                    formatDueDate(
                                      widget.task.endAt!,
                                      AppLocalizations.of(context),
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: _dueDateColor(
                                        widget.task.endAt!,
                                        colorScheme,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Chevron
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: colorScheme.outline.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _dueDateColor(int endAtMs, ColorScheme colorScheme) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (widget.task.status != TaskStatus.done && endAtMs < now) {
      return AppTokens.colorOverdue;
    }
    return colorScheme.onSurfaceVariant;
  }
}
