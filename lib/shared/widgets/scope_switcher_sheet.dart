import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import 'scope_nav_content.dart';

/// 呼出任务清单组上下文切换浮动菜单（今日、收件箱、各项目清单与文件夹）。
Future<void> showTaskScopeSheet(
  BuildContext context, {
  BuildContext? anchorContext,
  String? currentRoute,
}) {
  return showScopeSwitcherSheet(
    context,
    anchorContext: anchorContext,
    currentRoute: currentRoute,
    filter: ScopeNavFilter.tasksOnly,
  );
}

/// 呼出特殊视图组上下文切换浮动菜单（四象限、日历、概览、自定义视图）。
Future<void> showViewScopeSheet(
  BuildContext context, {
  BuildContext? anchorContext,
  String? currentRoute,
}) {
  return showScopeSwitcherSheet(
    context,
    anchorContext: anchorContext,
    currentRoute: currentRoute,
    filter: ScopeNavFilter.viewsOnly,
  );
}

/// 呼出清单/作用域切换浮动菜单。
///
/// 遵循极简 Popover 弹出菜单设计：
/// 1. 紧贴 Hero 标题正下方展开，靠左对齐，绝不遮挡 Hero 标题与副标题；
/// 2. 宽度紧凑（288dp），如原生随手唤出的弹出菜单，不占满全宽；
/// 3. 动态黄金比例高度（最高 400dp / 54% 屏幕高度），配合底部自然渐隐与滚动感知，长列表下兼顾轻盈与承载力。
Future<void> showScopeSwitcherSheet(
  BuildContext context, {
  BuildContext? anchorContext,
  String? currentRoute,
  ScopeNavFilter filter = ScopeNavFilter.all,
}) {
  final route = currentRoute ?? resolveCurrentRoute(context);
  final mediaQuery = MediaQuery.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  // 默认根据分组给一个优雅保底 offset（任务组含两行标题约 88dp+；视图组单行约 56dp+）
  final isTasksOnly = filter == ScopeNavFilter.tasksOnly;
  double topOffset = mediaQuery.padding.top + (isTasksOnly ? 88.0 : 56.0);
  double leftOffset = 16.0;

  final targetContext = anchorContext ?? context;
  try {
    final renderBox = targetContext.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      // 只有当获取到的元素高度小于屏幕高度的 35% 时（排除整页 Scaffold 容器），才视为局部 Header 锚点
      if (size.height < mediaQuery.size.height * 0.35) {
        final calcTop = position.dy + size.height + 6.0;
        if (calcTop > mediaQuery.padding.top &&
            calcTop < mediaQuery.size.height * 0.50) {
          topOffset = calcTop;
        }
        if (position.dx >= 12.0 && position.dx < mediaQuery.size.width * 0.5) {
          leftOffset = position.dx;
        }
      }
    }
  } catch (_) {}

  // 黄金比例动态高度，最高 400dp，透出呼吸透光空间
  final menuMaxHeight = math.min(mediaQuery.size.height * 0.54, 400.0);

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

/// 现代极简风格的清单/视图切换浮动卡片（紧凑靠左弹出菜单，带毛玻璃、微光阴影与滚动渐隐感知）。
class ScopeSwitcherSheet extends ConsumerStatefulWidget {
  const ScopeSwitcherSheet({
    super.key,
    this.currentRoute,
    this.filter = ScopeNavFilter.all,
  });

  final String? currentRoute;
  final ScopeNavFilter filter;

  @override
  ConsumerState<ScopeSwitcherSheet> createState() => _ScopeSwitcherSheetState();
}

class _ScopeSwitcherSheetState extends ConsumerState<ScopeSwitcherSheet> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollDown = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final canScroll =
        pos.maxScrollExtent > 4 && pos.pixels < pos.maxScrollExtent - 4;
    if (canScroll != _canScrollDown) {
      setState(() => _canScrollDown = canScroll);
    }
  }

  @override
  Widget build(BuildContext context) {
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

                  // 核心导航树与清单列表（紧凑滚动 + 底部渐隐指示）
                  Flexible(
                    child: Stack(
                      children: [
                        ScopeNavContent(
                          currentRoute: widget.currentRoute,
                          isModal: true,
                          showHeader: false,
                          filter: widget.filter,
                          scrollController: _scrollController,
                        ),

                        // 底部渐隐遮罩 + 细微呼吸指示，直觉化引导滚动，到底部时平滑消失
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 24,
                          child: IgnorePointer(
                            child: AnimatedOpacity(
                              opacity: _canScrollDown ? 1.0 : 0.0,
                              duration: AppTokens.motionFast,
                              curve: Curves.easeOutCubic,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(
                                      AppTokens.radiusSheet,
                                    ),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      sheetBg.withValues(
                                        alpha: AppTokens.alphaTransparent,
                                      ),
                                      sheetBg.withValues(
                                        alpha:
                                            AppTokens.alphaOverlayNearlyOpaque,
                                      ),
                                    ],
                                  ),
                                ),
                                alignment: Alignment.bottomCenter,
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 14,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(
                                        alpha: AppTokens.alphaBorderEmphasis,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
