import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../features/settings/settings_providers.dart';

/// 统一圆角矩形卡片容器（对齐设计规范中的 .card / 设置页圆角卡片风格）。
///
/// 当存在全局壁纸时，自动启用磨砂玻璃模糊 (BackdropFilter) 与半透明背景；
/// 无壁纸时，呈现干净现代的实体卡片色彩与精细微阴影。
class SettingsCard extends ConsumerWidget {
  const SettingsCard({
    super.key,
    this.children,
    this.child,
    this.padding = const EdgeInsets.all(AppTokens.spaceMd),
    this.margin,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.borderRadius,
    this.clipBehavior = Clip.none,
  }) : assert(
         children != null || child != null,
         'Either child or children must be provided',
       );

  final List<Widget>? children;
  final Widget? child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final CrossAxisAlignment crossAxisAlignment;
  final BorderRadius? borderRadius;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasWallpaper = ref.watch(appBackgroundConfigProvider).isEffective;
    final effectiveRadius =
        borderRadius ?? BorderRadius.circular(AppTokens.radiusDialog);

    final baseCardColor = isDark
        ? AppTokens.surfaceCardDark
        : AppTokens.surfaceCardLight;
    final cardColor = hasWallpaper
        ? baseCardColor.withValues(
            alpha: isDark
                ? AppTokens.alphaCardFrostedDark
                : AppTokens.alphaCardFrostedLight,
          )
        : baseCardColor;

    final borderColor = isDark
        ? Colors.white.withValues(
            alpha: hasWallpaper
                ? AppTokens.alphaTintStrong
                : AppTokens.alphaTintFaint,
          )
        : Colors.black.withValues(
            alpha: hasWallpaper
                ? AppTokens.alphaTintSoft
                : AppTokens.alphaTintFaint,
          );

    final content =
        child ??
        Column(
          crossAxisAlignment: crossAxisAlignment,
          mainAxisSize: MainAxisSize.min,
          children: children!,
        );

    if (hasWallpaper) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: effectiveRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark
                    ? AppTokens.alphaBorderEmphasis
                    : AppTokens.alphaTintFaint,
              ),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: effectiveRadius,
          clipBehavior: clipBehavior == Clip.none
              ? Clip.antiAlias
              : clipBehavior,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppTokens.blurFrostedGlass,
              sigmaY: AppTokens.blurFrostedGlass,
            ),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: effectiveRadius,
                border: Border.all(color: borderColor, width: 1),
              ),
              child: content,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: effectiveRadius,
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark
                  ? AppTokens.alphaBorderEmphasis
                  : AppTokens.alphaTintFaint,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: clipBehavior,
      child: content,
    );
  }
}
