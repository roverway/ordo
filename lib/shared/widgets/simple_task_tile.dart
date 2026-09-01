import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/dates.dart';
import 'animated_strikethrough.dart';
import 'checkbox_bounce.dart';
import 'modern_checkbox.dart';
import 'task_progress_ring.dart';

/// 扁平行任务行（今日/日历/标签/搜索视图共用，61-task-list-redesign.md §6 阶段 3）。
///
/// 与 `task_row.dart`（任务树拖拽行）解耦：**不加拖拽、不加菜单、不加缩进**。
/// 展示内容：方形勾选 + 标题 + 描述 + 标签 chips（最多 2 个）+ 日期行
/// （范围灰色 + 相对时间橙）+ 逾期徽标 + 派生进度环。
///
/// 视觉规格（61-task-list-redesign.md §2/§4）：
/// - 扁平行：无独立卡片底/阴影，hover 给轻微底色反馈；与 `TaskRow` 视觉统一。
/// - 方形复选框：完成 = 中性灰填充白勾（[AppTokens.checkboxDoneFill] +
///   [AppTokens.colorOnCheck]，由 AppTheme.checkboxTheme 提供填充），
///   未完成边框 = [AppTokens.colorInProgress]（今日等作用域恒为一级行）。
/// - 元信息（描述/标签/日期）为标题下方独立行，标签在描述下方，日期行尾
///   橙色相对时间（「距开始 X 天」，[AppTokens.colorDateRelative]）。
///
/// - [hasChildren]：任务有子任务时勾选禁用（状态由子任务派生，AGENTS.md §3-2）。
/// - [progressValue]：有子任务任务的派生完成度（0.0–1.0）；非空时在行尾
///   渲染进度环 + 百分比（55-ui-redesign §5，滴答式）。
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
    this.projectName,
    this.projectColor,
    this.progressValue,
    this.subtaskProgressText,
    this.onTap,
    this.onToggleDone,
  });

  final Task task;
  final bool hasChildren;
  final bool isDone;
  final bool isOverdue;
  final List<Tag> tags;
  final String? projectName;
  final int? projectColor;

  /// 有子任务任务的派生完成度（0.0–1.0），无子任务传 null。
  final double? progressValue;

  /// 子任务进度文案（如 "2/5"）；无子任务传 null。
  final String? subtaskProgressText;

  final VoidCallback? onTap;
  final ValueChanged<bool?>? onToggleDone;

  @override
  State<SimpleTaskTile> createState() => _SimpleTaskTileState();
}

class _SimpleTaskTileState extends State<SimpleTaskTile> {
  bool _hovered = false;

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

    // 优先级条颜色：高=红，中=橙，低/无=透明
    final Color priorityBarColor = switch (widget.task.priority) {
      TaskPriority.high => AppTokens.colorPriorityHigh,
      TaskPriority.medium => AppTokens.colorPriorityMedium,
      _ => Colors.transparent,
    };

    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        decoration: BoxDecoration(
          color: _hovered
              ? colorScheme.onSurface.withValues(alpha: 0.035)
              : Colors.transparent,
          border: Border(bottom: BorderSide(color: borderColor, width: 1)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            child: Stack(
              children: [
                // 优先级左侧竖条（高=红 / 中=橙）
                if (priorityBarColor != Colors.transparent)
                  Positioned(
                    left: 0,
                    top: 14,
                    bottom: 14,
                    width: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: priorityBarColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 现代极简复选框（22x22，圆角 6px），与首行标题顶对齐
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: CheckboxBounce(
                          isDone: widget.isDone,
                          child: widget.hasChildren
                              ? Tooltip(
                                  message: l10n.statusDerivedFromChildren,
                                  child: ModernCheckbox(
                                    checked: widget.isDone,
                                    onChanged: null,
                                  ),
                                )
                              : ModernCheckbox(
                                  checked: widget.isDone,
                                  onChanged: (val) =>
                                      widget.onToggleDone?.call(val),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // 标题 + 属性元数据
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 1.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 任务标题
                              AnimatedStrikethrough(
                                text: widget.task.title,
                                isDone: widget.isDone,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                  color: widget.isDone
                                      ? colorScheme.onSurfaceVariant.withValues(
                                          alpha: 0.6,
                                        )
                                      : colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              // 描述或元数据行（项目圆点 + 时间 + 标签）
                              if (widget.projectName != null ||
                                  timeText.isNotEmpty ||
                                  widget.tags.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Opacity(
                                    opacity: widget.isDone ? 0.55 : 1.0,
                                    child: Wrap(
                                      spacing: 10,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        // 所属项目
                                        if (widget.projectName != null &&
                                            widget.projectName!.isNotEmpty)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 7,
                                                height: 7,
                                                decoration: BoxDecoration(
                                                  color: Color(
                                                    widget.projectColor ??
                                                        AppTokens.seedColor
                                                            .toARGB32(),
                                                  ),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                widget.projectName!,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                      fontSize: 12.5,
                                                    ),
                                              ),
                                            ],
                                          ),

                                        // 时间展示
                                        if (timeText.isNotEmpty)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 13,
                                                color: widget.isOverdue
                                                    ? AppTokens.colorOverdue
                                                    : colorScheme
                                                          .onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                timeText,
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: widget.isOverdue
                                                          ? AppTokens
                                                                .colorOverdue
                                                          : colorScheme
                                                                .onSurfaceVariant,
                                                      fontWeight:
                                                          widget.isOverdue
                                                          ? FontWeight.w600
                                                          : FontWeight.normal,
                                                      fontSize: 12.5,
                                                      fontFeatures:
                                                          AppTokens.fontTabular,
                                                    ),
                                              ),
                                            ],
                                          ),

                                        // 标签
                                        for (final tag in widget.tags.take(3))
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colorScheme.surface,
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                              border: Border.all(
                                                color: borderColor,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 5,
                                                  height: 5,
                                                  decoration: BoxDecoration(
                                                    color: Color(tag.color),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  tag.name,
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                        fontSize: 11.5,
                                                      ),
                                                ),
                                              ],
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

                      // 右侧尾部：进度环 / 子任务数 (如 "2/5") + Chevron 箭头
                      Padding(
                        padding: const EdgeInsets.only(top: 2, left: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.hasChildren &&
                                widget.progressValue != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: TaskProgressRing(
                                  value: widget.progressValue!,
                                ),
                              ),
                            if (widget.subtaskProgressText != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  widget.subtaskProgressText!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 11.5,
                                    fontFeatures: AppTokens.fontTabular,
                                  ),
                                ),
                              ),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.65,
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
      ),
    );
  }
}
