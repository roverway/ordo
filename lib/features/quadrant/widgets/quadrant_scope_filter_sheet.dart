import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/settings_card.dart';
import '../../../shared/widgets/unified_hierarchical_folder_selector.dart';
import '../../projects/project_providers.dart';
import '../../tasks/task_providers.dart';
import '../providers/quadrant_providers.dart';

/// 四象限范围筛选底部抽屉弹层。
///
/// 遵循统一设计规范与 FILTER_DESIGN_SPEC.md：
/// 1. 顶部 Header 包含「范围筛选」标题、动态计数徽标、右上角「重置」与「完成」主操作胶囊按钮；
/// 2. 顶部主预设栏「全部清单与范围」支持一键全选/反选；
/// 3. 四象限与自定义视图完全统一的单圆角矩形层级容器 UnifiedHierarchicalFolderContainer；
/// 4. 底部设置风格圆角卡片承载「显示已完成任务」开关；
/// 5. 完全对齐当前设置页面的 SettingsCard 圆角矩形风格与 AppTokens 设计系统。
class QuadrantScopeFilterSheet extends ConsumerStatefulWidget {
  const QuadrantScopeFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuadrantScopeFilterSheet(),
    );
  }

  @override
  ConsumerState<QuadrantScopeFilterSheet> createState() =>
      _QuadrantScopeFilterSheetState();
}

class _QuadrantScopeFilterSheetState
    extends ConsumerState<QuadrantScopeFilterSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final filter = ref.watch(quadrantFilterProvider);
    final filterNotifier = ref.read(quadrantFilterProvider.notifier);

    final groupingAsync = ref.watch(projectsByFolderProvider);
    final inboxProjectAsync = ref.watch(inboxProjectProvider);

    final dividerColor = isDark
        ? AppTokens.borderSubtleNeutralDark
        : AppTokens.slate100;

    return groupingAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(AppTokens.spaceXl),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: AppTokens.sheetTopBorderRadius,
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(AppTokens.spaceXl),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: AppTokens.sheetTopBorderRadius,
        ),
        child: Center(child: Text(e.toString())),
      ),
      data: (grouping) {
        final inbox = inboxProjectAsync.value;
        final inboxId = inbox?.id ?? inboxProjectId;

        // 计算所有可用清单的 ID 集合
        final allAvailableIds = <String>{
          inboxId,
          for (final list in grouping.folderProjects.values)
            for (final p in list) p.id,
          for (final p in grouping.ungrouped) p.id,
        };

        final isAllSelected = !filter.isCustomScoped;
        final selectedIds = isAllSelected
            ? allAvailableIds
            : (filter.selectedProjectIds ?? const <String>{});

        final selectedCount = selectedIds.length;

        // 顶层未分组项目集合（包含收件箱与独立项目）
        final unassignedProjects = <Project>[?inbox, ...grouping.ungrouped];

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: AppTokens.sheetTopBorderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: AppTokens.alphaTintStrong,
                ),
                blurRadius: 36,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 顶部拖拽手柄 (Grabber)
                Center(
                  child: Container(
                    width: AppTokens.sheetGrabberWidth,
                    height: AppTokens.sheetGrabberHeight,
                    margin: const EdgeInsets.only(
                      top: AppTokens.spaceSm,
                      bottom: AppTokens.spaceXxs,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTokens.slate600
                          : AppTokens.slate300,
                      borderRadius: BorderRadius.circular(
                        AppTokens.sheetGrabberRadius,
                      ),
                    ),
                  ),
                ),

                // 1. 顶部 Header 栏：标题 + 动态计数徽标 + 右侧「重置」与「完成」主按钮
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceLg,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.quadrantScopeFilter,
                            style: TextStyle(
                              fontSize: AppTokens.textTitleSize,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppTokens.textPrimaryDark
                                  : AppTokens.slate900,
                            ),
                          ),
                          if (filter.isCustomScoped && selectedCount > 0) ...[
                            const SizedBox(width: AppTokens.spaceXs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary
                                    .withValues(alpha: AppTokens.alphaTintSoft),
                                borderRadius: BorderRadius.circular(AppTokens.radiusItem),
                              ),
                              child: Text(
                                '已选 $selectedCount 项',
                                style: TextStyle(
                                  fontSize: AppTokens.textMicroSize,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (filter.isCustomScoped)
                            TextButton(
                              onPressed: () => filterNotifier.resetAll(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                l10n.quadrantReset,
                                style: TextStyle(
                                  fontSize: AppTokens.textFootnoteSize,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          // 主操作胶囊「完成」按钮 (32dp 高度，16dp 圆角)
                          SizedBox(
                            height: 32,
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                elevation: 1.5,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTokens.radiusDialog),
                                ),
                              ),
                              child: Text(
                                l10n.quadrantDone,
                                style: const TextStyle(
                                  fontSize: AppTokens.textCaptionSize,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, thickness: 0.8, color: dividerColor),

                // 2. 可滚动的主体内容
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.spaceLg,
                      vertical: AppTokens.spaceMd,
                    ),
                    children: [
                      // 顶部大预设栏：「全部清单与范围」
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (isAllSelected) {
                              filterNotifier.setProjectSelection(<String>{});
                            } else {
                              filterNotifier.resetAll();
                            }
                          },
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusCard,
                          ),
                          child: AnimatedContainer(
                            duration: AppTokens.motionFast,
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: isAllSelected
                                  ? colorScheme.primary
                                  : (isDark
                                        ? AppTokens.surfaceSubtleDark
                                        : AppTokens.slate50),
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusCard,
                              ),
                              border: Border.all(
                                color: isAllSelected
                                    ? colorScheme.primary
                                    : (isDark
                                          ? AppTokens.borderSubtleNeutralDark
                                          : AppTokens.slate200),
                                width: 0.8,
                              ),
                              boxShadow: isAllSelected
                                  ? [
                                      BoxShadow(
                                        color: colorScheme.primary
                                            .withValues(alpha: AppTokens.alphaTintStrong),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.layers_outlined,
                                  size: 16,
                                  color: isAllSelected
                                      ? colorScheme.onPrimary
                                      : (isDark
                                            ? AppTokens.textMutedDark
                                            : AppTokens.slate500),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.quadrantAllScopes,
                                  style: TextStyle(
                                    fontSize: AppTokens.textFootnoteSize,
                                    fontWeight: FontWeight.w600,
                                    color: isAllSelected
                                        ? colorScheme.onPrimary
                                        : (isDark
                                              ? AppTokens.textPrimaryDark
                                              : AppTokens.slate800),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(${allAvailableIds.length})',
                                  style: TextStyle(
                                    fontSize: AppTokens.textCaptionSize,
                                    fontWeight: FontWeight.w500,
                                    color: isAllSelected
                                        ? colorScheme.onPrimary
                                              .withValues(alpha: AppTokens.alphaOverlayHeavy)
                                        : (isDark
                                              ? AppTokens.textMutedDark
                                              : AppTokens.slate400),
                                  ),
                                ),
                                const Spacer(),
                                if (isAllSelected) ...[
                                  Text(
                                    '已全选',
                                    style: TextStyle(
                                      fontSize: AppTokens.textCaptionSize,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: colorScheme.onPrimary,
                                  ),
                                ] else ...[
                                  Text(
                                    '一键全选',
                                    style: TextStyle(
                                      fontSize: AppTokens.textCaptionSize,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 统一层级架构单圆角矩形融合容器 (UnifiedHierarchicalFolderContainer)
                      UnifiedHierarchicalFolderContainer(
                        unassignedProjects: unassignedProjects,
                        folders: grouping.folders,
                        folderProjects: grouping.folderProjects,
                        selectedProjectIds: selectedIds,
                        onToggleProject: (projectId) {
                          filterNotifier.toggleProject(
                            projectId,
                            allAvailableIds,
                          );
                        },
                        onToggleGroup: (groupProjectIds, selectAll) {
                          filterNotifier.toggleFolder(
                            groupProjectIds,
                            allAvailableIds,
                          );
                        },
                        unassignedTitle: '顶层与独立清单',
                      ),

                      const SizedBox(height: 14),

                      // 底部设置风格圆角卡片：显示已完成任务
                      SettingsCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTokens.surfaceSubtleDark
                                      : AppTokens.slate100,
                                  borderRadius: BorderRadius.circular(AppTokens.radiusChip),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 15,
                                  color: isDark
                                      ? AppTokens.textMutedDark
                                      : AppTokens.slate600,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l10n.quadrantShowCompleted,
                                  style: TextStyle(
                                    fontSize: AppTokens.textFootnoteSize,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppTokens.textPrimaryDark
                                        : AppTokens.slate800,
                                  ),
                                ),
                              ),
                              Switch.adaptive(
                                value: filter.showCompleted,
                                activeTrackColor: colorScheme.primary,
                                onChanged: (_) =>
                                    filterNotifier.toggleShowCompleted(),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: AppTokens.spaceMd),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
