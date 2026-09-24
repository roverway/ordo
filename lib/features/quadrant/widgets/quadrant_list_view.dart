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

/// 四象限聚焦列表视图。
///
/// 遵循原型交互与视觉规范：
/// 1. 顶部 Tab Pills：[ 全部 (N) | 重要紧急 (N) | 计划做 (N) | 授权做 (N) | 稍后做 (N) ]；
/// 2. 纵向无级滚动的单列卡片组，针对大任务量象限进行聚焦浏览；
/// 3. 支持跨象限拖拽放置与快捷创建。
class QuadrantListView extends ConsumerWidget {
  const QuadrantListView({super.key, this.data});

  final QuadrantData? data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusTab = ref.watch(quadrantFocusTabProvider);
    final focusTabNotifier = ref.read(quadrantFocusTabProvider.notifier);
    final l10n = AppLocalizations.of(context);

    if (data != null) {
      return _buildViewBody(
        context: context,
        ref: ref,
        data: data!,
        focusTab: focusTab,
        focusTabNotifier: focusTabNotifier,
        l10n: l10n,
      );
    }

    final quadrantDataAsync = ref.watch(quadrantDataProvider);
    return quadrantDataAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text(err.toString())),
      data: (loadedData) => _buildViewBody(
        context: context,
        ref: ref,
        data: loadedData,
        focusTab: focusTab,
        focusTabNotifier: focusTabNotifier,
        l10n: l10n,
      ),
    );
  }

  Widget _buildViewBody({
    required BuildContext context,
    required WidgetRef ref,
    required QuadrantData data,
    required QuadrantType? focusTab,
    required QuadrantFocusTabNotifier focusTabNotifier,
    required AppLocalizations l10n,
  }) {
    return Column(
      children: [
        // 顶部横向滚动 Tab 栏
        _buildTabBar(
          context: context,
          data: data,
          selectedTab: focusTab,
          l10n: l10n,
          onSelect: (tab) => focusTabNotifier.setTab(tab),
        ),

        const SizedBox(height: AppTokens.spaceSm),

        // 纵向列表内容区
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceMd,
              vertical: AppTokens.spaceXs,
            ),
            children: [
              if (focusTab == null) ...[
                // 展示全部 4 个象限分组
                _buildQuadrantGroup(
                  context: context,
                  ref: ref,
                  type: QuadrantType.urgentImportant,
                  tasks: data.q1UrgentImportant,
                  l10n: l10n,
                ),
                const SizedBox(height: AppTokens.spaceMd),
                _buildQuadrantGroup(
                  context: context,
                  ref: ref,
                  type: QuadrantType.notUrgentImportant,
                  tasks: data.q2NotUrgentImportant,
                  l10n: l10n,
                ),
                const SizedBox(height: AppTokens.spaceMd),
                _buildQuadrantGroup(
                  context: context,
                  ref: ref,
                  type: QuadrantType.urgentUnimportant,
                  tasks: data.q3UrgentUnimportant,
                  l10n: l10n,
                ),
                const SizedBox(height: AppTokens.spaceMd),
                _buildQuadrantGroup(
                  context: context,
                  ref: ref,
                  type: QuadrantType.notUrgentUnimportant,
                  tasks: data.q4NotUrgentUnimportant,
                  l10n: l10n,
                ),
              ] else ...[
                // 单个象限聚焦展示
                _buildQuadrantGroup(
                  context: context,
                  ref: ref,
                  type: focusTab,
                  tasks: data.tasksOf(focusTab),
                  l10n: l10n,
                ),
              ],
              const SizedBox(height: AppTokens.spaceXl),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar({
    required BuildContext context,
    required QuadrantData data,
    required QuadrantType? selectedTab,
    required AppLocalizations l10n,
    required ValueChanged<QuadrantType?> onSelect,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceMd),
      child: Row(
        children: [
          // 全部 (N)
          _buildPillItem(
            context: context,
            label: l10n.quadrantTabAll,
            count: data.activeTotalCount,
            isSelected: selectedTab == null,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: AppTokens.spaceXs),
          _buildPillItem(
            context: context,
            label: l10n.quadrantQ1Title,
            count: data.q1UrgentImportant.length,
            isSelected: selectedTab == QuadrantType.urgentImportant,
            accentColor: QuadrantType.urgentImportant.accentColor,
            onTap: () => onSelect(QuadrantType.urgentImportant),
          ),
          const SizedBox(width: AppTokens.spaceXs),
          _buildPillItem(
            context: context,
            label: l10n.quadrantQ2Title,
            count: data.q2NotUrgentImportant.length,
            isSelected: selectedTab == QuadrantType.notUrgentImportant,
            accentColor: QuadrantType.notUrgentImportant.accentColor,
            onTap: () => onSelect(QuadrantType.notUrgentImportant),
          ),
          const SizedBox(width: AppTokens.spaceXs),
          _buildPillItem(
            context: context,
            label: l10n.quadrantQ3Title,
            count: data.q3UrgentUnimportant.length,
            isSelected: selectedTab == QuadrantType.urgentUnimportant,
            accentColor: QuadrantType.urgentUnimportant.accentColor,
            onTap: () => onSelect(QuadrantType.urgentUnimportant),
          ),
          const SizedBox(width: AppTokens.spaceXs),
          _buildPillItem(
            context: context,
            label: l10n.quadrantQ4Title,
            count: data.q4NotUrgentUnimportant.length,
            isSelected: selectedTab == QuadrantType.notUrgentUnimportant,
            accentColor: QuadrantType.notUrgentUnimportant.accentColor,
            onTap: () => onSelect(QuadrantType.notUrgentUnimportant),
          ),
        ],
      ),
    );
  }

  Widget _buildPillItem({
    required BuildContext context,
    required String label,
    required int count,
    required bool isSelected,
    Color? accentColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasWallpaper = AppBackgroundScope.hasWallpaperOf(context);

    final defaultBg = hasWallpaper
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
          color: isSelected ? colorScheme.primary : defaultBg,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(
            color: isSelected ? colorScheme.primary : borderColor,
            width: 0.6,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (accentColor != null && !isSelected) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppTokens.spaceXxs),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: AppTokens.textMicroSize,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: AppTokens.spaceMicro),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceMicro * 2,
                vertical: 0.5,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(
                        alpha: AppTokens.alphaBorderEmphasis,
                      )
                    : (isDark
                          ? AppTokens.surfaceSubtleDark
                          : AppTokens.surfaceSubtleLight),
                borderRadius: BorderRadius.circular(AppTokens.radiusItem),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: AppTokens.textMicroSize,
                  fontWeight: FontWeight.w700,
                  fontFeatures: AppTokens.fontTabular,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuadrantGroup({
    required BuildContext context,
    required WidgetRef ref,
    required QuadrantType type,
    required List<QuadrantTaskView> tasks,
    required AppLocalizations l10n,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasWallpaper = AppBackgroundScope.hasWallpaperOf(context);

    final accentColor = type.accentColor;
    final badgeBg = type.badgeBackgroundColor(context);
    final badgeText = type.badgeTextColor(context);

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
      onWillAcceptWithDetails: (details) => details.data.quadrant != type,
      onAcceptWithDetails: (details) async {
        await ref
            .read(quadrantActionControllerProvider)
            .moveTaskToQuadrant(details.data.task, type);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        final effectiveBorderColor = isHovered
            ? accentColor
            : defaultBorderColor;
        final effectiveBorderWidth = isHovered ? 1.5 : 1.0;

        final groupContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 头部栏
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceSm,
                vertical: AppTokens.spaceXs,
              ),
              child: Row(
                children: [
                  // 纵向色条
                  Container(
                    width: 3.5,
                    height: 14,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(
                        AppTokens.sheetGrabberRadius,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTokens.spaceXs),

                  // 象限名称与副标题
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          type.title(l10n),
                          style: TextStyle(
                            fontSize: AppTokens.textSecondarySize,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppTokens.textPrimaryDark
                                : AppTokens.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(width: AppTokens.spaceXxs),
                        Flexible(
                          child: Text(
                            '· ${type.subtitle(l10n)}',
                            style: TextStyle(
                              fontSize: AppTokens.textMicroSize,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: AppTokens.alphaContentMuted,
                              ),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 数量徽标
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
                  const SizedBox(width: AppTokens.spaceXs),

                  // 新增按钮
                  IconButton(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    tooltip: l10n.quadrantAddTask,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onPressed: () => _openCreateTask(context, ref, type),
                  ),
                ],
              ),
            ),

            Divider(height: 0.5, thickness: 0.5, color: dividerColor),

            // 任务条目
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppTokens.spaceLg,
                  horizontal: AppTokens.spaceMd,
                ),
                child: Center(
                  child: Text(
                    l10n.quadrantListEmpty,
                    style: TextStyle(
                      fontSize: AppTokens.textCaptionSize,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: AppTokens.alphaContentMuted,
                      ),
                    ),
                  ),
                ),
              )
            else
              ...List.generate(
                tasks.length,
                (index) => QuadrantTaskTile(
                  taskView: tasks[index],
                  showDivider: index < tasks.length - 1,
                ),
              ),
          ],
        );

        return _wrapCardContainer(
          child: groupContent,
          cardColor: cardColor,
          borderColor: effectiveBorderColor,
          borderWidth: effectiveBorderWidth,
          hasWallpaper: hasWallpaper,
          isDark: isDark,
        );
      },
    );
  }

  void _openCreateTask(BuildContext context, WidgetRef ref, QuadrantType type) {
    final now = DateTime.now();
    final filter = ref.read(quadrantFilterProvider);
    TaskCreateSheet.show(
      context,
      initialPriority: type.initialPriority,
      initialEndAt: type.initialEndAt(now),
      projectId: filter.selectedProjectIds?.length == 1
          ? filter.selectedProjectIds!.first
          : null,
    );
  }

  Widget _wrapCardContainer({
    required Widget child,
    required Color cardColor,
    required Color borderColor,
    required double borderWidth,
    required bool hasWallpaper,
    required bool isDark,
  }) {
    final borderRadius = BorderRadius.circular(AppTokens.radiusDialog);
    final shadow = BoxShadow(
      color: Colors.black.withValues(
        alpha: isDark
            ? AppTokens.alphaBorderEmphasis
            : AppTokens.alphaTintFaint,
      ),
      blurRadius: hasWallpaper ? 12 : 8,
      offset: const Offset(0, 2),
    );

    if (hasWallpaper) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [shadow],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: AppTokens.blurFrostedGlass,
              sigmaY: AppTokens.blurFrostedGlass,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: borderRadius,
                border: Border.all(color: borderColor, width: borderWidth),
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [shadow],
      ),
      child: child,
    );
  }
}
