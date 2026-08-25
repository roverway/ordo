import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_breakpoints.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/staggered_fade_slide.dart';
import 'project_providers.dart';
import 'widgets/project_card.dart';
import 'widgets/project_form_dialog.dart';

/// 项目列表页（50-ui-ux.md §5.3；62-folder-nav.md §6.4 批 3 分组展示）。
///
/// 按文件夹分组展示：文件夹分组头（图标 + 名称）+ 项目卡片 + 未分组区
/// （D5：宽屏与抽屉分组一致，**不做拖拽**，仅展示分组）。
/// 新建项目入口 + 删除项目（级联确认框）。
class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final narrow = AppBreakpoints.isNarrow(context);
    final groupingAsync = ref.watch(projectsByFolderProvider);

    return Scaffold(
      drawer: narrow ? const AppDrawer() : null,
      appBar: AppBar(
        leading: narrow
            ? Builder(
                builder: (context) => IconButton(
                  tooltip: l10n.openDrawer,
                  icon: const Icon(Icons.menu, size: 22),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
        automaticallyImplyLeading: false,
        title: Text(l10n.navProjects),
        actions: [
          IconButton(
            tooltip: l10n.search,
            icon: const Icon(Icons.search, size: 22),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: groupingAsync.when(
        data: (grouping) {
          // 与抽屉项目区一致：内置收件箱由系统组 /inbox 承载，不列入项目列表
          //（Bug 3）。无文件夹且无项目时显示「暂无项目」空态。
          final folders = grouping.folders;
          final ungrouped = grouping.ungrouped;
          if (folders.isEmpty && ungrouped.isEmpty) {
            return EmptyState(
              icon: Icons.folder_outlined,
              message: l10n.emptyProjects,
              action: FilledButton.icon(
                onPressed: () => _showNewProjectDialog(context, ref),
                icon: const Icon(Icons.add),
                label: Text(l10n.newProject),
              ),
            );
          }
          // B 批：卡片逐项错落入场（仅首次 build；分组头不参与，作为锚点
          // 即时呈现）。
          var cardIndex = 0;
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceMd,
                  vertical: AppTokens.spaceSm,
                ),
                children: [
                  for (final folder in folders) ...[
                    _ProjectSectionHeader(
                      icon: Icons.folder_outlined,
                      title: folder.name,
                    ),
                    for (final project
                        in grouping.folderProjects[folder.id] ??
                            const <Project>[])
                      StaggeredFadeSlide(
                        index: cardIndex++,
                        child: ProjectCard(
                          project: project,
                          onTap: () => context.push('/projects/${project.id}'),
                        ),
                      ),
                  ],
                  // 未分组区（无文件夹时同样展示，保持分组结构一致）。
                  if (ungrouped.isNotEmpty) ...[
                    _ProjectSectionHeader(
                      icon: Icons.folder_off_outlined,
                      title: l10n.ungrouped,
                    ),
                    for (final project in ungrouped)
                      StaggeredFadeSlide(
                        index: cardIndex++,
                        child: ProjectCard(
                          project: project,
                          onTap: () => context.push('/projects/${project.id}'),
                        ),
                      ),
                  ],
                ],
              ),
              Positioned(
                right: AppTokens.spaceMd,
                bottom: AppTokens.spaceMd,
                child: FloatingActionButton(
                  onPressed: () => _showNewProjectDialog(context, ref),
                  tooltip: l10n.newProject,
                  child: const Icon(Icons.add),
                ),
              ),
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
    );
  }

  Future<void> _showNewProjectDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await showProjectFormDialog(context: context);
    if (result != null && context.mounted) {
      final repo = ref.read(todoRepositoryProvider);
      await repo.createProject(
        name: result.name,
        color: result.color,
        description: result.description,
      );
    }
  }
}

/// 项目分组小标题（62-folder-nav.md §6.4：图标 + 名称）。
class _ProjectSectionHeader extends StatelessWidget {
  const _ProjectSectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceXxs,
        AppTokens.spaceSm,
        AppTokens.spaceXxs,
        AppTokens.spaceXs,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppTokens.folderHeaderIconSize,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppTokens.spaceXs),
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: AppTokens.textTitleWeight,
            ),
          ),
        ],
      ),
    );
  }
}
