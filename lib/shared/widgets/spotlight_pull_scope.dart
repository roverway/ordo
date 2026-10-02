import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';

/// 下拉唤起全局搜索（Spotlight）的作用域封装控件。
///
/// 封装了下拉阻尼、屏幕高度 25% 动态阈值判定、触感反馈与弹性胶囊提示。
class SpotlightPullScope extends StatefulWidget {
  const SpotlightPullScope({
    super.key,
    required this.child,
    required this.onTrigger,
  });

  final Widget child;
  final VoidCallback onTrigger;

  @override
  State<SpotlightPullScope> createState() => _SpotlightPullScopeState();
}

class _SpotlightPullScopeState extends State<SpotlightPullScope> {
  final ValueNotifier<double> _pullDistanceNotifier = ValueNotifier<double>(
    0.0,
  );
  double _overscrollAccumulator = 0.0;
  bool _hasTriggered = false;

  @override
  void dispose() {
    _pullDistanceNotifier.dispose();
    super.dispose();
  }

  void _handleScrollNotification(
    ScrollNotification notification,
    double threshold,
  ) {
    if (notification is ScrollUpdateNotification) {
      if (notification.metrics.pixels < 0) {
        final pull = -notification.metrics.pixels;
        _pullDistanceNotifier.value = pull;
        _checkTrigger(pull, threshold);
      } else if (_pullDistanceNotifier.value > 0) {
        _pullDistanceNotifier.value = 0.0;
      }
    } else if (notification is OverscrollNotification) {
      if (notification.overscroll < 0) {
        _overscrollAccumulator -= notification.overscroll;
        _pullDistanceNotifier.value = _overscrollAccumulator;
        _checkTrigger(_overscrollAccumulator, threshold);
      }
    } else if (notification is ScrollEndNotification) {
      _overscrollAccumulator = 0.0;
      _pullDistanceNotifier.value = 0.0;
      _hasTriggered = false;
    }
  }

  void _checkTrigger(double distance, double threshold) {
    if (distance >= threshold && !_hasTriggered) {
      _hasTriggered = true;
      HapticFeedback.mediumImpact();
      widget.onTrigger();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final threshold = math.max(
      AppTokens.spotlightMinTriggerHeight,
      screenHeight * AppTokens.spotlightTriggerFraction,
    );

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _handleScrollNotification(notification, threshold);
        return false;
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          widget.child,
          ValueListenableBuilder<double>(
            valueListenable: _pullDistanceNotifier,
            builder: (context, pullDistance, _) {
              if (pullDistance < AppTokens.spotlightPromptMinPull) {
                return const SizedBox.shrink();
              }
              return _SpotlightElasticPrompt(
                pullDistance: pullDistance,
                threshold: threshold,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SpotlightElasticPrompt extends StatelessWidget {
  const _SpotlightElasticPrompt({
    required this.pullDistance,
    required this.threshold,
  });

  final double pullDistance;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final progress = (pullDistance / threshold).clamp(0.0, 1.0);
    final isReady = progress >= 1.0;

    // 弹性位移曲线：使用幂律阻尼模拟 iOS 真实橡皮筋手感
    final translateY = (math.pow(pullDistance, 0.72) * 1.6).clamp(
      AppTokens.spaceSm,
      AppTokens.spotlightPromptMaxTranslateY,
    );
    final opacity = ((pullDistance - AppTokens.spotlightPromptMinPull) / 24.0)
        .clamp(0.0, 1.0);
    final scale = (0.90 + 0.10 * progress).clamp(0.90, 1.05);

    return Positioned(
      top: 0,
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceSm,
                vertical: AppTokens.spaceXxs + 1,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTokens.surfaceCardDark.withValues(
                        alpha: AppTokens.alphaOverlayHeavy,
                      )
                    : AppTokens.surfaceCard.withValues(
                        alpha: AppTokens.alphaOverlayHeavy,
                      ),
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                border: Border.all(
                  color: isReady
                      ? colorScheme.primary
                      : (isDark
                            ? AppTokens.borderSubtleDark
                            : AppTokens.borderSubtleLight),
                  width: 1.0,
                ),
                boxShadow: isDark
                    ? AppTokens.cardShadowDarkList
                    : AppTokens.cardShadowLight,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: AppTokens.spotlightProgressRingSize,
                    height: AppTokens.spotlightProgressRingSize,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 2.0,
                      color: colorScheme.primary,
                      backgroundColor: colorScheme.primary.withValues(
                        alpha: AppTokens.alphaBorderSubtle,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceXs),
                  Icon(
                    Icons.search_rounded,
                    size: AppTokens.spotlightPromptIconSize,
                    color: isReady
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppTokens.spaceXxs),
                  Text(
                    isReady ? l10n.releaseToSearch : l10n.pullDownToSearch,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: AppTokens.textMicroSize,
                      fontWeight: isReady ? FontWeight.w600 : FontWeight.w500,
                      color: isReady
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
