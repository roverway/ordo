import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import 'project_providers.dart';
import 'widgets/project_card.dart';
import 'widgets/project_form_dialog.dart';

/// 项目列表页（50-ui-ux.md §5.3）。
///
/// 卡片式列表：颜色圆点 + 名称 + 未完成任务数 + 进度条。
/// 新建项目入口 + 删除项目（级联确认框）。
class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final projectsAsync = ref.watch(projectsStreamProvider);

    return AppShell(
      title: l10n.navProjects,
      child: projectsAsync.when(
        data: (projects) {
          if (projects.isEmpty) {
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
          return Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceMd,
                  vertical: AppTokens.spaceSm,
                ),
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final project = projects[index];
                  return ProjectCard(
                    project: project,
                    onTap: () => context.push('/projects/${project.id}'),
                  );
                },
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
            onRetry: () => ref.invalidate(projectsStreamProvider),
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
