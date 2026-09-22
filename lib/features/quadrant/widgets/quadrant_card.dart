import 'dart:ui';

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
/// 遵循极简高信噪比规范与设置页面卡片视觉规范：
/// 1. 紧凑头部：高度 38dp，左侧语义色块条 + 粗体象限完整名称 + 语义色数字圆角徽标 + 右侧微型聚焦与新增按钮；
/// 2. 去卡片化任务行：任务项不使用独立实线外边框与卡片背景，仅由发丝级分割线分隔；
/// 3. 设置页面卡片样式：支持圆角、外阴影与自适应壁纸毛玻璃（BackdropFilter）；
/// 4. 跨象限拖拽交互：作为 [DragTarget] 接收其他象限拖入的任务并自动更新属性；
/// 5. 点击新增：直接调起全局 [TaskCreateSheet.show] 并预填优先级与截止日期。
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
        : baseCardColor;

    final defaultBorderColor = isDark
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

    final dividerColor = defaultBorderColor;

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
        final effectiveBorderColor = isHovered ? accentColor : defaultBorderColor;
        final effectiveBorderWidth = isHovered ? 1.5 : 1.0;

        final cardContent = Column(
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
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
                    border: Border.all(
                      color: effectiveBorderColor,
                      width: effectiveBorderWidth,
                    ),
                  ),
                  child: cardContent,
                ),
              ),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
            border: Border.all(
              color: effectiveBorderColor,
              width: effectiveBorderWidth,
            ),
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
          child: cardContent,
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

            // 象限名称：完整展示
            Text(
              title,
              style: TextStyle(
                fontSize: AppTokens.textMicroSize,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
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
                  fontSize: AppTokens.textNanoSize,
                  fontWeight: FontWeight.w700,
                  fontFeatures: AppTokens.fontTabular,
                  color: badgeText,
                ),
              ),
            ),

            const Spacer(),

            // 缩小在右侧的聚焦与添加按钮 (22x22 紧凑按钮)
            if (onFocus != null) ...[
              _buildMiniHeaderButton(
                tooltip: l10n.quadrantFocusMode,
                icon: Icons.fullscreen_outlined,
                iconSize: 15,
                color: colorScheme.onSurfaceVariant,
                onTap: onFocus!,
              ),
              const SizedBox(width: AppTokens.spaceMicro),
            ],

            _buildMiniHeaderButton(
              tooltip: l10n.quadrantAddTask,
              icon: Icons.add_rounded,
              iconSize: 16,
              color: colorScheme.onSurfaceVariant,
              onTap: () => _openCreateTask(context, filter),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniHeaderButton({
    required String tooltip,
    required IconData icon,
    required double iconSize,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusItem),
        onTap: onTap,
        child: SizedBox(
          width: 22,
          height: 22,
          child: Center(
            child: Icon(icon, size: iconSize, color: color),
          ),
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
                  alpha: AppTokens.alphaTintFaint,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.inbox_outlined,
                  size: 16,
                  color: accentColor,
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
    TaskCreateSheet.show(
      context,
      initialPriority: quadrantType.initialPriority,
      initialEndAt: quadrantType.initialEndAt(now),
      projectId: filter.selectedProjectIds?.length == 1
          ? filter.selectedProjectIds!.first
          : null,
    );
  }
}
