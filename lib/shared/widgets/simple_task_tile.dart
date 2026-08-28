import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/priority_color.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/motion.dart';
import 'animated_strikethrough.dart';
import 'checkbox_bounce.dart';
import 'tag_chip.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final timeText = formatDateRange(
      widget.task.startAt,
      widget.task.endAt,
      l10n,
    );
    final relativeText = formatRelativeStart(widget.task.startAt, l10n);
    // 标题首行行高 = textScaler 缩放后的 fontSize × height（行高由主题
    // height 钉死，与具体字体度量无关；textScaler 覆盖系统字号缩放）。
    final titleLineHeight =
        MediaQuery.textScalerOf(
          context,
        ).scale(theme.textTheme.bodyLarge?.fontSize ?? AppTokens.textBodySize) *
        (theme.textTheme.bodyLarge?.height ?? AppTokens.textBodyHeight);
    // 标题首行顶部留白 = (复选框触控区 − 首行行高) / 2：外层 Row 改 start
    // 对齐后，首行文本中心仍与复选框中心（触控区 y=22）严格重合——任务带
    // 描述/日期/标签行时复选框对齐**标题首行**而非整块中心（用户评审
    // 2026-08，与 TaskRow 同款几何）。
    final titleTopPad = (AppTokens.checkboxTapTargetSize - titleLineHeight) / 2;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceXxs),
        child: AnimatedContainer(
          duration: motionFast(context),
          curve: motionCurve(context),
          decoration: BoxDecoration(
            // 形态 B：轻质感白卡（与 TaskTree / KanbanTaskCard 统一层级）
            color: isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCard,
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            border: Border.all(
              color: _hovered
                  ? (isDark
                      ? AppTokens.borderSubtleHoverDark
                      : AppTokens.borderSubtleHoverLight)
                  : (isDark
                      ? AppTokens.borderSubtleDark
                      : AppTokens.borderSubtleLight),
              width: 1.0,
            ),
            boxShadow: isDark
                ? (_hovered
                    ? AppTokens.cardShadowDarkHoverList
                    : AppTokens.cardShadowDarkList)
                : (_hovered
                    ? AppTokens.cardShadowLightHover
                    : AppTokens.cardShadowLight),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceSm,
                  vertical: AppTokens.spaceXxs,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppTokens.taskRowMinHeight,
                  ),
                  child: Row(
                    // start 对齐（用户评审 2026-08）：复选框钉在首行，与标题
                    // 首行中心对齐（此前 center 对齐到整块中心，带描述/日期/
                    // 标签行时复选框明显偏低）。
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 圆形勾选（Linear / Things 风格；有子任务 → 禁用，状态由子任务派生）。
                      // 触控区 44，视觉 24 居中。
                      // A 批：勾选/取消 scale 弹性脉冲（CheckboxBounce），
                      // 勾线本身由 Material Checkbox 的勾动画淡入。
                      SizedBox(
                        width: AppTokens.checkboxTapTargetSize,
                        height: AppTokens.checkboxTapTargetSize,
                        child: CheckboxBounce(
                          isDone: widget.isDone,
                          child: widget.hasChildren
                              ? Tooltip(
                                  // 无障碍（NFR-06）：禁用原因走 ARB 文案。
                                  message: l10n.statusDerivedFromChildren,
                                  child: Checkbox(
                                    value: widget.isDone,
                                    shape: AppTokens.checkboxShape,
                                    side: BorderSide(
                                      color: widget.isDone
                                          ? colorScheme.onSurfaceVariant
                                          : (theme.brightness == Brightness.dark
                                                ? Colors.white.withValues(
                                                    alpha: 0.35,
                                                  )
                                                : colorScheme.outline
                                                      .withValues(alpha: 0.45)),
                                      width: 1.5,
                                    ),
                                    onChanged: null,
                                  ),
                                )
                              : Checkbox(
                                  value: widget.isDone,
                                  shape: AppTokens.checkboxShape,
                                  side: BorderSide(
                                    color: widget.isDone
                                        ? colorScheme.onSurfaceVariant
                                        : (theme.brightness == Brightness.dark
                                              ? Colors.white.withValues(
                                                  alpha: 0.35,
                                                )
                                              : colorScheme.outline.withValues(
                                                  alpha: 0.45,
                                                )),
                                    width: 1.5,
                                  ),
                                  onChanged: widget.onToggleDone,
                                ),
                        ),
                      ),
                      const SizedBox(width: AppTokens.spaceXxs),
                      Expanded(
                        // 已完成 → 内容区整体淡化（勾选/进度环保持全不透明，
                        // 行仍可交互；strikethrough + onSurfaceVariant 保留）。
                        child: AnimatedOpacity(
                          opacity: widget.isDone
                              ? AppTokens.doneContentOpacity
                              : 1,
                          duration: motionFast(context),
                          curve: motionCurve(context),
                          child: Padding(
                            // 首行顶部留白：start 对齐下标题首行中心仍与复选
                            // 框中心重合（见 titleTopPad 注释）。
                            padding: EdgeInsets.only(top: titleTopPad),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // 优先级旗帜（用户要求：与编辑器工具栏同一
                                    // flag 图标/配色）；无优先级不渲染，行布局
                                    // 与改造前完全一致。
                                    if (widget.task.priority !=
                                        TaskPriority.none) ...[
                                      Icon(
                                        Icons.flag_outlined,
                                        size: 14,
                                        color: priorityColor(
                                          widget.task.priority,
                                        ),
                                      ),
                                      const SizedBox(width: AppTokens.spaceXxs),
                                    ],
                                    Expanded(
                                      child: AnimatedStrikethrough(
                                        text: widget.task.title,
                                        isDone: widget.isDone,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              color: widget.isDone
                                                  ? colorScheme.onSurfaceVariant
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
                                            color: AppTokens.colorOverdue
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              AppTokens.radiusChip,
                                            ),
                                          ),
                                          child: Text(
                                            l10n.overdue,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: AppTokens.colorOverdue,
                                                  fontSize:
                                                      AppTokens.textMicroSize,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                // 描述文字（61 §4.4）：标题下方灰色小字。
                                if (widget.task.description.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppTokens.spaceXxs,
                                    ),
                                    child: Text(
                                      widget.task.description,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                // 日期行（61 §4.4）：标题下方独立行，范围灰色 +
                                // 相对时间橙色强调。
                                if (timeText.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppTokens.spaceXxs,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_outlined,
                                          size: 11,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(
                                          width: AppTokens.spaceXxs,
                                        ),
                                        Expanded(
                                          child: Text(
                                            timeText,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (relativeText.isNotEmpty) ...[
                                          const SizedBox(
                                            width: AppTokens.spaceXs,
                                          ),
                                          Text(
                                            relativeText,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: AppTokens
                                                      .colorDateRelative,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                // 标签 chips（61 §4.4）：底部独立行（≤2 + +N）。
                                // 底部对称留白（用户要求）：bottom = top = spaceXxs，
                                // 与行内元信息行间距节奏一致（行/卡片底部不再贴边）。
                                if (widget.tags.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppTokens.spaceXxs,
                                    ),
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ...widget.tags
                                                  .take(2)
                                                  .map(
                                                    (tag) => Flexible(
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              right: AppTokens
                                                                  .spaceXxs,
                                                            ),
                                                        child: TagChip(
                                                          tag: tag,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              if (widget.tags.length > 2)
                                                Text(
                                                  '+${widget.tags.length - 2}',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
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
                      // 进度环 + 百分比（61 §4.4：行尾，有子任务任务的派生完成度）。
                      // 定高 44 居中：start 对齐下进度环始终与复选框中心对齐，
                      // 不随描述/日期/标签行撑高的内容块偏移。
                      if (widget.hasChildren &&
                          widget.progressValue != null) ...[
                        SizedBox(
                          height: AppTokens.checkboxTapTargetSize,
                          child: Center(
                            child: TaskProgressRing(
                              value: widget.progressValue!,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTokens.spaceXs),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
