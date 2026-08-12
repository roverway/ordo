import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// 任务进度环（滴答式，55-ui-redesign-proposal.md §5 progressRing）。
///
/// 有子任务任务的派生完成度表达：圆形进度环 + 百分比数字，放在行尾。
/// - 圆环尺寸/线宽走 [AppTokens.progressRingSize] / [AppTokens.progressRingWidth]；
/// - 完成（≥1.0）用 [AppTokens.colorDone]，进行中用 [AppTokens.colorInProgress]；
/// - 百分比数字用主题 bodySmall（令牌字号），随明暗主题自动适配。
///
/// 颜色/尺寸/间距一律使用 [AppTokens]/colorScheme（AGENTS.md §3-9）。
class TaskProgressRing extends StatelessWidget {
  const TaskProgressRing({super.key, required this.value});

  /// 完成度 0.0–1.0（有子任务任务，由派生算法计算）。
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: AppTokens.progressRingSize,
          height: AppTokens.progressRingSize,
          child: CircularProgressIndicator(
            value: value,
            strokeWidth: AppTokens.progressRingWidth,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(
              value >= 1.0 ? AppTokens.colorDone : AppTokens.colorInProgress,
            ),
          ),
        ),
        const SizedBox(width: AppTokens.spaceXxs),
        Text(
          '${(value * 100).round()}%',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
