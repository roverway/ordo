import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/motion.dart';

/// 任务进度环（滴答式，55-ui-redesign-proposal.md §5 progressRing）。
///
/// 有子任务任务的派生完成度表达：圆形进度环 + 百分比数字，放在行尾。
/// - 圆环尺寸/线宽走 [AppTokens.progressRingSize] / [AppTokens.progressRingWidth]
///   （用户打磨要求 1：24/2.5 → 18/2，更小更轻）；
/// - 完成（≥1.0）用 [AppTokens.colorDone]，进行中用 [AppTokens.colorInProgress]；
/// - 百分比数字用 [AppTokens.progressPercentSize]（10sp，小一号）。
///
/// 动效（docs/63-motion-polish.md §5 F）：value 变化时圆环用
/// [TweenAnimationBuilder] 平滑扫过——时长 `motionNormal`、曲线 `motionCurve`
/// （easeOutCubic）；reduced motion 自动降级为瞬时到位（时长零）。
/// 百分比数字与圆环共用同一动画值，避免「数字先跳、圆环后到」的割裂感。
///
/// 无障碍（NFR-06）：整组件用 [Semantics] 暴露「进度 + 完成百分比」，
/// 子级（圆环 + 数字）用 [ExcludeSemantics] 排除，避免读屏重复播报；
/// Semantics label 始终取**最终值**（不随动画播报中间值）。
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
    final percent = (value * 100).round();

    return Semantics(
      label: AppLocalizations.of(context).progressPercent(percent),
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: motionNormal(context),
          curve: motionCurve(context),
          builder: (context, animatedValue, _) {
            final animatedPercent = (animatedValue * 100).round();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: AppTokens.progressRingSize,
                  height: AppTokens.progressRingSize,
                  child: CircularProgressIndicator(
                    value: animatedValue,
                    strokeWidth: AppTokens.progressRingWidth,
                    backgroundColor: colorScheme.primary.withValues(
                      alpha: 0.12,
                    ),
                    // 颜色按**最终**完成度切换（不随动画闪烁）。
                    valueColor: AlwaysStoppedAnimation(
                      value >= 1.0 ? AppTokens.colorDone : colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceXxs),
                Text(
                  '$animatedPercent%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: AppTokens.progressPercentSize,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
