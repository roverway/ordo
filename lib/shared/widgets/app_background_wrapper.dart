import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/background_config.dart';
import '../../features/settings/settings_providers.dart';

/// 承载壁纸背景、毛玻璃模糊与黑白遮罩的通用外壳容器
class AppBackgroundWrapper extends ConsumerWidget {
  const AppBackgroundWrapper({
    super.key,
    this.projectId,
    this.overrideConfig,
    required this.child,
  });

  /// 当前清单 ID（若存在则结合全局解析壁纸）
  final String? projectId;

  /// 直接指定的壁纸配置（优先于 Provider 解析，用于预览弹层等场景）
  final BackgroundConfig? overrideConfig;

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BackgroundConfig config =
        overrideConfig ??
        ref.watch(effectiveBackgroundConfigProvider(projectId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 若无有效壁纸，直接渲染子组件
    if (!config.isEffective) {
      return child;
    }

    final imageWidget = _buildImage(config);
    if (imageWidget == null) {
      return child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 底层壁纸图像
        Positioned.fill(child: imageWidget),

        // 2. 高斯模糊层
        if (config.blur > 0)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: config.blur,
                sigmaY: config.blur,
              ),
              child: const SizedBox.expand(),
            ),
          ),

        // 3. 动态明暗防花屏遮罩层（暗色叠加黑色、亮色叠加白色）
        Positioned.fill(
          child: Container(
            color: (isDark ? Colors.black : Colors.white).withValues(
              alpha: config.opacity.clamp(0.0, 0.9),
            ),
          ),
        ),

        // 4. 前景子组件
        child,
      ],
    );
  }

  Widget? _buildImage(BackgroundConfig config) {
    final fit = switch (config.fit) {
      BackgroundFit.contain => BoxFit.contain,
      BackgroundFit.center => BoxFit.none,
      _ => BoxFit.cover,
    };

    if (config.type == BackgroundType.preset && config.value != null) {
      return Image.asset(
        config.value!,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      );
    }

    if (config.type == BackgroundType.custom && config.value != null) {
      final file = File(config.value!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        );
      }
    }

    return null;
  }
}

/// 壁纸微缩预览组件
class WallpaperThumbnail extends StatelessWidget {
  const WallpaperThumbnail({
    super.key,
    required this.config,
    this.width = 48,
    this.height = 48,
    this.borderRadius = 8.0,
    this.isSelected = false,
    this.onTap,
  });

  final BackgroundConfig config;
  final double width;
  final double height;
  final double borderRadius;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    Widget imageWidget;
    if (config.type == BackgroundType.preset && config.value != null) {
      imageWidget = Image.asset(
        config.value!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(isDark),
      );
    } else if (config.type == BackgroundType.custom && config.value != null) {
      final file = File(config.value!);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholder(isDark),
        );
      } else {
        imageWidget = _buildPlaceholder(isDark);
      }
    } else {
      imageWidget = _buildPlaceholder(isDark);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : theme.colorScheme.outlineVariant.withValues(
                      alpha: AppTokens.alphaBorderSubtle,
                    ),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius - 1),
            child: Stack(
              fit: StackFit.expand,
              children: [
                imageWidget,
                if (isSelected)
                  Container(
                    color: primaryColor.withValues(
                      alpha: AppTokens.alphaTintStrong,
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check, size: 14, color: primaryColor),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark
          ? Colors.white.withValues(alpha: AppTokens.alphaTintSoft)
          : Colors.black.withValues(alpha: AppTokens.alphaTintFaint),
      child: Icon(
        Icons.wallpaper,
        size: 18,
        color: isDark
            ? Colors.white.withValues(alpha: AppTokens.alphaContentDisabled)
            : Colors.black.withValues(alpha: AppTokens.alphaContentDisabled),
      ),
    );
  }
}
