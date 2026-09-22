import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_background_wrapper.dart';
import '../../projects/project_providers.dart';
import '../models/quadrant_models.dart';
import '../providers/quadrant_providers.dart';
import 'quadrant_scope_filter_sheet.dart';

/// 四象限顶部工具筛选条。
///
/// 包含两项核心能力：
/// 1. 左侧：[ 全部项目 (N) ⌵ ] 胶囊，展示当前筛选作用域及任务数，点击呼出清单选择抽屉；
/// 2. 右侧：[ 2x2 矩阵 | 聚焦列表 ] 胶囊分段切换器，平滑切换双视图模式。
class QuadrantFilterBar extends ConsumerWidget {
  const QuadrantFilterBar({super.key, required this.totalTasksCount});

  final int totalTasksCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasWallpaper = AppBackgroundScope.hasWallpaperOf(context);
    final l10n = AppLocalizations.of(context);

    final filter = ref.watch(quadrantFilterProvider);
    final viewMode = ref.watch(quadrantViewModeProvider);
    final viewModeNotifier = ref.read(quadrantViewModeProvider.notifier);

    // 解析当前作用域文案
    String scopeLabel = l10n.quadrantAllProjects;
    if (filter.selectedProjectIds != null) {
      final projectsMap = ref.watch(projectsMapProvider);
      if (filter.selectedProjectIds!.length == 1) {
        final pid = filter.selectedProjectIds!.first;
        scopeLabel = projectsMap[pid]?.name ?? l10n.inbox;
      } else {
        scopeLabel = '${filter.selectedProjectIds!.length} 个清单';
      }
    }

    // 壁纸与主题色自适应
    final capsuleBg = hasWallpaper
        ? (isDark
              ? AppTokens.surfaceCardDark.withValues(
                  alpha: AppTokens.alphaCardFrostedDark,
                )
              : AppTokens.surfaceCardLight.withValues(
                  alpha: AppTokens.alphaCardFrostedLight,
                ))
        : (isDark ? colorScheme.surfaceContainerHighest : Colors.white);

    final borderColor = isDark
        ? AppTokens.borderSubtleDark.withValues(
            alpha: AppTokens.alphaBorderSubtle,
          )
        : (hasWallpaper
              ? Colors.white.withValues(alpha: AppTokens.alphaBorderSubtle)
              : AppTokens.borderSubtleNeutralLight);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceXs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左侧：项目范围筛选胶囊
          InkWell(
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            onTap: () => QuadrantScopeFilterSheet.show(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceSm,
                vertical: AppTokens.spaceXxs,
              ),
              decoration: BoxDecoration(
                color: capsuleBg,
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                border: Border.all(color: borderColor, width: 0.6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    scopeLabel,
                    style: TextStyle(
                      fontSize: AppTokens.textMicroSize,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceMicro),
                  Text(
                    '($totalTasksCount)',
                    style: TextStyle(
                      fontSize: AppTokens.textMicroSize,
                      fontFeatures: AppTokens.fontTabular,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: AppTokens.alphaContentMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // 右侧：[ 2x2 矩阵 | 聚焦列表 ] 分段控制器
          Container(
            padding: const EdgeInsets.all(2.0),
            decoration: BoxDecoration(
              color: capsuleBg,
              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              border: Border.all(color: borderColor, width: 0.6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSegmentButton(
                  context: context,
                  label: l10n.quadrantViewMatrix,
                  isSelected: viewMode == QuadrantViewMode.matrix,
                  onTap: () =>
                      viewModeNotifier.setMode(QuadrantViewMode.matrix),
                ),
                _buildSegmentButton(
                  context: context,
                  label: l10n.quadrantViewList,
                  isSelected: viewMode == QuadrantViewMode.list,
                  onTap: () => viewModeNotifier.setMode(QuadrantViewMode.list),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppTokens.motionFast,
        curve: AppTokens.motionSpring,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceSm,
          vertical: AppTokens.spaceXxs,
        ),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppTokens.textMicroSize,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
