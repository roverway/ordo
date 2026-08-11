import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/dates.dart';

/// 扁平任务行（今日/日历/标签/搜索视图共用，M3）。
///
/// 与 `task_row.dart`（任务树拖拽行）解耦：**不加拖拽、不加菜单、不加缩进**。
/// 展示内容：勾选 + 标题 + 标签 chips（最多 2 个）+ 时间区间 + 逾期徽标。
///
/// - [hasChildren]：任务有子任务时勾选禁用（状态由子任务派生，AGENTS.md §3-2）。
/// - [isDone]：标题划线 + 弱色。
/// - [isOverdue]：标题红色 + 尾部「逾期」徽标。
/// - [tags]：任务关联标签（调用方解析后传入）。
///
/// 颜色/圆角/间距/动效一律使用 [AppTokens] 设计令牌（AGENTS.md §3-9）。
class SimpleTaskTile extends StatelessWidget {
  const SimpleTaskTile({
    super.key,
    required this.task,
    required this.hasChildren,
    required this.isDone,
    this.isOverdue = false,
    this.tags = const [],
    this.onTap,
    this.onToggleDone,
  });

  final Task task;
  final bool hasChildren;
  final bool isDone;
  final bool isOverdue;
  final List<Tag> tags;
  final VoidCallback? onTap;
  final ValueChanged<bool?>? onToggleDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeText = formatDateRange(task.startAt, task.endAt, l10n);
    final showMeta = tags.isNotEmpty || timeText.isNotEmpty || isOverdue;

    return Material(
      color: Colors.transparent,
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
              // 勾选（有子任务 → 禁用，状态由子任务派生）。
              SizedBox(
                width: AppTokens.touchTarget,
                height: AppTokens.touchTarget,
                child: Checkbox(
                  value: isDone,
                  onChanged: hasChildren ? null : onToggleDone,
                ),
              ),
              const SizedBox(width: AppTokens.spaceXs),
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
                                  : isOverdue
                                  ? AppTokens.colorOverdue
                                  : colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // 逾期徽标。
                        if (isOverdue)
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
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTokens.colorOverdue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // 元信息行：标签 chips（≤2）+ 时间区间。
                    if (showMeta)
                      Padding(
                        padding: const EdgeInsets.only(top: AppTokens.spaceXxs),
                        child: Row(
                          children: [
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
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
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
    );
  }
}
