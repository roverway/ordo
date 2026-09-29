import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/ai_copilot/views/ai_copilot_sheet.dart';
import '../../features/tasks/widgets/quick_capture_bar.dart';

/// 移动端底部悬浮极简胶囊坞（Floating Minimal Dock）。
///
/// 遵循乔布斯极端极简与单手拇指热区哲学：
/// 1. 悬浮居中圆角胶囊（48dp 高度，圆角 24dp，磨砂毛玻璃 16，细微微光描边）；
/// 2. 拇指黄金扇形区：
///    - 左侧：今日 (Today)、日历 (Calendar)
///    - 中央：灵感捕捉加号 (Quick Capture +)，短按极速录入，长按呼唤 AI 智能助手
///    - 右侧：象限 (Matrix)、清单 (Projects)、全局搜索 (Search)
class FloatingMinimalDock extends ConsumerWidget {
  const FloatingMinimalDock({super.key, this.currentRoute});

  final String? currentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    // 解析当前路由路径
    String path = currentRoute ?? '';
    if (path.isEmpty) {
      try {
        path = GoRouterState.of(context).uri.path;
      } catch (_) {
        path = '/today';
      }
    }

    final isToday = path == '/today' || path == '/';
    final isCalendar = path.startsWith('/calendar');
    final isMatrix = path.startsWith('/matrix');
    final isProjects = path.startsWith('/projects');

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

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: AppTokens.spaceMd),
      decoration: BoxDecoration(
        color: dockBg,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark
                  ? AppTokens.alphaBorderEmphasis
                  : AppTokens.alphaTintFaint,
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceSm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. 今日
                _buildNavItem(
                  context: context,
                  icon: isToday
                      ? Icons.wb_sunny_rounded
                      : Icons.wb_sunny_outlined,
                  color: isToday
                      ? AppTokens.colorNavToday
                      : colorScheme.onSurfaceVariant,
                  tooltip: l10n.navToday,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.go('/today');
                  },
                ),

                const SizedBox(width: AppTokens.spaceXs),

                // 2. 日历
                _buildNavItem(
                  context: context,
                  icon: isCalendar
                      ? Icons.calendar_today_rounded
                      : Icons.calendar_today_outlined,
                  color: isCalendar
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  tooltip: l10n.navCalendar,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.go('/calendar');
                  },
                ),

                const SizedBox(width: AppTokens.spaceSm),

                // 3. 中央快速新建灵感胶囊按键（+）
                _buildQuickAddButton(context, l10n, colorScheme),

                const SizedBox(width: AppTokens.spaceSm),

                // 4. 四象限
                _buildNavItem(
                  context: context,
                  icon: isMatrix
                      ? Icons.grid_view_rounded
                      : Icons.grid_view_outlined,
                  color: isMatrix
                      ? AppTokens.colorNavQuadrant
                      : colorScheme.onSurfaceVariant,
                  tooltip: l10n.navQuadrant,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.go('/matrix');
                  },
                ),

                const SizedBox(width: AppTokens.spaceXs),

                // 5. 清单 / 概览
                _buildNavItem(
                  context: context,
                  icon: isProjects
                      ? Icons.folder_rounded
                      : Icons.folder_outlined,
                  color: isProjects
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  tooltip: l10n.overview,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.go('/projects');
                  },
                ),

                const SizedBox(width: AppTokens.spaceXs),

                // 6. 全局搜索
                _buildNavItem(
                  context: context,
                  icon: Icons.search_rounded,
                  color: colorScheme.onSurfaceVariant,
                  tooltip: l10n.search,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.push('/search');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(icon, color: color, size: 20),
      tooltip: tooltip,
      splashRadius: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: onTap,
    );
  }

  Widget _buildQuickAddButton(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    return Tooltip(
      message: l10n.newTask,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          QuickCaptureBar.show(context);
        },
        onLongPress: () {
          HapticFeedback.heavyImpact();
          AiCopilotSheet.show(context);
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.primary,
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(
                  alpha: AppTokens.alphaBorderEmphasis,
                ),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.add_rounded,
            color: colorScheme.onPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}
