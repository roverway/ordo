import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/platform/keyboard_inset_bridge.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../projects/project_providers.dart';
import '../../../projects/widgets/create_list_folder_sheet.dart';
import '../../task_providers.dart';

/// 顶部栏项目切换：[项目图标] 文件夹/项目名 [下拉双箭头]（编辑中直接切换所属项目）。
class TaskProjectSwitcher extends ConsumerWidget {
  const TaskProjectSwitcher({super.key, this.interactive = true});

  /// 编辑已有任务时传 false：仅展示项目名（跨项目移动未实现，编辑态隐藏
  /// 误导性切换入口；新建态保留切换，59 讨论定稿）。
  final bool interactive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final projectId = ref.watch(taskFormProvider.select((s) => s.projectId));
    final projects =
        ref.watch(projectsStreamProvider).value ?? const <Project>[];
    final project = projects.where((p) => p.id == projectId).firstOrNull;

    final folders = ref.watch(foldersStreamProvider).value ?? const <Folder>[];
    final folder = folders.where((f) => f.id == project?.folderId).firstOrNull;

    final displayName = folder != null
        ? '${folder.name} / ${project!.name}'
        : (project?.name ?? (projectId == inboxProjectId ? l10n.inbox : ''));

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 项目图标：彩色圆点（与清单选择器一致的设计语言）。
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: project != null
                ? Color(project.color)
                : (projectId == inboxProjectId
                      ? AppTokens.colorNavInbox
                      : AppTokens.colorCancelled),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppTokens.spaceXs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: AppTokens.textTitleWeight,
            ),
          ),
        ),
        if (interactive) ...[
          const SizedBox(width: AppTokens.spaceXxs),
          Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ],
    );

    final padding = const EdgeInsets.symmetric(
      vertical: AppTokens.spaceXs,
      horizontal: AppTokens.spaceXxs,
    );
    if (!interactive) return Padding(padding: padding, child: content);

    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radiusButton),
      onTap: () => showTaskProjectPicker(context, ref),
      child: Padding(padding: padding, child: content),
    );
  }
}

/// 「移动到」清单选择：搜索 + 文件夹层级/收件箱/未分组列表（当前项对勾）+ 添加项目。
Future<void> showTaskProjectPicker(BuildContext context, WidgetRef ref) async {
  final projectId = ref.read(taskFormProvider.select((s) => s.projectId));
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppTokens.radiusDialog),
      ),
    ),
    builder: (sheetContext) => KeyboardInsetBuilder(
      child: RepaintBoundary(
        child: ProjectPickerSheet(currentProjectId: projectId ?? ''),
      ),
      builder: (context, effectiveInset, _, pickerChild) => Padding(
        padding: EdgeInsets.only(bottom: effectiveInset),
        child: pickerChild!,
      ),
    ),
  );
  if (result != null && context.mounted) {
    // 父任务不能跨项目：切换项目时清空 parentId。
    ref.read(taskFormProvider.notifier).setProjectAndParent(result, null);
  }
}

/// 「移动到」清单选择弹层：搜索框 + 收件箱 + 文件夹分组（可折叠） + 未分组清单 + 添加项目。
class ProjectPickerSheet extends ConsumerStatefulWidget {
  const ProjectPickerSheet({super.key, required this.currentProjectId});

  final String currentProjectId;

  @override
  ConsumerState<ProjectPickerSheet> createState() => _ProjectPickerSheetState();
}

class _ProjectPickerSheetState extends ConsumerState<ProjectPickerSheet> {
  final _searchController = TextEditingController();
  final Set<String> _collapsedFolders = <String>{};
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleFolderCollapse(String folderId) {
    setState(() {
      if (_collapsedFolders.contains(folderId)) {
        _collapsedFolders.remove(folderId);
      } else {
        _collapsedFolders.add(folderId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? AppTokens.borderSubtleDark
        : AppTokens.borderSubtleLight;

    final projectsAsync = ref.watch(projectsStreamProvider);
    final allProjects = projectsAsync.value ?? const <Project>[];

    final groupingAsync = ref.watch(projectsByFolderProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部导航：关闭与标题
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    l10n.moveTo,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: AppTokens.textTitleWeight,
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceMd),
              ],
            ),
            const SizedBox(height: AppTokens.spaceXs),
            // 搜索框
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceSm,
              ),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: l10n.searchProjects,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            const SizedBox(height: AppTokens.spaceXs),
            const Divider(height: 1),

            // 主列表区：搜索模式 vs 文件夹层级模式
            Flexible(
              child: _query.isNotEmpty
                  ? _buildSearchResults(
                      context: context,
                      l10n: l10n,
                      theme: theme,
                      allProjects: allProjects,
                      grouping: groupingAsync.value,
                    )
                  : _buildHierarchicalList(
                      context: context,
                      l10n: l10n,
                      theme: theme,
                      borderColor: borderColor,
                      grouping: groupingAsync.value,
                    ),
            ),

            const Divider(height: 1),
            // 底部操作：+ 添加项目
            ListTile(
              dense: true,
              leading: const Icon(Icons.add, size: 20),
              title: Text(l10n.addProject),
              onTap: _createProject,
            ),
            const SizedBox(height: AppTokens.spaceXs),
          ],
        ),
      ),
    );
  }

  Widget _buildHierarchicalList({
    required BuildContext context,
    required AppLocalizations l10n,
    required ThemeData theme,
    required Color borderColor,
    required ProjectGrouping? grouping,
  }) {
    final isInboxSelected = widget.currentProjectId == inboxProjectId;

    return ListView(
      shrinkWrap: true,
      children: [
        // 1. 系统收件箱
        ListTile(
          dense: true,
          leading: const Icon(
            Icons.inbox_outlined,
            size: 20,
            color: AppTokens.colorNavInbox,
          ),
          title: Text(
            l10n.inbox,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isInboxSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          trailing: isInboxSelected
              ? const Icon(
                  Icons.check,
                  size: 20,
                  color: AppTokens.colorInProgress,
                )
              : null,
          onTap: () => Navigator.of(context).pop(inboxProjectId),
        ),

        // 2. 文件夹与组内清单
        if (grouping != null) ...[
          for (final folder in grouping.folders) ...[
            () {
              final fProjects =
                  grouping.folderProjects[folder.id] ?? const <Project>[];
              final isCollapsed = _collapsedFolders.contains(folder.id);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 文件夹 Header
                  InkWell(
                    onTap: () => _toggleFolderCollapse(folder.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.spaceSm,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCollapsed
                                ? Icons.keyboard_arrow_right
                                : Icons.keyboard_arrow_down,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.folder_outlined,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              folder.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${fProjects.length}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 展开时的清单列表
                  if (!isCollapsed) ...[
                    if (fProjects.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 48,
                          top: 4,
                          bottom: 8,
                        ),
                        child: Text(
                          l10n.emptyProjects,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      )
                    else
                      Container(
                        margin: const EdgeInsets.only(
                          left: 24,
                          top: 1,
                          bottom: 4,
                        ),
                        padding: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: borderColor, width: 1),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final project in fProjects)
                              _buildProjectTile(
                                context: context,
                                project: project,
                                isSelected:
                                    project.id == widget.currentProjectId,
                              ),
                          ],
                        ),
                      ),
                  ],
                ],
              );
            }(),
          ],

          // 3. 未分组清单
          if (grouping.ungrouped.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: AppTokens.spaceSm,
                right: AppTokens.spaceSm,
                top: 12,
                bottom: 4,
              ),
              child: Text(
                l10n.ungrouped,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final project in grouping.ungrouped)
              _buildProjectTile(
                context: context,
                project: project,
                isSelected: project.id == widget.currentProjectId,
              ),
          ],
        ],
      ],
    );
  }

  Widget _buildSearchResults({
    required BuildContext context,
    required AppLocalizations l10n,
    required ThemeData theme,
    required List<Project> allProjects,
    required ProjectGrouping? grouping,
  }) {
    final queryLower = _query.toLowerCase();
    final foldersMap = {
      if (grouping != null)
        for (final f in grouping.folders) f.id: f,
    };

    // 搜索包含收件箱与所有清单
    final matched =
        <({String id, String name, int color, String? folderName})>[];

    if (l10n.inbox.toLowerCase().contains(queryLower)) {
      matched.add((
        id: inboxProjectId,
        name: l10n.inbox,
        color: AppTokens.colorNavInbox.toARGB32(),
        folderName: null,
      ));
    }

    for (final p in allProjects) {
      if (p.id == inboxProjectId) continue;
      final folder = p.folderId != null ? foldersMap[p.folderId] : null;
      final nameMatches = p.name.toLowerCase().contains(queryLower);
      final folderMatches =
          folder != null && folder.name.toLowerCase().contains(queryLower);
      if (nameMatches || folderMatches) {
        matched.add((
          id: p.id,
          name: p.name,
          color: p.color,
          folderName: folder?.name,
        ));
      }
    }

    if (matched.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceLg),
          child: Text(
            l10n.emptySearch,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: matched.length,
      itemBuilder: (context, index) {
        final item = matched[index];
        final isSelected = item.id == widget.currentProjectId;
        return ListTile(
          dense: true,
          leading: item.id == inboxProjectId
              ? const Icon(
                  Icons.inbox_outlined,
                  size: 20,
                  color: AppTokens.colorNavInbox,
                )
              : Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color(item.color),
                    shape: BoxShape.circle,
                  ),
                ),
          title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: item.folderName != null
              ? Text(
                  item.folderName!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                )
              : null,
          trailing: isSelected
              ? const Icon(
                  Icons.check,
                  size: 20,
                  color: AppTokens.colorInProgress,
                )
              : null,
          onTap: () => Navigator.of(context).pop(item.id),
        );
      },
    );
  }

  Widget _buildProjectTile({
    required BuildContext context,
    required Project project,
    required bool isSelected,
  }) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: Color(project.color),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: isSelected
          ? const Icon(Icons.check, size: 20, color: AppTokens.colorInProgress)
          : null,
      onTap: () => Navigator.of(context).pop(project.id),
    );
  }

  /// 「+ 添加项目」：使用新建清单/文件夹模态，创建后自动选中。
  Future<void> _createProject() async {
    final created = await showCreateListFolderSheet(
      context: context,
      initialType: CreateType.list,
    );
    if (created is Project && mounted) {
      Navigator.of(context).pop(created.id);
    }
  }
}
