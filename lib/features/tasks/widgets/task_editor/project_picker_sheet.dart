import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/todo_repository.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/platform/keyboard_inset_bridge.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../projects/project_providers.dart';
import '../../../projects/widgets/project_form_dialog.dart';
import '../../task_providers.dart';

/// 顶部栏项目切换：[项目图标] 项目名 [下拉双箭头]（编辑中直接切换所属项目）。
class TaskProjectSwitcher extends ConsumerWidget {
  const TaskProjectSwitcher({super.key, this.interactive = true});

  /// 编辑已有任务时传 false：仅展示项目名（跨项目移动未实现，编辑态隐藏
  /// 误导性切换入口；新建态保留切换，59 讨论定稿）。
  final bool interactive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final projectId = ref.watch(taskFormProvider.select((s) => s.projectId));
    final projects =
        ref.watch(projectsStreamProvider).value ?? const <Project>[];
    final project = projects.where((p) => p.id == projectId).firstOrNull;

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
                : AppTokens.colorCancelled,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppTokens.spaceXs),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            project?.name ?? '',
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
      onTap: () => _pickProject(context, ref),
      child: Padding(padding: padding, child: content),
    );
  }

  /// 「移动到」清单选择：搜索 + 列表（当前项对勾）+ 添加项目。
  Future<void> _pickProject(BuildContext context, WidgetRef ref) async {
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
      // 父任务不能跨项目：切换项目时清空 parentId（新建态切换；编辑态无此入口）。
      ref.read(taskFormProvider.notifier).setProjectAndParent(result, null);
    }
  }
}

/// 「移动到」清单选择弹层：搜索框 + 清单列表（当前项对勾）+ 添加项目。
class ProjectPickerSheet extends ConsumerStatefulWidget {
  const ProjectPickerSheet({super.key, required this.currentProjectId});

  final String currentProjectId;

  @override
  ConsumerState<ProjectPickerSheet> createState() => _ProjectPickerSheetState();
}

class _ProjectPickerSheetState extends ConsumerState<ProjectPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final projects =
        ref.watch(projectsStreamProvider).value ?? const <Project>[];
    final filtered = projects
        .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Row(
              children: [
                const SizedBox(width: AppTokens.spaceSm),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: l10n.searchProjects,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: AppTokens.spaceSm),
              ],
            ),
            const SizedBox(height: AppTokens.spaceXs),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final project = filtered[index];
                  final isCurrent = project.id == widget.currentProjectId;
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
                    title: Text(
                      project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isCurrent
                        ? const Icon(
                            Icons.check,
                            size: 20,
                            color: AppTokens.colorInProgress,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(project.id),
                  );
                },
              ),
            ),
            const Divider(),
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

  /// 「+ 添加项目」：复用项目表单弹窗，创建后自动选中。
  Future<void> _createProject() async {
    final data = await showProjectFormDialog(context: context);
    if (data == null || !mounted) return;
    final repo = ref.read(todoRepositoryProvider);
    try {
      final project = await repo.createProject(
        name: data.name,
        color: data.color,
        description: data.description,
      );
      if (!mounted) return;
      Navigator.of(context).pop(project.id);
    } on RepositoryException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
