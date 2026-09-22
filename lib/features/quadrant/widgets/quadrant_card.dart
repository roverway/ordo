import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/tables.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../projects/project_providers.dart';
import '../../settings/settings_providers.dart';
import '../../tasks/widgets/task_create_sheet.dart';
import '../models/quadrant_models.dart';
import '../providers/quadrant_providers.dart';
import 'quadrant_task_tile.dart';

/// 单个象限卡片容器。
///
/// 具备独立标题栏（标题、副标题、任务计数角标、聚焦按钮、快速添加按钮）、
/// 拖拽放置目标（[DragTarget]）、任务列表滚动区及空态说明。
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
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final hasWallpaper = ref.watch(appBackgroundConfigProvider).isEffective;
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
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

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

        return Container(
          decoration: BoxDecoration(
            color: isHovered
                ? accentColor.withValues(alpha: AppTokens.alphaTintFaint)
                : cardColor,
            borderRadius: BorderRadius.circular(AppTokens.radiusCard),
            border: Border.all(
              color: isHovered
                  ? accentColor
                  : defaultBorderColor.withValues(
                      alpha: AppTokens.alphaBorderSubtle,
                    ),
              width: isHovered ? 1.5 : 1.0,
            ),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: accentColor.withValues(
                        alpha: AppTokens.alphaBorderEmphasis,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 象限头部
              _buildHeader(
                context: context,
                ref: ref,
                colorScheme: colorScheme,
                l10n: l10n,
                accentColor: accentColor,
                filter: filter,
              ),

              const Divider(height: 1),

              // 任务列表或空态
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.spaceXs,
                          vertical: AppTokens.spaceXs,
                        ),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) =>
                            QuadrantTaskTile(taskView: tasks[index]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader({
    required BuildContext context,
    required WidgetRef ref,
    required ColorScheme colorScheme,
    required AppLocalizations l10n,
    required Color accentColor,
    required QuadrantFilterState filter,
  }) {
    final title = _getQuadrantTitle(l10n);
    final subtitle = _getQuadrantSubtitle(l10n);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceSm,
        AppTokens.spaceXs,
        AppTokens.spaceXs,
        AppTokens.spaceXs,
      ),
      child: Row(
        children: [
          // 色标指示块
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(AppTokens.radiusMicro),
            ),
          ),
          const SizedBox(width: AppTokens.spaceXs),

          // 标题与副标题
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: AppTokens.textBodySize,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppTokens.spaceXxs),
                    // 计数微标
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spaceXxs,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(
                          alpha: AppTokens.alphaBorderSubtle,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusMicro,
                        ),
                      ),
                      child: Text(
                        '${tasks.length}',
                        style: TextStyle(
                          fontSize: AppTokens.textMicroSize,
                          fontWeight: FontWeight.w600,
                          fontFeatures: AppTokens.fontTabular,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: AppTokens.textMicroSize,
                    color: colorScheme.onSurfaceVariant.withValues(
                      alpha: AppTokens.alphaContentMuted,
                    ),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 聚焦展开按钮
          if (onFocus != null)
            IconButton(
              icon: const Icon(Icons.fullscreen_outlined, size: 18),
              tooltip: l10n.quadrantFocusMode,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onFocus,
            ),

          // 快速新建按钮
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => _openCreateTask(context, filter),
          ),
        ],
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
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 28,
              color: colorScheme.onSurfaceVariant.withValues(
                alpha: AppTokens.alphaBorderEmphasis,
              ),
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Text(
              l10n.quadrantEmpty,
              style: TextStyle(
                fontSize: AppTokens.textCaptionSize,
                color: colorScheme.onSurfaceVariant.withValues(
                  alpha: AppTokens.alphaContentMuted,
                ),
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusList),
              onTap: () => _openCreateTask(context, filter),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceSm,
                  vertical: AppTokens.spaceXxs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: accentColor),
                    const SizedBox(width: AppTokens.spaceXxs),
                    Text(
                      l10n.newTask,
                      style: TextStyle(
                        fontSize: AppTokens.textCaptionSize,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
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
    final endOfToday = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
    ).millisecondsSinceEpoch;

    // 单个清单筛选时直接归属该清单，否则默认 inbox
    final targetProjectId =
        (filter.selectedProjectIds != null &&
            filter.selectedProjectIds!.length == 1)
        ? filter.selectedProjectIds!.first
        : inboxProjectId;

    final targetPriority =
        (quadrantType == QuadrantType.urgentImportant ||
            quadrantType == QuadrantType.notUrgentImportant)
        ? TaskPriority.high
        : TaskPriority.none;

    final targetEndAt =
        (quadrantType == QuadrantType.urgentImportant ||
            quadrantType == QuadrantType.urgentUnimportant)
        ? endOfToday
        : null;

    TaskCreateSheet.show(
      context,
      projectId: targetProjectId,
      initialPriority: targetPriority,
      initialEndAt: targetEndAt,
    );
  }

  String _getQuadrantTitle(AppLocalizations l10n) {
    return switch (quadrantType) {
      QuadrantType.urgentImportant => l10n.quadrantQ1Title,
      QuadrantType.notUrgentImportant => l10n.quadrantQ2Title,
      QuadrantType.urgentUnimportant => l10n.quadrantQ3Title,
      QuadrantType.notUrgentUnimportant => l10n.quadrantQ4Title,
    };
  }

  String _getQuadrantSubtitle(AppLocalizations l10n) {
    return switch (quadrantType) {
      QuadrantType.urgentImportant => l10n.quadrantQ1Subtitle,
      QuadrantType.notUrgentImportant => l10n.quadrantQ2Subtitle,
      QuadrantType.urgentUnimportant => l10n.quadrantQ3Subtitle,
      QuadrantType.notUrgentUnimportant => l10n.quadrantQ4Subtitle,
    };
  }
}
