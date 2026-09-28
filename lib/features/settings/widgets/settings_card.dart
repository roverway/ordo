import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../settings_providers.dart';

/// Standard rounded settings card container.
///
/// Automatically activates frosted glass / semi-translucent backdrop filter
/// when a custom wallpaper is active, aligning with design specification.
class SettingsCard extends ConsumerWidget {
  const SettingsCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(AppTokens.spaceMd),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasWallpaper = ref.watch(appBackgroundConfigProvider).isEffective;

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

    if (hasWallpaper) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
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
          borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppTokens.blurFrostedGlass,
              sigmaY: AppTokens.blurFrostedGlass,
            ),
            child: Material(
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
                side: BorderSide(color: borderColor, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
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
      child: Material(
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
          side: BorderSide(color: borderColor, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}
