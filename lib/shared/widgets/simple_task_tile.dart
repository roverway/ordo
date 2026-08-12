import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/dates.dart';
import 'task_progress_ring.dart';

/// 卡片化任务行（今日/日历/标签/搜索视图共用，滴答风格，M5 批 1）。
///
/// 与 `task_row.dart`（任务树拖拽行）解耦：**不加拖拽、不加菜单、不加缩进**。
/// 展示内容：圆形勾选 + 标题 + 标签 chips（最多 2 个）+ 时间区间 + 逾期徽标。
///
/// 视觉规格（55-ui-redesign-proposal.md §6，批 1）：
/// - 白卡片行：圆角 [AppTokens.radiusCard] + 轻阴影 [AppTokens.elevationCard]，
///   hover/按压轻微抬升到 [AppTokens.elevationCardHover]。
/// - 圆形复选框：完成 = 蓝填充白勾（[AppTokens.colorInProgress] + [AppTokens.colorOnCheck]，
///   由 AppTheme.checkboxTheme 统一提供）；有子任务禁用态保留。
///
/// - [hasChildren]：任务有子任务时勾选禁用（状态由子任务派生，AGENTS.md §3-2）。
/// - [progressValue]：有子任务任务的派生完成度（0.0–1.0）；非空时在元信息行
///   尾部渲染进度环 + 百分比（55-ui-redesign §5，滴答式）。
/// - [isDone]：标题划线 + 弱色。
/// - [isOverdue]：标题红色 + 尾部「逾期」徽标。
/// - [tags]：任务关联标签（调用方解析后传入）。
///
/// 颜色/圆角/间距/动效一律使用 [AppTokens] 设计令牌（AGENTS.md §3-9）。
class SimpleTaskTile extends StatefulWidget {
  const SimpleTaskTile({
    super.key,
    required this.task,
    required this.hasChildren,
    required this.isDone,
    this.isOverdue = false,
    this.tags = const [],
    this.progressValue,
    this.onTap,
    this.onToggleDone,
  });

  final Task task;
  final bool hasChildren;
  final bool isDone;
  final bool isOverdue;
  final List<Tag> tags;

  /// 有子任务任务的派生完成度（0.0–1.0），无子任务传 null。
  final double? progressValue;
  final VoidCallback? onTap;
  final ValueChanged<bool?>? onToggleDone;

  @override
  State<SimpleTaskTile> createState() => _SimpleTaskTileState();
}

class _SimpleTaskTileState extends State<SimpleTaskTile> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _raised => _hovered || _pressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final timeText = formatDateRange(
      widget.task.startAt,
      widget.task.endAt,
      l10n,
    );
    final showMeta =
        widget.tags.isNotEmpty ||
        timeText.isNotEmpty ||
        widget.isOverdue ||
        (widget.hasChildren && widget.progressValue != null);

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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 圆形勾选（有子任务 → 禁用，状态由子任务派生）。
                    SizedBox(
                      width: AppTokens.touchTarget,
                      height: AppTokens.touchTarget,
                      child: widget.hasChildren
                          ? Tooltip(
                              // 无障碍（NFR-06）：禁用原因走 ARB 文案。
                              message: l10n.statusDerivedFromChildren,
                              child: Checkbox(
                                value: widget.isDone,
                                onChanged: null,
                              ),
                            )
                          : Checkbox(
                              value: widget.isDone,
                              onChanged: widget.onToggleDone,
                            ),
                    ),
                    const SizedBox(width: AppTokens.spaceSm),
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
                                    decoration: widget.isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: widget.isDone
                                        ? colorScheme.onSurfaceVariant
                                        : widget.isOverdue
                                        ? AppTokens.colorOverdue
                                        : colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // 逾期徽标。
                              if (widget.isOverdue)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: AppTokens.spaceXxs,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppTokens.spaceXs,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTokens.colorOverdue.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppTokens.radiusChip,
                                      ),
                                    ),
                                    child: Text(
                                      l10n.overdue,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppTokens.colorOverdue,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // 元信息行：标签 chips（≤2）+ 时间区间（内联紧凑排布）。
                          if (showMeta)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppTokens.spaceXxs,
                              ),
                              child: Row(
                                children: [
                                  // 标签 chips（≤2）。Flexible + maxLines 兜底：
                                  // 系统字体缩放（NFR-06）下标签组可收缩而非溢出。
                                  if (widget.tags.isNotEmpty)
                                    Flexible(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ...widget.tags
                                              .take(2)
                                              .map(
                                                (tag) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right:
                                                            AppTokens.spaceXxs,
                                                      ),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal:
                                                              AppTokens.spaceXs,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Color(
                                                        tag.color,
                                                      ).withValues(alpha: 0.12),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            AppTokens
                                                                .radiusChip,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      tag.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: Color(
                                                              tag.color,
                                                            ),
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          if (widget.tags.length > 2)
                                            Text(
                                              '+${widget.tags.length - 2}',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                    fontSize: 10,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  const Spacer(),
                                  // 进度环 + 百分比（有子任务任务的派生完成度）。
                                  if (widget.hasChildren &&
                                      widget.progressValue != null) ...[
                                    TaskProgressRing(
                                      value: widget.progressValue!,
                                    ),
                                    if (timeText.isNotEmpty)
                                      const SizedBox(width: AppTokens.spaceXs),
                                  ],
                                  if (timeText.isNotEmpty) ...[
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 11,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: AppTokens.spaceXxs),
                                    Flexible(
                                      child: Text(
                                        timeText,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
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
          ),
        ),
      ),
    );
  }
}
