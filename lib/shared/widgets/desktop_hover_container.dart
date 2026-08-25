import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/motion.dart';

/// 桌面端与多端精致 Hover 卡片容器（Linear / Things 3 风格）。
///
/// 1. 鼠标悬停时平滑插值 1px 光晕微边框与多层弥散阴影；
/// 2. 支持将 isHovered 状态透传给子组件以实现快捷操作图标的优雅淡入；
/// 3. reduced motion 时瞬时切换。
class DesktopHoverContainer extends StatefulWidget {
  const DesktopHoverContainer({
    super.key,
    this.child,
    this.hoverChild,
    this.builder,
    this.borderRadius,
    this.margin,
    this.padding,
    this.backgroundColor,
    this.borderWidth = 1.0,
    this.restingBorderColor,
    this.hoverBorderColor,
    this.restingShadow,
    this.hoverShadow,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.cursor = SystemMouseCursors.click,
    this.enableHover = true,
  });

  final Widget? child;
  final Widget? hoverChild;
  final Widget Function(BuildContext context, bool isHovered)? builder;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final double borderWidth;
  final Color? restingBorderColor;
  final Color? hoverBorderColor;
  final List<BoxShadow>? restingShadow;
  final List<BoxShadow>? hoverShadow;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final MouseCursor cursor;
  final bool enableHover;

  @override
  State<DesktopHoverContainer> createState() => _DesktopHoverContainerState();
}

class _DesktopHoverContainerState extends State<DesktopHoverContainer> {
  bool _isHovered = false;

  void _onEnter(PointerEnterEvent event) {
    if (!widget.enableHover) return;
    setState(() => _isHovered = true);
  }

  void _onExit(PointerExitEvent event) {
    if (!widget.enableHover) return;
    setState(() => _isHovered = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius =
        widget.borderRadius ?? BorderRadius.circular(AppTokens.radiusCard);

    final restingBorder =
        widget.restingBorderColor ??
        (isDark ? AppTokens.borderSubtleDark : AppTokens.borderSubtleLight);
    final hoverBorder =
        widget.hoverBorderColor ??
        (isDark
            ? AppTokens.borderSubtleHoverDark
            : AppTokens.borderSubtleHoverLight);

    final restingShadows =
        widget.restingShadow ??
        (isDark ? AppTokens.cardShadowDarkList : AppTokens.cardShadowLight);
    final hoverShadows =
        widget.hoverShadow ??
        (isDark
            ? AppTokens.cardShadowDarkHoverList
            : AppTokens.cardShadowLightHover);

    final cardBg =
        widget.backgroundColor ??
        (isDark ? AppTokens.surfaceCardDark : AppTokens.surfaceCard);

    final duration = motionFast(context);

    Widget content = widget.builder != null
        ? widget.builder!(context, _isHovered)
        : (_isHovered && widget.hoverChild != null
              ? widget.hoverChild!
              : widget.child ?? const SizedBox.shrink());

    if (widget.padding != null) {
      content = Padding(padding: widget.padding!, child: content);
    }

    Widget decorated = AnimatedContainer(
      duration: duration,
      curve: motionCurve(context),
      margin: widget.margin,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: radius,
        border: Border.all(
          color: _isHovered ? hoverBorder : restingBorder,
          width: widget.borderWidth,
        ),
        boxShadow: _isHovered ? hoverShadows : restingShadows,
      ),
      child: ClipRRect(borderRadius: radius, child: content),
    );

    if (widget.onTap != null ||
        widget.onLongPress != null ||
        widget.onSecondaryTap != null) {
      decorated = GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onSecondaryTap: widget.onSecondaryTap,
        behavior: HitTestBehavior.opaque,
        child: decorated,
      );
    }

    return MouseRegion(
      cursor: widget.cursor,
      onEnter: _onEnter,
      onExit: _onExit,
      child: decorated,
    );
  }
}
