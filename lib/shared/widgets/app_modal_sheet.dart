import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'app_frosted_container.dart';
import 'app_scroll_fade_wrapper.dart';

/// 统一精工底部弹层（Frosted Modal Sheet）。
///
/// 严格践行乔布斯设计原则：
/// - 28×3 极简微距胶囊抓手（[AppTokens.sheetGrabberMiniWidth] × [AppTokens.sheetGrabberMiniHeight]）
/// - 顶部 [AppTokens.radiusSheet] (22dp) 连续曲率圆角
/// - 20px 光学毛玻璃透光容器（[AppFrostedContainer]）
/// - 可选支持长内容滚动动态渐隐（[AppScrollFadeWrapper]）
class AppModalSheet extends StatelessWidget {
  const AppModalSheet({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.showGrabber = true,
    this.maxHeight,
    this.padding,
    this.scrollController,
    this.borderRadius,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final bool showGrabber;
  final double? maxHeight;
  final EdgeInsetsGeometry? padding;
  final ScrollController? scrollController;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);

    final effectiveRadius =
        borderRadius ??
        const BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusSheet),
        );

    final resolvedMaxHeight =
        maxHeight ??
        (mediaQuery.size.height * AppTokens.menuMaxHeightRatio).clamp(
          200.0,
          mediaQuery.size.height - mediaQuery.padding.top,
        );

    Widget content = child;
    if (scrollController != null) {
      content = AppScrollFadeWrapper(
        scrollController: scrollController,
        bottomRadius: 0,
        child: content,
      );
    }

    return AppFrostedContainer(
      borderRadius: effectiveRadius,
      constraints: BoxConstraints(maxHeight: resolvedMaxHeight),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showGrabber)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(
                    top: AppTokens.sheetGrabberMiniMarginTop,
                    bottom: AppTokens.sheetGrabberMiniMarginBottom,
                  ),
                  width: AppTokens.sheetGrabberMiniWidth,
                  height: AppTokens.sheetGrabberMiniHeight,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(
                      alpha: AppTokens.alphaTintStrong,
                    ),
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                  ),
                ),
              ),
            if (title != null || trailing != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceMd,
                  vertical: AppTokens.spaceXs,
                ),
                child: Row(
                  children: [
                    if (title != null)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title!,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: AppTokens.textTitleWeight,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: AppTokens.spaceXxs),
                              Text(
                                subtitle!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ?trailing,
                  ],
                ),
              ),
            Flexible(
              child: Padding(
                padding: padding ?? EdgeInsets.zero,
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 呼出统一样式的毛玻璃底部弹层（Living Scrim + Frosted Sheet）。
Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  Color? barrierColor,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final effectiveBarrierColor =
      barrierColor ??
      Colors.black.withValues(
        alpha: isDark ? AppTokens.alphaScrimDark : AppTokens.alphaScrimLight,
      );

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: effectiveBarrierColor,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useRootNavigator: useRootNavigator,
    builder: builder,
  );
}
