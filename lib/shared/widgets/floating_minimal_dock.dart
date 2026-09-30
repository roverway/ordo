import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/preset_icons.dart';
import '../../features/ai_copilot/views/ai_copilot_sheet.dart';
import '../../features/custom_views/providers/custom_view_providers.dart';
import '../../features/custom_views/widgets/icon_picker_dialog.dart';
import '../../features/projects/project_providers.dart';
import '../../features/settings/settings_providers.dart';
import '../../features/tasks/widgets/quick_capture_bar.dart';

/// 移动端悬浮双岛操作栏（Floating Dual-Island Dock）。
///
/// 遵循乔布斯极简设计哲学与 Linear 设计语言：
/// 1. 左岛（Navigation Island）：负责功能区域切换
///    - 1.1 任务清单按钮：短按直达默认任务页，长按直接将当前页面设为默认任务页（弹出 Linear HUD 提示）
///    - 1.2 特殊视图按钮：短按直达默认特殊视图，长按直接将当前页面设为默认特殊视图（弹出 Linear HUD 提示）
///    - 1.3 设置按钮：直达设置页
///    - 1.4 搜索按钮：直达搜索页
/// 2. 右岛（Action Island）：AI 功能与快速新建一体式胶囊
///    - 左侧 AI 星芒按钮：呼出 AI Copilot
///    - 微光超细分割线
///    - 右侧一体化新建按钮：34dp 紧凑圆形，自然微光光晕不截断 + 极速录入待办
/// 3. 两岛靠拢并在屏幕水平方向整体居中对齐。
class FloatingMinimalDock extends ConsumerWidget {
  const FloatingMinimalDock({super.key, this.currentRoute});

  final String? currentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final isZh = l10n.localeName.startsWith('zh');

    // 解析当前路由路径
    String path = currentRoute ?? '';
    if (path.isEmpty) {
      try {
        path = GoRouterState.of(context).uri.path;
      } catch (_) {
        path = '/today';
      }
    }

    // 默认路由读取
    final defaultTasksRoute = ref.watch(defaultTasksRouteProvider);
    final defaultSpecialViewsRoute = ref.watch(
      defaultSpecialViewsRouteProvider,
    );

    // 激活状态判断
    // 1. 任务清单组：今日、收件箱、具体项目清单 (/projects/:id 但非 /projects)
    final isTasksActive =
        path == '/today' ||
        path == '/' ||
        path == '/inbox' ||
        (path.startsWith('/projects/') && path != '/projects');

    // 2. 特殊视图组：四象限、日历、项目概览 (/projects)、自定义视图 (/custom_view/:id)
    final isViewsActive =
        path.startsWith('/matrix') ||
        path.startsWith('/calendar') ||
        path == '/projects' ||
        path.startsWith('/custom_view/');

    // 3. 设置
    final isSettingsActive = path.startsWith('/settings');

    // 4. 搜索
    final isSearchActive = path.startsWith('/search');

    // 动态图标计算
    // 1.1 任务清单组图标（随默认目标动态自适应）
    IconData getTasksIcon(bool isActive) {
      if (defaultTasksRoute == '/today' || defaultTasksRoute == '/') {
        return isActive ? Icons.today_rounded : Icons.today_outlined;
      }
      if (defaultTasksRoute == '/inbox') {
        return isActive ? Icons.inbox_rounded : Icons.inbox_outlined;
      }
      if (defaultTasksRoute.startsWith('/projects/')) {
        final pid = defaultTasksRoute.replaceFirst('/projects/', '');
        final projects = ref.watch(projectsStreamProvider).value;
        final matched = projects?.where((p) => p.id == pid).firstOrNull;
        if (matched != null) {
          return getIconDataById(
            matched.icon,
            fallback: isActive
                ? Icons.check_circle_rounded
                : Icons.check_circle_outline_rounded,
          );
        }
      }
      return isActive
          ? Icons.check_circle_rounded
          : Icons.check_circle_outline_rounded;
    }

    // 1.2 特殊视图组图标（随默认目标动态自适应）
    IconData getViewsIcon(bool isActive) {
      if (defaultSpecialViewsRoute == '/matrix') {
        return isActive ? Icons.grid_view_rounded : Icons.grid_view_outlined;
      }
      if (defaultSpecialViewsRoute == '/calendar') {
        return isActive
            ? Icons.calendar_month_rounded
            : Icons.calendar_month_outlined;
      }
      if (defaultSpecialViewsRoute == '/projects') {
        return isActive
            ? Icons.view_agenda_rounded
            : Icons.view_agenda_outlined;
      }
      if (defaultSpecialViewsRoute.startsWith('/custom_view/')) {
        final vid = defaultSpecialViewsRoute.replaceFirst('/custom_view/', '');
        final views = ref.watch(customViewsStreamProvider).value;
        final matched = views?.where((v) => v.id == vid).firstOrNull;
        if (matched != null) {
          return getCustomViewIcon(matched.icon);
        }
      }
      return isActive ? Icons.grid_view_rounded : Icons.grid_view_outlined;
    }

    final dockBg = isDark
        ? AppTokens.surfaceCardDark.withValues(
            alpha: AppTokens.alphaCardFrostedDark,
          )
        : AppTokens.surfaceCardLight.withValues(
            alpha: AppTokens.alphaCardFrostedLight,
          );

    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 左岛：功能区域切换
          _buildIslandContainer(
            dockBg: dockBg,
            borderColor: borderColor,
            isDark: isDark,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1.1 任务清单按钮 (长按直接设当前页为默认)
                _buildNavItem(
                  icon: getTasksIcon(isTasksActive),
                  color: isTasksActive
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  tooltip: isZh
                      ? '任务清单（长按设当前为默认）'
                      : 'Tasks (Long-press to set default)',
                  onTap: () => _handleTasksTap(context, ref),
                  onLongPress: () => _handleTasksLongPress(
                    context,
                    ref,
                    path,
                    isTasksActive,
                    isZh,
                  ),
                ),

                const SizedBox(width: 4),

                // 1.2 特殊视图按钮 (长按直接设当前页为默认)
                _buildNavItem(
                  icon: getViewsIcon(isViewsActive),
                  color: isViewsActive
                      ? AppTokens.colorNavQuadrant
                      : colorScheme.onSurfaceVariant,
                  tooltip: isZh
                      ? '特殊视图（长按设当前为默认）'
                      : 'Special Views (Long-press to set default)',
                  onTap: () => _handleViewsTap(context, ref),
                  onLongPress: () => _handleViewsLongPress(
                    context,
                    ref,
                    path,
                    isViewsActive,
                    isZh,
                  ),
                ),

                const SizedBox(width: 4),

                // 1.3 设置按钮
                _buildNavItem(
                  icon: isSettingsActive
                      ? Icons.settings_rounded
                      : Icons.settings_outlined,
                  color: isSettingsActive
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  tooltip: l10n.settings,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.push('/settings');
                  },
                ),

                const SizedBox(width: 4),

                // 1.4 搜索按钮
                _buildNavItem(
                  icon: isSearchActive
                      ? Icons.search_rounded
                      : Icons.search_outlined,
                  color: isSearchActive
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  tooltip: l10n.search,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.push('/search');
                  },
                ),
              ],
            ),
          ),

          const SizedBox(width: AppTokens.spaceSm), // 左右两部分紧靠，中间 8dp 间距
          // 右岛：AI 功能与快速新建一体式胶囊
          _buildIslandContainer(
            dockBg: dockBg,
            borderColor: borderColor,
            isDark: isDark,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // AI 星芒按钮
                Tooltip(
                  message: l10n.aiCopilot,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTokens.radiusButton),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      AiCopilotSheet.show(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spaceSm,
                        vertical: AppTokens.spaceXs,
                      ),
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [AppTokens.colorInbox, Colors.cyanAccent],
                        ).createShader(bounds),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),

                // 胶囊中段微光细分割线
                Container(
                  width: 1.0,
                  height: 18.0,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  color: isDark
                      ? Colors.white.withValues(alpha: AppTokens.alphaTintFaint)
                      : Colors.black.withValues(
                          alpha: AppTokens.alphaTintFaint,
                        ),
                ),

                // 快速新建按钮 (缩小至 34dp 直径，光晕完整柔和散发，不被 48dp 操作栏截断)
                SizedBox(
                  width: 34,
                  height: 34,
                  child: FloatingActionButton.small(
                    heroTag: 'dock_quick_add_fab_hero',
                    tooltip: l10n.newTask,
                    elevation: 0,
                    focusElevation: 0,
                    hoverElevation: 0,
                    highlightElevation: 0,
                    backgroundColor: Colors.transparent,
                    shape: const CircleBorder(),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      QuickCaptureBar.show(context);
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primary,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(
                              alpha: isDark
                                  ? AppTokens.alphaBorderEmphasis
                                  : 0.38,
                            ),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIslandContainer({
    required Color dockBg,
    required Color borderColor,
    required bool isDark,
    required EdgeInsetsGeometry padding,
    required Widget child,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: dockBg,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark
                  ? AppTokens.alphaBorderEmphasis
                  : AppTokens.alphaBorderSubtle,
            ),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: Colors.transparent,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  void _handleTasksTap(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    final defaultRoute = ref.read(defaultTasksRouteProvider);

    // 容错校验：若目标路由为清单，校验该清单是否仍然存在，否则回退到今日
    if (defaultRoute.startsWith('/projects/')) {
      final projectId = defaultRoute.replaceFirst('/projects/', '');
      final projects = ref.read(projectsStreamProvider).value;
      if (projects != null && !projects.any((p) => p.id == projectId)) {
        context.go('/today');
        return;
      }
    }

    context.go(defaultRoute);
  }

  void _handleViewsTap(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    final defaultRoute = ref.read(defaultSpecialViewsRouteProvider);

    // 容错校验：若目标路由为自定义视图，校验该视图是否仍然存在，否则回退到四象限
    if (defaultRoute.startsWith('/custom_view/')) {
      final viewId = defaultRoute.replaceFirst('/custom_view/', '');
      final views = ref.read(customViewsStreamProvider).value;
      if (views != null && !views.any((v) => v.id == viewId)) {
        context.go('/matrix');
        return;
      }
    }

    context.go(defaultRoute);
  }

  void _handleTasksLongPress(
    BuildContext context,
    WidgetRef ref,
    String currentPath,
    bool isTasksActive,
    bool isZh,
  ) {
    if (!isTasksActive) {
      _showToast(
        context,
        isZh ? '请先进入目标清单或今日页面再长按设为默认' : 'Please navigate to a task list first',
      );
      return;
    }

    HapticFeedback.heavyImpact();
    ref
        .read(defaultTasksRouteProvider.notifier)
        .setDefaultTasksRoute(currentPath);
    _showToast(
      context,
      isZh ? '已将当前页面设为默认任务清单' : 'Set current page as default task list',
    );
  }

  void _handleViewsLongPress(
    BuildContext context,
    WidgetRef ref,
    String currentPath,
    bool isViewsActive,
    bool isZh,
  ) {
    if (!isViewsActive) {
      _showToast(
        context,
        isZh
            ? '请先进入目标视图或日历页面再长按设为默认'
            : 'Please navigate to a special view first',
      );
      return;
    }

    HapticFeedback.heavyImpact();
    ref
        .read(defaultSpecialViewsRouteProvider.notifier)
        .setDefaultSpecialViewsRoute(currentPath);
    _showToast(
      context,
      isZh ? '已将当前页面设为默认特殊视图' : 'Set current view as default special view',
    );
  }

  void _showToast(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontSize: AppTokens.textBodySize,
            fontWeight: FontWeight.w500,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
        ),
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.only(bottom: 76, left: 24, right: 24),
      ),
    );
  }
}
