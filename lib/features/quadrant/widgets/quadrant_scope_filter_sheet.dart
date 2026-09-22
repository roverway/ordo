import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/preset_icons.dart';
import '../../projects/project_providers.dart';
import '../../tasks/task_providers.dart';
import '../models/quadrant_models.dart';
import '../providers/quadrant_providers.dart';

/// 四象限范围筛选底部抽屉弹层。
///
/// 允许用户按清单和文件夹层级（支持多选、级联与三态显示）
/// 自定义四象限目标任务范围。
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
  final Set<String> _collapsedFolderIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    final filter = ref.watch(quadrantFilterProvider);
    final filterNotifier = ref.read(quadrantFilterProvider.notifier);

    final groupingAsync = ref.watch(projectsByFolderProvider);
    final inboxProjectAsync = ref.watch(inboxProjectProvider);

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
        final inboxId = inboxProjectAsync.value?.id ?? inboxProjectId;

        // 计算所有可用清单的 ID 集合
        final allAvailableIds = <String>{
          inboxId,
          for (final list in grouping.folderProjects.values)
            for (final p in list) p.id,
          for (final p in grouping.ungrouped) p.id,
        };

        final isAllSelected = !filter.isCustomScoped;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
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
                // 顶部抓手 (Grabber)
                Container(
                  width: AppTokens.sheetGrabberWidth,
                  height: AppTokens.sheetGrabberHeight,
                  margin: const EdgeInsets.only(
                    top: AppTokens.spaceSm,
                    bottom: AppTokens.spaceSm,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(
                      alpha: AppTokens.alphaTintStrong,
                    ),
                    borderRadius: BorderRadius.circular(
                      AppTokens.sheetGrabberRadius,
                    ),
                  ),
                ),

                // 标题栏
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceLg,
                    vertical: AppTokens.spaceSm,
                  ),
                  child: Row(
                    children: [
                      Text(
                        l10n.quadrantScopeFilter,
                        style: TextStyle(
                          fontSize: AppTokens.textTitleSize,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      if (filter.isCustomScoped)
                        TextButton(
                          onPressed: () => filterNotifier.resetAll(),
                          child: Text(
                            l10n.quadrantReset,
                            style: TextStyle(
                              fontSize: AppTokens.textCaptionSize,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: Text(
                          l10n.quadrantDone,
                          style: TextStyle(
                            fontSize: AppTokens.textBodySize,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // 可滚动内容区
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.spaceMd,
                      AppTokens.spaceSm,
                      AppTokens.spaceMd,
                      AppTokens.spaceLg,
                    ),
                    children: [
                      // 全选 / 全部范围
                      _buildTile(
                        icon: Icons.layers_outlined,
                        iconColor: AppTokens.colorNavQuadrant,
                        title: l10n.quadrantAllScopes,
                        isChecked: isAllSelected,
                        onTap: () => filterNotifier.resetAll(),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AppTokens.spaceXxs,
                        ),
                        child: Divider(height: 1),
                      ),

                      // 收集箱
                      _buildTile(
                        icon: Icons.inbox_outlined,
                        iconColor: AppTokens.colorNavInbox,
                        title: l10n.inbox,
                        isChecked:
                            isAllSelected ||
                            filter.selectedProjectIds!.contains(inboxId),
                        onTap: () => filterNotifier.toggleProject(
                          inboxId,
                          allAvailableIds,
                        ),
                      ),

                      // 文件夹与下属清单
                      for (final folder in grouping.folders) ...[
                        _buildFolderSection(
                          folder: folder,
                          projects:
                              grouping.folderProjects[folder.id] ?? const [],
                          filter: filter,
                          filterNotifier: filterNotifier,
                          allAvailableIds: allAvailableIds,
                        ),
                      ],

                      // 未分组清单
                      if (grouping.ungrouped.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppTokens.spaceMd,
                            AppTokens.spaceMd,
                            AppTokens.spaceMd,
                            AppTokens.spaceXs,
                          ),
                          child: Text(
                            l10n.quadrantUngroupedLists,
                            style: TextStyle(
                              fontSize: AppTokens.textMicroSize,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: AppTokens.alphaContentMuted,
                              ),
                            ),
                          ),
                        ),
                        for (final project in grouping.ungrouped)
                          _buildProjectTile(
                            project: project,
                            filter: filter,
                            filterNotifier: filterNotifier,
                            allAvailableIds: allAvailableIds,
                            isIndented: false,
                          ),
                      ],

                      const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: AppTokens.spaceMd,
                        ),
                        child: Divider(height: 1),
                      ),

                      // 显示已完成任务切换项
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.spaceSm,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: AppTokens.alphaBorderSubtle,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTokens.radiusList,
                                ),
                              ),
                              child: Icon(
                                Icons.check_circle_outline,
                                color: colorScheme.primary,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: AppTokens.spaceMd),
                            Expanded(
                              child: Text(
                                l10n.quadrantShowCompleted,
                                style: TextStyle(
                                  fontSize: AppTokens.textBodySize,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Switch.adaptive(
                              value: filter.showCompleted,
                              onChanged: (_) =>
                                  filterNotifier.toggleShowCompleted(),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildFolderSection({
    required Folder folder,
    required List<Project> projects,
    required QuadrantFilterState filter,
    required QuadrantFilterNotifier filterNotifier,
    required Set<String> allAvailableIds,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final folderColor = folder.color != null
        ? Color(folder.color!)
        : colorScheme.primary;
    final folderIcon = getIconDataById(
      folder.icon,
      fallback: Icons.folder_outlined,
    );

    final isCollapsed = _collapsedFolderIds.contains(folder.id);
    final projectIds = projects.map((p) => p.id).toList();

    final isAllSelected = !filter.isCustomScoped;
    final selectedCount = isAllSelected
        ? projects.length
        : projects
              .where((p) => filter.selectedProjectIds!.contains(p.id))
              .length;

    final isFullySelected =
        projects.isNotEmpty && selectedCount == projects.length;
    final isPartiallySelected =
        selectedCount > 0 && selectedCount < projects.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppTokens.radiusItem),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusItem),
              onTap: () {
                filterNotifier.toggleFolder(projectIds, allAvailableIds);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceSm,
                  vertical: AppTokens.spaceSm,
                ),
                child: Row(
                  children: [
                    // 折叠切换箭头
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isCollapsed) {
                            _collapsedFolderIds.remove(folder.id);
                          } else {
                            _collapsedFolderIds.add(folder.id);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(
                          right: AppTokens.spaceXxs,
                        ),
                        child: Icon(
                          isCollapsed ? Icons.chevron_right : Icons.expand_more,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: folderColor.withValues(
                          alpha: AppTokens.alphaBorderSubtle,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusList,
                        ),
                      ),
                      child: Icon(folderIcon, color: folderColor, size: 16),
                    ),
                    const SizedBox(width: AppTokens.spaceMd),
                    Expanded(
                      child: Text(
                        '${folder.name} (${projects.length})',
                        style: TextStyle(
                          fontSize: AppTokens.textBodySize,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 三态复选框指示
                    _buildCheckboxIndicator(
                      isChecked: isFullySelected,
                      isIndeterminate: isPartiallySelected,
                      colorScheme: colorScheme,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!isCollapsed)
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final project in projects)
                  _buildProjectTile(
                    project: project,
                    filter: filter,
                    filterNotifier: filterNotifier,
                    allAvailableIds: allAvailableIds,
                    isIndented: true,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProjectTile({
    required Project project,
    required QuadrantFilterState filter,
    required QuadrantFilterNotifier filterNotifier,
    required Set<String> allAvailableIds,
    required bool isIndented,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final projectColor = Color(project.color);
    final projectIcon = getIconDataById(
      project.icon,
      fallback: Icons.checklist_outlined,
    );

    final isChecked =
        !filter.isCustomScoped ||
        filter.selectedProjectIds!.contains(project.id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusItem),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusItem),
          onTap: () {
            filterNotifier.toggleProject(project.id, allAvailableIds);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceSm,
              vertical: AppTokens.spaceSm,
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: projectColor.withValues(
                      alpha: AppTokens.alphaBorderSubtle,
                    ),
                    borderRadius: BorderRadius.circular(AppTokens.radiusList),
                  ),
                  child: Icon(projectIcon, color: projectColor, size: 14),
                ),
                const SizedBox(width: AppTokens.spaceMd),
                Expanded(
                  child: Text(
                    project.name,
                    style: TextStyle(
                      fontSize: AppTokens.textBodySize,
                      fontWeight: isChecked ? FontWeight.w600 : FontWeight.w400,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildCheckboxIndicator(
                  isChecked: isChecked,
                  isIndeterminate: false,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool isChecked,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusItem),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusItem),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceSm,
              vertical: AppTokens.spaceSm,
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(
                      alpha: AppTokens.alphaBorderSubtle,
                    ),
                    borderRadius: BorderRadius.circular(AppTokens.radiusList),
                  ),
                  child: Icon(icon, color: iconColor, size: 16),
                ),
                const SizedBox(width: AppTokens.spaceMd),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: AppTokens.textBodySize,
                      fontWeight: isChecked ? FontWeight.w600 : FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                _buildCheckboxIndicator(
                  isChecked: isChecked,
                  isIndeterminate: false,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckboxIndicator({
    required bool isChecked,
    required bool isIndeterminate,
    required ColorScheme colorScheme,
  }) {
    if (isIndeterminate) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(AppTokens.checkboxRadius),
        ),
        child: const Center(
          child: Icon(Icons.remove, size: 14, color: Colors.white),
        ),
      );
    }

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: isChecked ? colorScheme.primary : Colors.transparent,
        border: Border.all(
          color: isChecked ? colorScheme.primary : colorScheme.outline,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(AppTokens.checkboxRadius),
      ),
      child: isChecked
          ? const Center(
              child: Icon(Icons.check, size: 14, color: Colors.white),
            )
          : null,
    );
  }
}
