import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/preset_icons.dart';
import '../../features/custom_views/providers/custom_view_providers.dart';
import '../../features/custom_views/widgets/icon_picker_dialog.dart';
import '../../features/projects/project_providers.dart';
import '../../features/projects/widgets/create_list_folder_sheet.dart';
import '../../features/sync_setup/sync_setup_providers.dart';
import '../../features/tasks/task_providers.dart';
import '../../features/today/today_providers.dart';
import 'confirm_dialog.dart';

/// 呼出清单/作用域切换底部弹层。
Future<void> showScopeSwitcherSheet(
  BuildContext context, {
  String? currentRoute,
}) {
  final route = currentRoute ?? _resolveCurrentRoute(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ScopeSwitcherSheet(currentRoute: route),
  );
}

String _resolveCurrentRoute(BuildContext context) {
  try {
    return GoRouter.maybeOf(
          context,
        )?.routerDelegate.currentConfiguration.uri.path ??
        '';
  } catch (_) {
    return '';
  }
}

/// 现代极简风格的清单/视图切换底部弹层（对齐原型设计中的切换弹层 `sheet`）。
class ScopeSwitcherSheet extends ConsumerStatefulWidget {
  const ScopeSwitcherSheet({super.key, this.currentRoute});

  final String? currentRoute;

  @override
  ConsumerState<ScopeSwitcherSheet> createState() => _ScopeSwitcherSheetState();
}

class _ScopeSwitcherSheetState extends ConsumerState<ScopeSwitcherSheet> {
  final Set<String> _collapsedFolders = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final currentRoute = widget.currentRoute ?? _resolveCurrentRoute(context);

    final todayViewAsync = ref.watch(todayViewProvider);
    final inboxProjectAsync = ref.watch(inboxProjectProvider);
    final groupingAsync = ref.watch(projectsByFolderProvider);
    final customViewsAsync = ref.watch(customViewsStreamProvider);
    final syncState = ref.watch(syncStateProvider);

    // 今日待办数
    final todayUncompleted = todayViewAsync.maybeWhen(
      data: (view) => (view.overdue + view.today)
          .where((v) => v.effectiveStatus != TaskStatus.done)
          .length,
      orElse: () => 0,
    );

    // 收集箱待办数
    final inboxProjectIdVal = inboxProjectAsync.value?.id ?? inboxProjectId;
    final inboxSummary = ref.watch(projectSummaryProvider(inboxProjectIdVal));
    final inboxUncompleted = inboxSummary.uncompletedCount;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
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
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // 主滚动内容区
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 12),
                children: [
                  // 1. 系统作用域
                  _buildSectionHeader(l10n.viewsSection),
                  _buildScopeTile(
                    icon: Icons.wb_sunny_outlined,
                    iconColor: AppTokens.colorNavToday,
                    title: l10n.navToday,
                    badgeCount: todayUncompleted > 0 ? todayUncompleted : null,
                    badgeColor: todayUncompleted > 0
                        ? AppTokens.colorNavToday
                        : null,
                    isSelected: currentRoute == '/today' || currentRoute == '/',
                    onTap: () {
                      final router = GoRouter.of(context);
                      Navigator.of(context).maybePop();
                      router.go('/today');
                    },
                  ),
                  _buildScopeTile(
                    icon: Icons.inbox_outlined,
                    iconColor: AppTokens.colorNavInbox,
                    title: l10n.inbox,
                    badgeCount: inboxUncompleted > 0 ? inboxUncompleted : null,
                    badgeColor: inboxUncompleted > 0
                        ? AppTokens.colorNavInbox
                        : null,
                    isSelected: currentRoute == '/inbox',
                    onTap: () {
                      final router = GoRouter.of(context);
                      Navigator.of(context).maybePop();
                      router.go('/inbox');
                    },
                  ),
                  _buildScopeTile(
                    icon: Icons.calendar_month_outlined,
                    iconColor: AppTokens.colorNavCalendar,
                    title: l10n.navCalendar,
                    isSelected: currentRoute == '/calendar',
                    onTap: () {
                      final router = GoRouter.of(context);
                      Navigator.of(context).maybePop();
                      router.go('/calendar');
                    },
                  ),
                  _buildScopeTile(
                    icon: Icons.pie_chart_outline_rounded,
                    iconColor: AppTokens.colorNavOverview,
                    title: l10n.overview,
                    isSelected: currentRoute == '/projects',
                    onTap: () {
                      final router = GoRouter.of(context);
                      Navigator.of(context).maybePop();
                      router.go('/projects');
                    },
                  ),

                  const SizedBox(height: 12),

                  // 2. 自定义视图
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeaderWithAdd(
                        title: l10n.customViews,
                        tooltip: l10n.newCustomView,
                        onAdd: () {
                          final router = GoRouter.of(context);
                          Navigator.of(context).maybePop();
                          router.push('/custom_view/new');
                        },
                      ),
                      customViewsAsync.maybeWhen(
                        data: (views) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final cv in views)
                              _buildScopeTile(
                                icon: getCustomViewIcon(cv.icon),
                                iconColor: Color(cv.color),
                                title: cv.name,
                                isSelected:
                                    currentRoute == '/custom_view/${cv.id}',
                                onTap: () {
                                  final router = GoRouter.of(context);
                                  Navigator.of(context).maybePop();
                                  router.go('/custom_view/${cv.id}');
                                },
                              ),
                          ],
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),

                  // 3. 项目与文件夹分组（清单）
                  _buildSectionHeaderWithAdd(
                    title: l10n.listsSection,
                    tooltip: l10n.newFolder,
                    onAdd: () async {
                      await showCreateListFolderSheet(
                        context: context,
                        initialType: CreateType.folder,
                      );
                    },
                  ),
                  groupingAsync.maybeWhen(
                    data: (grouping) {
                      final folders = grouping.folders;
                      final ungrouped = grouping.ungrouped;
                      final isDark = theme.brightness == Brightness.dark;
                      final borderColor = isDark
                          ? AppTokens.borderSubtleDark
                          : AppTokens.borderSubtleLight;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final folder in folders) ...[
                            () {
                              final fProjects =
                                  grouping.folderProjects[folder.id] ??
                                  const <Project>[];
                              final fUncompleted = ref.watch(
                                folderUncompletedCountProvider(folder.id),
                              );
                              return _buildFolderHeader(
                                folder: folder,
                                uncompletedCount: fUncompleted,
                                isCollapsed: _collapsedFolders.contains(
                                  folder.id,
                                ),
                                projectCount: fProjects.length,
                                onToggleCollapse: () {
                                  setState(() {
                                    if (_collapsedFolders.contains(folder.id)) {
                                      _collapsedFolders.remove(folder.id);
                                    } else {
                                      _collapsedFolders.add(folder.id);
                                    }
                                  });
                                },
                              );
                            }(),
                            if (!_collapsedFolders.contains(folder.id))
                              Container(
                                margin: const EdgeInsets.only(
                                  left: 20,
                                  top: 1,
                                  bottom: 4,
                                ),
                                padding: const EdgeInsets.only(left: 6),
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: borderColor,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final p
                                        in grouping.folderProjects[folder.id] ??
                                            const <Project>[])
                                      _buildProjectTile(
                                        project: p,
                                        isIndented: false,
                                        isSelected:
                                            currentRoute == '/projects/${p.id}',
                                        onTap: () {
                                          final router = GoRouter.of(context);
                                          Navigator.of(context).maybePop();
                                          router.go('/projects/${p.id}');
                                        },
                                      ),
                                  ],
                                ),
                              ),
                          ],
                          if (ungrouped.isNotEmpty) ...[
                            if (folders.isNotEmpty)
                              DragTarget<Project>(
                                onWillAcceptWithDetails: (details) =>
                                    details.data.folderId != null,
                                onAcceptWithDetails: (details) async {
                                  await ref
                                      .read(todoRepositoryProvider)
                                      .moveProjectToFolder(
                                        details.data.id,
                                        folderId: null,
                                        newIndex: ungrouped.length,
                                      );
                                },
                                builder:
                                    (context, candidateData, rejectedData) {
                                      final isHovered =
                                          candidateData.isNotEmpty;
                                      return Container(
                                        decoration: isHovered
                                            ? BoxDecoration(
                                                color: colorScheme.primary
                                                    .withValues(alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              )
                                            : null,
                                        child: _buildSubHeader(l10n.ungrouped),
                                      );
                                    },
                              ),
                            for (final p in ungrouped)
                              _buildProjectTile(
                                project: p,
                                isIndented: false,
                                isSelected: currentRoute == '/projects/${p.id}',
                                onTap: () {
                                  final router = GoRouter.of(context);
                                  Navigator.of(context).maybePop();
                                  router.go('/projects/${p.id}');
                                },
                              ),
                          ],
                        ],
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 底部操作区 (新建项目 / 文件夹 / 设置 / 同步)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildBottomActionButton(
                    icon: Icons.add,
                    label: l10n.create,
                    onTap: () async {
                      await showCreateListFolderSheet(
                        context: context,
                        initialType: CreateType.list,
                      );
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: l10n.settings,
                    icon: Icon(
                      Icons.settings_outlined,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      final router = GoRouter.of(context);
                      Navigator.of(context).maybePop();
                      router.push('/settings');
                    },
                  ),
                  IconButton(
                    tooltip: l10n.webdavSync,
                    icon: Icon(
                      syncState.status == SyncStateStatus.syncing
                          ? Icons.sync
                          : (syncState.status == SyncStateStatus.error
                                ? Icons.sync_problem
                                : Icons.cloud_done_outlined),
                      size: 20,
                      color: syncState.status == SyncStateStatus.error
                          ? colorScheme.error
                          : (syncState.status == SyncStateStatus.syncing
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant),
                    ),
                    onPressed: () {
                      ref.read(syncEngineProvider).run();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
        ),
      ),
    );
  }

  Widget _buildSectionHeaderWithAdd({
    required String title,
    required String tooltip,
    required VoidCallback onAdd,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
            ),
          ),
          SizedBox.square(
            dimension: 24,
            child: IconButton(
              padding: EdgeInsets.zero,
              tooltip: tooltip,
              icon: Icon(
                Icons.add,
                size: 15,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: onAdd,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubHeader(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 10, 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildScopeTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    int? badgeCount,
    Color? badgeColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 15),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badgeCount != null && badgeCount > 0)
                  Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontSize: 12,
                      fontFeatures: AppTokens.fontTabular,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.check,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editFolder(Folder folder) async {
    await showEditFolderSheet(context, folder);
  }

  Future<void> _deleteFolder(Folder folder) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.deleteFolder,
      message:
          '${l10n.deleteFolderConfirm(folder.name)}\n${l10n.deleteFolderWarning}',
      confirmLabel: l10n.delete,
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (confirmed && mounted) {
      await ref.read(todoRepositoryProvider).deleteFolder(folder.id);
    }
  }

  Future<void> _editProject(Project project) async {
    await showEditListSheet(context, project);
  }

  Future<void> _deleteProject(Project project) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.deleteProject,
      message: l10n.deleteProjectConfirm(project.name),
      confirmLabel: l10n.delete,
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (confirmed && mounted) {
      await ref.read(todoRepositoryProvider).deleteProject(project.id);
    }
  }

  Widget _buildFolderHeader({
    required Folder folder,
    required int uncompletedCount,
    required bool isCollapsed,
    required int projectCount,
    required VoidCallback onToggleCollapse,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    final folderColor = folder.color != null
        ? Color(folder.color!)
        : colorScheme.primary;
    final folderIcon = getIconDataById(
      folder.icon,
      fallback: Icons.folder_outlined,
    );

    final headerTile = DragTarget<Project>(
      onWillAcceptWithDetails: (details) => details.data.folderId != folder.id,
      onAcceptWithDetails: (details) async {
        await ref
            .read(todoRepositoryProvider)
            .moveProjectToFolder(
              details.data.id,
              folderId: folder.id,
              newIndex: projectCount,
            );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            color: isHovered
                ? folderColor.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onToggleCollapse,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: folderColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(folderIcon, color: folderColor, size: 15),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        folder.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (uncompletedCount > 0)
                      Text(
                        '$uncompletedCount',
                        style: TextStyle(
                          fontSize: 12,
                          fontFeatures: AppTokens.fontTabular,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: isCollapsed ? -0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    return _SlidableActionTile(
      onEdit: () => _editFolder(folder),
      onDelete: () => _deleteFolder(folder),
      child: headerTile,
    );
  }

  Widget _buildProjectTile({
    required Project project,
    required bool isIndented,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final projectColor = Color(project.color);
    final projectIcon = getIconDataById(
      project.icon,
      fallback: Icons.format_list_bulleted_rounded,
    );

    final summary = ref.watch(projectSummaryProvider(project.id));
    final uncompleted = summary.uncompletedCount;

    final tileContent = Padding(
      padding: EdgeInsets.only(left: isIndented ? 16 : 0, top: 1, bottom: 1),
      child: Material(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: projectColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(projectIcon, color: projectColor, size: 13),
                ),
                Expanded(
                  child: Text(
                    project.name,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (uncompleted > 0)
                  Text(
                    '$uncompleted',
                    style: TextStyle(
                      fontSize: 12,
                      fontFeatures: AppTokens.fontTabular,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.check,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final isMobile =
        theme.platform == TargetPlatform.android ||
        theme.platform == TargetPlatform.iOS;

    final feedback = Material(
      color: Colors.transparent,
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 240,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: projectColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                project.name,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    final draggableTile = isMobile
        ? LongPressDraggable<Project>(
            data: project,
            feedback: feedback,
            childWhenDragging: Opacity(opacity: 0.35, child: tileContent),
            child: tileContent,
          )
        : Draggable<Project>(
            data: project,
            feedback: feedback,
            childWhenDragging: Opacity(opacity: 0.35, child: tileContent),
            child: tileContent,
          );

    return _SlidableActionTile(
      onEdit: () => _editProject(project),
      onDelete: () => _deleteProject(project),
      child: draggableTile,
    );
  }

  Widget _buildBottomActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 支持左滑显露“编辑”与“删除”两个操作按钮的滑动包装组件。
class _SlidableActionTile extends StatefulWidget {
  const _SlidableActionTile({
    required this.child,
    required this.onEdit,
    required this.onDelete,
  });

  final Widget child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_SlidableActionTile> createState() => _SlidableActionTileState();
}

class _SlidableActionTileState extends State<_SlidableActionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragExtent = 0;
  static const double _actionWidth = 96;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent += details.primaryDelta!;
      if (_dragExtent > 0) _dragExtent = 0;
      if (_dragExtent < -_actionWidth) _dragExtent = -_actionWidth;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragExtent < -_actionWidth / 2) {
      _animateTo(-_actionWidth);
    } else {
      _animateTo(0);
    }
  }

  void _animateTo(double target) {
    _animation =
        Tween<double>(begin: _dragExtent, end: target).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        )..addListener(() {
          setState(() {
            _dragExtent = _animation.value;
          });
        });
    _controller.reset();
    _controller.forward();
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final rect = RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 0, 0),
      Offset.zero & (overlay?.size ?? MediaQuery.of(context).size),
    );

    showMenu<String>(
      context: context,
      position: rect,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<String>(
          value: 'edit',
          height: 38,
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 17, color: colorScheme.onSurface),
              const SizedBox(width: 10),
              Text(
                l10n.edit,
                style: TextStyle(fontSize: 13.5, color: colorScheme.onSurface),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          height: 38,
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 17, color: colorScheme.error),
              const SizedBox(width: 10),
              Text(
                l10n.delete,
                style: TextStyle(
                  fontSize: 13.5,
                  color: colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit') {
        widget.onEdit();
      } else if (value == 'delete') {
        widget.onDelete();
      }
    });
  }

  void _close() {
    _animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop =
        theme.platform == TargetPlatform.windows ||
        theme.platform == TargetPlatform.linux ||
        theme.platform == TargetPlatform.macOS;

    if (isDesktop) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) =>
            _showContextMenu(context, details.globalPosition),
        child: widget.child,
      );
    }

    return ClipRect(
      child: Stack(
        children: [
          // 前景滑动内容
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: Transform.translate(
              offset: Offset(_dragExtent, 0),
              child: Container(color: colorScheme.surface, child: widget.child),
            ),
          ),

          // 右侧露出的操作按钮（仅在左滑时置于顶层，确保可直接点击交互）
          if (_dragExtent < 0)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: _actionWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () {
                        _close();
                        widget.onEdit();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 42,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.edit_outlined,
                          size: 17,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        _close();
                        widget.onDelete();
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 42,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colorScheme.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.delete_outline,
                          size: 17,
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
