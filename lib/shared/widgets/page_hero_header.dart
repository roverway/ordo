import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// 页面静态大标题头部（docs/66-ui-visual-polish-proposal.md §5）。
///
/// 「工具感 → 产品感」的核心杠杆：display 级大标题 + 可选副标题 +
/// 完成概览（本地化文案 + 4dp 细进度条）。
/// 与日历页「AppBar 内嵌周期选择器」并存：日历是工具型导航，本组件
/// 用于情感型概览页（今日 / 项目列表），滚动不折叠。
class PageHeroHeader extends StatelessWidget {
  const PageHeroHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.progress,
    this.progressLabel,
    this.progressColor = AppTokens.colorDone,
  });

  /// 大标题文字。
  final String title;

  /// 可选副标题。
  final String? subtitle;

  /// 完成进度（0.0–1.0）；null 时隐藏概览行。
  final double? progress;

  /// 完成概览文案（ARB，如「2/5 已完成」）。
  final String? progressLabel;

  /// 进度条填充色；缺省完成绿 [AppTokens.colorDone]。
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showProgress =
        progress != null && progressLabel != null && progressLabel!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: AppTokens.textDisplaySize,
            fontWeight: AppTokens.textDisplayWeight,
            letterSpacing: AppTokens.textDisplayLetterSpacing,
            height: AppTokens.textDisplayHeight,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          SizedBox(height: AppTokens.spaceXxs),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: AppTokens.textFootnoteSize,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (showProgress) ...[
          SizedBox(height: AppTokens.spaceMd),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.spaceXxs / 2),
                  child: LinearProgressIndicator(
                    value: progress!.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ),
              SizedBox(width: AppTokens.spaceSm),
              Text(
                progressLabel!,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: AppTokens.textMicroSize,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTokens.fontTabular,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
