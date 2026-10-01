import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// 滚动溢出渐隐感知包装器（Scroll Perception Fade Wrapper）。
///
/// 严格践行乔布斯设计原则：
/// - 消除长列表被生硬斩断的不适感；
/// - 底部叠加 [AppTokens.scrollFadeHeight] 高度自然过渡渐变；
/// - 悬浮 [AppTokens.scrollFadeIconSize] 微光下滚箭头；
/// - 动态感知滚动状态：当滑至底部（距终点 ≤ 4dp）时，150ms [Curves.easeOutCubic] 优雅淡出；离开底部时苏醒。
class AppScrollFadeWrapper extends StatefulWidget {
  const AppScrollFadeWrapper({
    super.key,
    required this.child,
    this.scrollController,
    this.bottomRadius = AppTokens.radiusSheet,
    this.backgroundColor,
  });

  final Widget child;
  final ScrollController? scrollController;
  final double bottomRadius;
  final Color? backgroundColor;

  @override
  State<AppScrollFadeWrapper> createState() => _AppScrollFadeWrapperState();
}

class _AppScrollFadeWrapperState extends State<AppScrollFadeWrapper> {
  ScrollController? _internalController;
  ScrollController get _effectiveController =>
      widget.scrollController ?? (_internalController ??= ScrollController());

  bool _canScrollDown = false;

  @override
  void initState() {
    super.initState();
    _effectiveController.addListener(_checkScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }

  @override
  void didUpdateWidget(covariant AppScrollFadeWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_checkScroll);
      _effectiveController.addListener(_checkScroll);
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_checkScroll);
    _internalController?.dispose();
    super.dispose();
  }

  void _checkScroll() {
    if (!_effectiveController.hasClients) return;
    final pos = _effectiveController.position;
    final canScroll =
        pos.maxScrollExtent > AppTokens.spaceXxs &&
        pos.pixels < pos.maxScrollExtent - AppTokens.spaceXxs;
    if (canScroll != _canScrollDown && mounted) {
      setState(() => _canScrollDown = canScroll);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sheetBg =
        widget.backgroundColor ??
        (isDark
            ? AppTokens.surfaceCardDark.withValues(
                alpha: AppTokens.alphaCardFrostedDark,
              )
            : AppTokens.surfaceCardLight.withValues(
                alpha: AppTokens.alphaCardFrostedLight,
              ));

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (_) {
            _checkScroll();
            return false;
          },
          child: widget.child,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: AppTokens.scrollFadeHeight,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _canScrollDown ? 1.0 : 0.0,
              duration: AppTokens.motionFast,
              curve: Curves.easeOutCubic,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      sheetBg.withValues(alpha: AppTokens.alphaTransparent),
                      sheetBg.withValues(
                        alpha: AppTokens.alphaOverlayNearlyOpaque,
                      ),
                    ],
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(widget.bottomRadius),
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: AppTokens.scrollFadeIconSize,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: AppTokens.alphaContentMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
