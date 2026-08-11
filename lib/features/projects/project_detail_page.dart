import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/l10n/app_localizations.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../projects/project_providers.dart';
import '../tasks/widgets/task_tree.dart';
import 'widgets/project_form_dialog.dart';

/// 项目详情页（50-ui-ux.md §5.3）。
///
/// 任务树（最多 3 级）+ 新建任务按钮 + 编辑/删除项目。
class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final projectsAsync = ref.watch(projectsStreamProvider);

    return projectsAsync.when(
      data: (projects) {
        final project = projects.where((p) => p.id == projectId).firstOrNull;
        if (project == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.navProjects)),
            body: Center(child: Text(l10n.emptyProjects)),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(project.name),
            actions: [
              IconButton(
                tooltip: l10n.editProject,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editProject(context, ref, project),
              ),
              IconButton(
                tooltip: l10n.deleteProject,
                icon: const Icon(Icons.delete_outlined),
                onPressed: () => _deleteProject(context, ref, project),
              ),
            ],
          ),
          body: TaskTree(projectId: projectId),
          floatingActionButton: FloatingActionButton(
            tooltip: l10n.newTask,
            onPressed: () => context.push('/task/new?projectId=$projectId'),
            child: const Icon(Icons.add),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
    );
  }

  Future<void> _editProject(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final result = await showProjectFormDialog(
      context: context,
      initialName: project.name,
      initialColor: project.color,
    );
    if (result != null && context.mounted) {
      final repo = ref.read(todoRepositoryProvider);
      await repo.updateProject(
        project.id,
        name: result.name,
        color: result.color,
      );
    }
  }

  Future<void> _deleteProject(
    BuildContext context,
    WidgetRef ref,
    Project project,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmDialog(
      context: context,
      title: l10n.deleteProject,
      message: l10n.deleteProjectConfirm(project.name),
      confirmLabel: l10n.delete,
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (confirmed && context.mounted) {
      final repo = ref.read(todoRepositoryProvider);
      await repo.deleteProject(project.id);
      if (context.mounted) {
        context.go('/projects');
      }
    }
  }
}
