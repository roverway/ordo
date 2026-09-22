import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_background_wrapper.dart';
import '../../tasks/widgets/task_create_sheet.dart';
import '../models/quadrant_models.dart';
import '../providers/quadrant_providers.dart';
import 'quadrant_task_tile.dart';

/// 2x2 网格中的单个象限卡片组件。
///
/// 遵循极简高信噪比规范：
/// 1. 紧凑头部：高度 38dp，左侧语义色块条 + 粗体标题 + 语义色数字圆角徽标 + 右侧聚焦与新增按钮；
/// 2. 去卡片化任务行：任务项不使用独立实线外边框与卡片背景，仅由发丝级分割线分隔；
/// 3. 支持壁纸与深浅色模式：在有壁纸时启用半透明毛玻璃材质底色与微边框；
/// 4. 跨象限拖拽交互：作为 [DragTarget] 接收其他象限拖入的任务并自动更新属性。
class QuadrantCard extends ConsumerWidget {
  const QuadrantCard({
    super.key,
    required this.quadrantType,
    required this.tasks,
    this.onFocus,
  });

  final QuadrantType quadrantType;
  final List<QuadrantTaskView> tasks;
  final VoidCallback? onFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasWallpaper = AppBackgroundScope.hasWallpaperOf(context);
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(quadrantFilterProvider);
    final accentColor = quadrantType.accentColor;

    final baseCardColor = isDark
        ? AppTokens.surfaceCardDark
        : AppTokens.surfaceCardLight;
    final cardColor = hasWallpaper
        ? baseCardColor.withValues(
            alpha: isDark
                ? AppTokens.alphaCardFrostedDark
                : AppTokens.alphaCardFrostedLight,
          )
        : (isDark ? colorScheme.surface : Colors.white);

    final defaultBorderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleNeutralLight;

    final dividerColor = isDark
        ? AppTokens.borderSubtleDark.withValues(
            alpha: AppTokens.alphaBorderSubtle,
          )
        : (hasWallpaper
              ? Colors.white.withValues(alpha: AppTokens.alphaBorderSubtle)
              : AppTokens.borderSubtleNeutralLight);

    return DragTarget<QuadrantTaskView>(
      onWillAcceptWithDetails: (details) =>
          details.data.quadrant != quadrantType,
      onAcceptWithDetails: (details) async {
        await ref
            .read(quadrantActionControllerProvider)
            .moveTaskToQuadrant(details.data.task, quadrantType);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: AppTokens.motionFast,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppTokens.radiusDialog), // 16dp
            border: Border.all(
              color: isHovered
                  ? accentColor
                  : (hasWallpaper
                        ? defaultBorderColor.withValues(
                            alpha: AppTokens.alphaBorderEmphasis,
                          )
                        : defaultBorderColor),
              width: isHovered ? 1.5 : 0.6,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 紧凑卡片头部 (38dp)
              _buildCompactHeader(
                context: context,
                ref: ref,
                colorScheme: colorScheme,
                l10n: l10n,
                accentColor: accentColor,
                filter: filter,
              ),

              Divider(height: 0.5, thickness: 0.5, color: dividerColor),

              // 任务列表或精炼空状态
              Expanded(
                child: tasks.isEmpty
                    ? _buildEmptyPlaceholder(
                        context: context,
                        ref: ref,
                        colorScheme: colorScheme,
                        l10n: l10n,
                        accentColor: accentColor,
                        filter: filter,
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: tasks.length,
                        itemBuilder: (context, index) => QuadrantTaskTile(
                          taskView: tasks[index],
                          showDivider: index < tasks.length - 1,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactHeader({
    required BuildContext context,
    required WidgetRef ref,
    required ColorScheme colorScheme,
    required AppLocalizations l10n,
    required Color accentColor,
    required QuadrantFilterState filter,
  }) {
    final title = quadrantType.title(l10n);
    final badgeBg = quadrantType.badgeBackgroundColor(context);
    final badgeText = quadrantType.badgeTextColor(context);

    return SizedBox(
      height: 38,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceSm,
          vertical: AppTokens.spaceXxs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 纵向语义色条 (3.5x13dp)
            Container(
              width: 3.5,
              height: 13,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(
                  AppTokens.sheetGrabberRadius,
                ),
              ),
            ),
            const SizedBox(width: AppTokens.spaceXs),

            // 象限标题 (12sp 粗体)
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: AppTokens.textCaptionSize,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppTokens.spaceXxs),

            // 紧凑圆角数量徽标
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceXs * 0.75,
                vertical: 1.5,
              ),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(AppTokens.radiusItem),
              ),
              child: Text(
                '${tasks.length}',
                style: TextStyle(
                  fontSize: AppTokens.textMicroSize,
                  fontWeight: FontWeight.w700,
                  fontFeatures: AppTokens.fontTabular,
                  color: badgeText,
                ),
              ),
            ),

            const Spacer(),

            // 全屏聚焦按钮 ⛶
            if (onFocus != null)
              IconButton(
                icon: const Icon(Icons.fullscreen_outlined, size: 18),
                tooltip: l10n.quadrantFocusMode,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onFocus,
              ),

            // 快速新增按钮 +
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 18),
              tooltip: l10n.quadrantAddTask,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              onPressed: () => _openCreateTask(context, filter),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder({
    required BuildContext context,
    required WidgetRef ref,
    required ColorScheme colorScheme,
    required AppLocalizations l10n,
    required Color accentColor,
    required QuadrantFilterState filter,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
          vertical: AppTokens.spaceSm,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accentColor.withValues(
                  alpha: AppTokens.alphaTintSoft * 0.7,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.inbox_outlined,
                  size: 16,
                  color: accentColor.withValues(
                    alpha: AppTokens.alphaBorderEmphasis,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Text(
              l10n.quadrantEmpty,
              style: TextStyle(
                fontSize: AppTokens.textMicroSize,
                color: colorScheme.onSurfaceVariant.withValues(
                  alpha: AppTokens.alphaContentMuted,
                ),
              ),
            ),
            const SizedBox(height: AppTokens.spaceXs),
            InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusList),
              onTap: () => _openCreateTask(context, filter),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceXs,
                  vertical: AppTokens.spaceXxs,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.primary.withValues(
                      alpha: AppTokens.alphaBorderEmphasis,
                    ),
                    width: 0.8,
                  ),
                  borderRadius: BorderRadius.circular(AppTokens.radiusList),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 13,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: AppTokens.spaceMicro),
                    Text(
                      l10n.quadrantAddTask,
                      style: TextStyle(
                        fontSize: AppTokens.textMicroSize,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreateTask(BuildContext context, QuadrantFilterState filter) {
    final now = DateTime.now();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskCreateSheet(
        initialPriority: quadrantType.initialPriority,
        initialEndAt: quadrantType.initialEndAt(now),
        projectId: filter.selectedProjectIds?.length == 1
            ? filter.selectedProjectIds!.first
            : null,
      ),
    );
  }
}
