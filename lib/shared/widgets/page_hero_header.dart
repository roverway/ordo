import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// 净化式 Hero 大标题头部（对齐原型设计：大标题 + ∨ 切换箭头 + 副标题 + 右侧插槽如进度环/操作按钮）。
///
/// 见于 `home.html` / `tasklist.html` / `calendar.html` / `overview.html` / `settings.html` / `customview.html`。
class PageHeroHeader extends StatelessWidget {
  const PageHeroHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.onTitleTap,
    this.isExpanded = false,
    this.showDropdownChevron = true,
    this.leading,
    this.padding,
  });

  /// 大标题文字（如 "8月31日", "收集箱", "日历", "概览", "发布看板", "设置"）。
  final String title;

  /// 副标题纯文字。
  final String? subtitle;

  /// 副标题自定义组件（支持富文本/高亮/逾期标红等）。
  final Widget? subtitleWidget;

  /// 右侧组件（如 [HeroProgressRing] 或操作图标行）。
  final Widget? trailing;

  /// 点击标题触发的回调（在移动端唤起 Scope Switcher 底部弹层）。
  final VoidCallback? onTitleTap;

  /// 是否处于展开状态（驱动 ∨ 箭头旋转 180 度）。
  final bool isExpanded;

  /// 是否在大标题右侧显示 ∨ 下拉箭头。
  final bool showDropdownChevron;

  /// 标题左侧组件（如返回箭头）。
  final Widget? leading;

  /// 自定义内边距。
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget titleRow = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: AppTokens.spaceXs),
        ],
        Flexible(
          child: Text(
            title,
            style: TextStyle(
              fontSize: AppTokens.textHeroSize,
              fontWeight: AppTokens.textHeroWeight,
              letterSpacing: AppTokens.textHeroLetterSpacing,
              height: AppTokens.textHeroHeight,
              color: colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (showDropdownChevron && onTitleTap != null) ...[
          const SizedBox(width: 6),
          AnimatedRotation(
            turns: isExpanded ? 0.5 : 0.0,
            duration: AppTokens.motionFast,
            curve: Curves.easeOutCubic,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 22,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    Widget headerTextColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleRow,
        if (subtitleWidget != null) ...[
          const SizedBox(height: 6),
          subtitleWidget!,
        ] else if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: TextStyle(
              fontFeatures: AppTokens.fontTabular,
              fontSize: AppTokens.textCaptionSize,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    if (onTitleTap != null) {
      headerTextColumn = InkWell(
        onTap: onTitleTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        splashColor: colorScheme.onSurface.withValues(
          alpha: AppTokens.alphaTintFaint,
        ),
        highlightColor: colorScheme.onSurface.withValues(
          alpha: AppTokens.alphaTintFaint,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: headerTextColumn,
        ),
      );
    }

    return Padding(
      padding:
          padding ??
          const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: headerTextColumn,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppTokens.spaceMd),
            trailing!,
          ],
        ],
      ),
    );
  }
}
