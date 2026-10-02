import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/db/database.dart';
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
    this.isSelected = false,
    this.collapseOnDone = false,
    this.onTap,
    this.onToggleDone,
  });

  final bool isSelected;
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

  final bool collapseOnDone;
  final VoidCallback? onTap;
  final ValueChanged<bool?>? onToggleDone;

  @override
  State<SimpleTaskTile> createState() => _SimpleTaskTileState();
}

class _SimpleTaskTileState extends State<SimpleTaskTile>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  Timer? _graceTimer;
  late bool _isLocallyDone;
  late final AnimationController _collapseController;
  late final Animation<double> _collapseFactor;

  @override
  void initState() {
    super.initState();
    _isLocallyDone = widget.isDone;
    _collapseController = AnimationController(
      vsync: this,
      duration: AppTokens.motionCollapse,
    );
    _collapseFactor = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _collapseController,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant SimpleTaskTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDone != widget.isDone) {
      _graceTimer?.cancel();
      _graceTimer = null;
      _isLocallyDone = widget.isDone;
      _collapseController.value = 0.0;
    }
  }

  @override
  void dispose() {
    _graceTimer?.cancel();
    _collapseController.dispose();
    super.dispose();
  }

  void _handleToggle(bool? val) {
    if (widget.onToggleDone == null) return;
    final targetDone = val ?? !_isLocallyDone;

    if (targetDone) {
      HapticFeedback.lightImpact();
      setState(() => _isLocallyDone = true);
      if (widget.collapseOnDone) {
        _graceTimer?.cancel();
        _graceTimer = Timer(AppTokens.motionDoneGracePeriod, () {
          if (mounted) {
            _collapseController.forward().then((_) {
              if (mounted) {
                widget.onToggleDone?.call(true);
              }
            });
          }
        });
      } else {
        widget.onToggleDone?.call(true);
      }
    } else {
      _graceTimer?.cancel();
      _graceTimer = null;
      _collapseController.value = 0.0;
      setState(() => _isLocallyDone = false);
      widget.onToggleDone?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDone = _isLocallyDone;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final timeText = formatDateRange(
      widget.task.startAt,
      widget.task.endAt,
      l10n,
    );

    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    final titleLineHeight =
        MediaQuery.textScalerOf(context).scale(AppTokens.textTaskL2Size) * 1.35;
    final titleTopPad =
        ((AppTokens.checkboxTapTargetSize - titleLineHeight) / 2).clamp(
          0.0,
          AppTokens.spaceXs,
        );

    return SizeTransition(
      sizeFactor: _collapseFactor,
      axisAlignment: 0.0,
      child: FadeTransition(
        opacity: _collapseFactor,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Container(
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? colorScheme.primary.withValues(
                      alpha: AppTokens.alphaTintSoft,
                    )
                  : (_hovered
                        ? colorScheme.onSurface.withValues(
                            alpha: AppTokens.alphaTintFaint,
                          )
                        : Colors.transparent),
              borderRadius: widget.isSelected
                  ? BorderRadius.circular(AppTokens.radiusList)
                  : null,
              border: widget.isSelected
                  ? Border.all(
                      color: colorScheme.primary.withValues(
                        alpha: AppTokens.alphaBorderSubtle,
                      ),
                      width: 1,
                    )
                  : Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: AppTokens.taskRowPaddingVertical,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckboxBounce(
                        isDone: effectiveDone,
                        child: widget.hasChildren
                            ? Tooltip(
                                message: l10n.statusDerivedFromChildren,
                                child: ModernCheckbox(
                                  checked: effectiveDone,
                                  onChanged: null,
                                  size: AppTokens.checkboxSize,
                                  tapTargetSize:
                                      AppTokens.checkboxTapTargetSize,
                                ),
                              )
                            : ModernCheckbox(
                                checked: effectiveDone,
                                onChanged: (val) => _handleToggle(val),
                                size: AppTokens.checkboxSize,
                                tapTargetSize: AppTokens.checkboxTapTargetSize,
                              ),
                      ),
                      const SizedBox(width: AppTokens.checkboxToTitleGap),

                      // 标题 + 属性元数据
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(top: titleTopPad),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 任务标题（统一到二级任务字阶 15 / w500）
                              AnimatedStrikethrough(
                                text: widget.task.title,
                                isDone: effectiveDone,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontSize: AppTokens.textTaskL2Size,
                                  fontWeight: AppTokens.textTaskL2Weight,
                                  height: 1.35,
                                  color: effectiveDone
                                      ? colorScheme.onSurfaceVariant.withValues(
                                          alpha: AppTokens.alphaScrim,
                                        )
                                      : colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              // 描述或元数据行（所属项目圆点 -> Linear 风格 #标签 -> 时间）
                              if (widget.projectName != null ||
                                  widget.tags.isNotEmpty ||
                                  timeText.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Opacity(
                                    opacity: effectiveDone
                                        ? AppTokens.alphaContentMuted
                                        : 1.0,
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        // 1. 所属项目（带 7dp 项目色圆点）
                                        if (widget.projectName != null &&
                                            widget.projectName!.isNotEmpty)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: AppTokens.projectDotSize,
                                                height:
                                                    AppTokens.projectDotSize,
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
                                                      fontSize: AppTokens
                                                          .textCaptionSize,
                                                    ),
                                              ),
                                            ],
                                          ),

                                        // 2. Linear 风格 #标签（带微色底极细微胶囊）
                                        for (final tag in widget.tags.take(3))
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Color(tag.color)
                                                  .withValues(
                                                    alpha:
                                                        AppTokens.alphaTintSoft,
                                                  ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTokens.radiusMicro,
                                                  ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '#',
                                                  style: TextStyle(
                                                    color: Color(tag.color)
                                                        .withValues(
                                                          alpha: AppTokens
                                                              .alphaHashPrefix,
                                                        ),
                                                    fontWeight: FontWeight.w400,
                                                    fontSize:
                                                        AppTokens.textMicroSize,
                                                  ),
                                                ),
                                                Text(
                                                  tag.name,
                                                  style: TextStyle(
                                                    color: Color(tag.color),
                                                    fontWeight: FontWeight.w500,
                                                    fontSize:
                                                        AppTokens.textMicroSize,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        // 3. 时间展示（强行启用 fontTabular）
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
                                                      fontSize: AppTokens
                                                          .textCaptionSize,
                                                      fontFeatures:
                                                          AppTokens.fontTabular,
                                                      height: 1.25,
                                                    ),
                                              ),
                                            ],
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
                              )
                            else if (widget.subtaskProgressText != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  widget.subtaskProgressText!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: AppTokens.textMicroSize,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
