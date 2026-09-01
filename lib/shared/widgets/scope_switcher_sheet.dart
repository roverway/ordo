import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/sync/sync_engine.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/custom_views/providers/custom_view_providers.dart';
import '../../features/custom_views/widgets/icon_picker_dialog.dart';
import '../../features/projects/project_providers.dart';
import '../../features/projects/widgets/folder_name_dialog.dart';
import '../../features/projects/widgets/project_form_dialog.dart';
import '../../features/sync_setup/sync_setup_providers.dart';
import '../../features/tasks/task_providers.dart';
import '../../features/today/today_providers.dart';

/// 呼出清单/作用域切换底部弹层。
Future<void> showScopeSwitcherSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const ScopeSwitcherSheet(),
  );
}

/// 现代极简风格的清单/视图切换底部弹层（对齐原型设计中的切换弹层 `sheet`）。
class ScopeSwitcherSheet extends ConsumerStatefulWidget {
  const ScopeSwitcherSheet({super.key});

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
    final currentRoute = GoRouterState.of(context).uri.path;

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
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 头部标题
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '切换清单',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 主滚动内容区
            Flexible(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  // 1. 系统作用域
                  _buildSectionHeader('视图'),
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
                    title: '概览',
                    isSelected: currentRoute == '/projects',
                    onTap: () {
                      final router = GoRouter.of(context);
                      Navigator.of(context).maybePop();
                      router.go('/projects');
                    },
                  ),

                  const SizedBox(height: 12),

                  // 2. 自定义视图
                  customViewsAsync.maybeWhen(
                    data: (views) {
                      if (views.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionHeader(l10n.customViews),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.of(context).maybePop();
                                  context.push('/custom_view/new');
                                },
                                icon: const Icon(Icons.add, size: 14),
                                label: Text(
                                  l10n.newCustomView,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
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
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),

                  // 3. 项目与文件夹分组
                  _buildSectionHeader('项目'),
                  groupingAsync.maybeWhen(
                    data: (grouping) {
                      final folders = grouping.folders;
                      final ungrouped = grouping.ungrouped;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final folder in folders) ...[
                            _buildFolderHeader(
                              folder: folder,
                              isCollapsed: _collapsedFolders.contains(
                                folder.id,
                              ),
                              onToggleCollapse: () {
                                setState(() {
                                  if (_collapsedFolders.contains(folder.id)) {
                                    _collapsedFolders.remove(folder.id);
                                  } else {
                                    _collapsedFolders.add(folder.id);
                                  }
                                });
                              },
                            ),
                            if (!_collapsedFolders.contains(folder.id))
                              for (final p
                                  in grouping.folderProjects[folder.id] ??
                                      const <Project>[])
                                _buildProjectTile(
                                  project: p,
                                  isIndented: true,
                                  isSelected:
                                      currentRoute == '/projects/${p.id}',
                                  onTap: () {
                                    final router = GoRouter.of(context);
                                    Navigator.of(context).maybePop();
                                    router.go('/projects/${p.id}');
                                  },
                                ),
                          ],
                          if (ungrouped.isNotEmpty) ...[
                            if (folders.isNotEmpty)
                              _buildSubHeader(l10n.ungrouped),
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
                    label: l10n.newProject,
                    onTap: () async {
                      Navigator.of(context).maybePop();
                      final result = await showProjectFormDialog(
                        context: context,
                      );
                      if (result != null && context.mounted) {
                        await ref
                            .read(todoRepositoryProvider)
                            .createProject(
                              name: result.name,
                              color: result.color,
                              description: result.description,
                            );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildBottomActionButton(
                    icon: Icons.create_new_folder_outlined,
                    label: '新文件夹',
                    onTap: () async {
                      Navigator.of(context).maybePop();
                      final name = await showFolderNameDialog(context: context);
                      if (name != null &&
                          name.trim().isNotEmpty &&
                          context.mounted) {
                        await ref
                            .read(todoRepositoryProvider)
                            .createFolder(name: name.trim());
                      }
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
                      Navigator.of(context).maybePop();
                      context.push('/settings');
                    },
                  ),
                  IconButton(
                    tooltip: 'WebDAV 同步',
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
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildSubHeader(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: Icon(icon, color: iconColor, size: 20),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
          ),
        ),
        trailing: badgeCount != null && badgeCount > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: (badgeColor ?? colorScheme.primary).withValues(
                    alpha: 0.15,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    fontFeatures: AppTokens.fontTabular,
                    color: badgeColor ?? colorScheme.primary,
                  ),
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildFolderHeader({
    required Folder folder,
    required bool isCollapsed,
    required VoidCallback onToggleCollapse,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onToggleCollapse,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Icon(
              isCollapsed ? Icons.chevron_right : Icons.expand_more,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.folder_outlined,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              folder.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
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

    final summary = ref.watch(projectSummaryProvider(project.id));
    final uncompleted = summary.uncompletedCount;

    return Container(
      margin: EdgeInsets.only(left: isIndented ? 20 : 0, top: 1, bottom: 1),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            color: projectColor,
            shape: BoxShape.circle,
          ),
        ),
        title: Text(
          project.name,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
          ),
        ),
        trailing: uncompleted > 0
            ? Text(
                '$uncompleted',
                style: TextStyle(
                  fontSize: 12,
                  fontFeatures: AppTokens.fontTabular,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        onTap: onTap,
      ),
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
