import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// 全局精工毛玻璃容器（Liquid Glass Container）。
///
/// 严格践行乔布斯设计原则：
/// - 双模半透明透光率（浅色 82% 纯白，深色 72% 碳黑）
/// - 20px 高斯双向光学模糊（[AppTokens.blurFrostedOverlay]）
/// - 微光发丝描边（浅色 4.7% 暗边，深色 6% 白高光漫射）
/// - 深度漫射环境投影（[AppTokens.overlayShadowLight] / [AppTokens.overlayShadowDark]）
class AppFrostedContainer extends StatelessWidget {
  const AppFrostedContainer({
    super.key,
    required this.child,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.padding,
    this.constraints,
    this.width,
    this.height,
    this.blurSigma = AppTokens.blurFrostedOverlay,
    this.backgroundColor,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;
  final double? width;
  final double? height;
  final double blurSigma;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(AppTokens.radiusMenu);
    final effectiveBorder =
        border ??
        Border.all(
          color: isDark
              ? AppTokens.borderSubtleDark
              : AppTokens.borderSubtleLight,
          width: 1,
        );
    final effectiveBg =
        backgroundColor ??
        (isDark
            ? AppTokens.surfaceCardDark.withValues(
                alpha: AppTokens.alphaCardFrostedDark,
              )
            : AppTokens.surfaceCardLight.withValues(
                alpha: AppTokens.alphaCardFrostedLight,
              ));
    final effectiveShadow =
        boxShadow ??
        (isDark ? AppTokens.overlayShadowDark : AppTokens.overlayShadowLight);

    return Container(
      width: width,
      height: height,
      constraints: constraints,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: effectiveShadow,
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: effectiveBg,
              borderRadius: effectiveRadius,
              border: effectiveBorder,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
