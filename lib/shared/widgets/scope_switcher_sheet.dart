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

/// 呼出清单/作用域切换浮动菜单（从 Hero 标题下方弹出，左右不占满屏幕）。
Future<void> showScopeSwitcherSheet(
  BuildContext context, {
  String? currentRoute,
  ScopeNavFilter filter = ScopeNavFilter.all,
}) {
  final route = currentRoute ?? resolveCurrentRoute(context);
  final mediaQuery = MediaQuery.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  // 尝试获取触发组件在屏幕中的全局位置，以紧贴 Hero 标题正下方弹出
  double topOffset = mediaQuery.padding.top + 64.0;
  try {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final position = renderBox.localToGlobal(Offset.zero);
      final calcTop = position.dy + renderBox.size.height + 4;
      if (calcTop > mediaQuery.padding.top &&
          calcTop < mediaQuery.size.height * 0.45) {
        topOffset = calcTop;
      }
    }
  } catch (_) {}

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: isDark ? 0.45 : 0.25),
    transitionDuration: AppTokens.motionFast,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Stack(
        children: [
          Positioned(
            top: topOffset,
            left: 16,
            right: 16,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 380,
                  maxHeight: mediaQuery.size.height * 0.65,
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
          alignment: Alignment.topCenter,
          child: child,
        ),
      );
    },
  );
}

/// 现代极简风格的清单/视图切换浮动卡片（不占满全宽，带毛玻璃与微光阴影）。
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
                  blurRadius: 32,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部微光短装饰条
                  Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: AppTokens.alphaTintStrong,
                      ),
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    ),
                  ),

                  // 核心导航树与清单列表
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
