import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import 'scope_nav_content.dart';

/// 呼出任务清单组上下文切换浮动菜单（今日、收件箱、各项目清单与文件夹）。
Future<void> showTaskScopeSheet(BuildContext context, {String? currentRoute}) {
  return showScopeSwitcherSheet(
    context,
    currentRoute: currentRoute,
    filter: ScopeNavFilter.tasksOnly,
  );
}

/// 呼出特殊视图组上下文切换浮动菜单（四象限、日历、概览、自定义视图）。
Future<void> showViewScopeSheet(BuildContext context, {String? currentRoute}) {
  return showScopeSwitcherSheet(
    context,
    currentRoute: currentRoute,
    filter: ScopeNavFilter.viewsOnly,
  );
}

/// 呼出清单/作用域切换浮动菜单。
///
/// 遵循极简 Popover 弹出菜单设计：
/// 1. 紧贴 Hero 标题正下方展开，靠左对齐；
/// 2. 宽度紧凑（288dp），更像一个随手呼出的弹出菜单，不占满全宽；
/// 3. 任务清单组与特殊视图组高度一致克制（最大高度 330dp），绝不遮挡 Hero 标题。
Future<void> showScopeSwitcherSheet(
  BuildContext context, {
  String? currentRoute,
  ScopeNavFilter filter = ScopeNavFilter.all,
}) {
  final route = currentRoute ?? resolveCurrentRoute(context);
  final mediaQuery = MediaQuery.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  // 精准计算 Hero 标题在屏幕中的全局位置，紧贴标题下方，靠左对齐展开
  double topOffset = mediaQuery.padding.top + 56.0;
  double leftOffset = 16.0;

  try {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final position = renderBox.localToGlobal(Offset.zero);
      final calcTop = position.dy + renderBox.size.height + 6.0;
      if (calcTop > mediaQuery.padding.top &&
          calcTop < mediaQuery.size.height * 0.40) {
        topOffset = calcTop;
      }
      if (position.dx >= 12.0 && position.dx < mediaQuery.size.width * 0.5) {
        leftOffset = position.dx;
      }
    }
  } catch (_) {}

  // 限制最大高度与视图组一致，精致紧凑，绝不遮挡 Hero 标题
  final menuMaxHeight = math.min(mediaQuery.size.height * 0.45, 330.0);

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: isDark ? 0.35 : 0.18),
    transitionDuration: AppTokens.motionFast,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Stack(
        children: [
          Positioned(
            top: topOffset,
            left: leftOffset,
            right: 16,
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 288,
                  maxHeight: menuMaxHeight,
                ),
                child: ScopeSwitcherSheet(currentRoute: route, filter: filter),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          alignment: Alignment.topLeft,
          child: child,
        ),
      );
    },
  );
}

/// 现代极简风格的清单/视图切换浮动卡片（紧凑靠左弹出菜单，带毛玻璃与微光阴影）。
class ScopeSwitcherSheet extends ConsumerWidget {
  const ScopeSwitcherSheet({
    super.key,
    this.currentRoute,
    this.filter = ScopeNavFilter.all,
  });

  final String? currentRoute;
  final ScopeNavFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sheetBg = isDark
        ? AppTokens.surfaceCardDark.withValues(
            alpha: AppTokens.alphaCardFrostedDark,
          )
        : AppTokens.surfaceCardLight.withValues(
            alpha: AppTokens.alphaCardFrostedLight,
          );

    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusSheet),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: BorderRadius.circular(AppTokens.radiusSheet),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isDark
                        ? AppTokens.alphaBorderEmphasis
                        : AppTokens.alphaBorderSubtle,
                  ),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 顶部微光细短装饰把手
                  Center(
                    child: Container(
                      width: 28,
                      height: 3,
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: AppTokens.alphaTintStrong,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusPill,
                        ),
                      ),
                    ),
                  ),

                  // 核心导航树与清单列表（紧凑滚动）
                  Flexible(
                    child: ScopeNavContent(
                      currentRoute: currentRoute,
                      isModal: true,
                      showHeader: false,
                      filter: filter,
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
