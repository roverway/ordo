import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_breakpoints.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/hero_progress_ring.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/page_hero_header.dart';
import '../../shared/widgets/scope_switcher_sheet.dart';
import '../../shared/widgets/staggered_fade_slide.dart';
import '../tasks/task_providers.dart';
import 'project_providers.dart';
import 'widgets/create_list_folder_sheet.dart';
import 'widgets/project_card.dart';

/// 项目概览页（对齐原型 overview.html：概览 Hero + 周进度条 + 文件夹分组项目卡片）。
class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final narrow = AppBreakpoints.isNarrow(context);

    final groupingAsync = ref.watch(projectsByFolderProvider);
    final projectsAsync = ref.watch(projectsStreamProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: groupingAsync.when(
          data: (grouping) {
            final folders = grouping.folders;
            final ungrouped = grouping.ungrouped;
            final allProjects =
                projectsAsync.value
                    ?.where((p) => p.id != inboxProjectId)
                    .toList() ??
                [];

            if (folders.isEmpty && ungrouped.isEmpty) {
              return EmptyState(
                icon: Icons.folder_outlined,
                accentColor: colorScheme.primary,
                message: l10n.emptyProjects,
                action: FilledButton.icon(
                  onPressed: () => _showNewProjectDialog(context, ref),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.newProject),
                ),
              );
            }

            // 统计待办与完成情况（通过聚合 Provider 统一订阅，避免 build 循环内 watch）
            final overview = ref.watch(allProjectsOverviewSummaryProvider);
            final totalTasks = overview.total;
            final totalCompleted = overview.completed;
            final totalPendingTasks = overview.uncompleted;
            final totalProjectsCount = allProjects.length;

            var cardIndex = 0;

            return CustomScrollView(
              slivers: [
                // Hero 顶栏
                SliverToBoxAdapter(
                  child: PageHeroHeader(
                    title: '概览',
                    onTitleTap: narrow
                        ? () => showScopeSwitcherSheet(context)
                        : null,
                    subtitle:
                        '共 $totalProjectsCount 个项目 · $totalPendingTasks 项待办',
                    trailing: HeroProgressRing(
                      completed: totalCompleted,
                      total: totalTasks > 0 ? totalTasks : 1,
                      customCenterText: totalTasks > 0
                          ? '$totalCompleted/$totalTasks'
                          : '0/0',
                    ),
                  ),
                ),

                // 周完成条 (Week progress bar)
                if (totalTasks > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '本周进度',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                '$totalCompleted/$totalTasks 项 (${(totalCompleted / totalTasks * 100).round()}%)',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontFeatures: AppTokens.fontTabular,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: totalCompleted / totalTasks,
                              minHeight: 6,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                totalCompleted == totalTasks
                                    ? AppTokens.colorDone
                                    : colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 分组项目列表
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      for (final folder in folders) ...[
                        _FolderSectionHeader(
                          title: folder.name,
                          count:
                              grouping.folderProjects[folder.id]?.length ?? 0,
                        ),
                        for (final project
                            in grouping.folderProjects[folder.id] ??
                                const <Project>[])
                          StaggeredFadeSlide(
                            index: cardIndex++,
                            child: ProjectCard(
                              project: project,
                              onTap: () =>
                                  context.push('/projects/${project.id}'),
                            ),
                          ),
                      ],
                      if (ungrouped.isNotEmpty) ...[
                        _FolderSectionHeader(
                          title: '未分组',
                          count: ungrouped.length,
                        ),
                        for (final project in ungrouped)
                          StaggeredFadeSlide(
                            index: cardIndex++,
                            child: ProjectCard(
                              project: project,
                              onTap: () =>
                                  context.push('/projects/${project.id}'),
                            ),
                          ),
                      ],
                    ]),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
          loading: () => const LoadingView(),
          error: (e, st) {
            logAsyncError(e, st);
            return ErrorView(
              onRetry: () => ref.invalidate(projectsByFolderProvider),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewProjectDialog(context, ref),
        tooltip: l10n.newProject,
        backgroundColor: isDark ? Colors.white : Colors.black,
        foregroundColor: isDark ? Colors.black : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          l10n.newProject,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
        ),
      ),
    );
  }

  Future<void> _showNewProjectDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showCreateListFolderSheet(
      context: context,
      initialType: CreateType.list,
    );
  }
}

/// 概览页文件夹分组头
class _FolderSectionHeader extends StatelessWidget {
  const _FolderSectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontFamily: 'monospace',
              fontFeatures: AppTokens.fontTabular,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
