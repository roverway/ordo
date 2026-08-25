import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/app_breakpoints.dart';
import '../../core/utils/derived.dart';
import '../../core/utils/tree.dart';
import '../../core/utils/view_rules.dart';
import '../../shared/widgets/app_drawer.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/simple_task_tile.dart';
import '../projects/project_providers.dart';
import '../tasks/task_edit_page.dart';
import 'tag_providers.dart';

/// 标签详情页（FR-VIEW-04 AC：任务列表支持按状态筛选）。
///
/// - AppBar 标题为标签名（来自 [tagsStreamProvider]，找不到显示空态）。
/// - 任务列表来自 `tasksForTag`，行用 [SimpleTaskTile]；
///   有子任务的任务勾选禁用、状态由子任务派生（AGENTS.md §3-2）。
/// - 页内状态下拉筛选（会话内状态），用 [applyTaskFilter] + 派生状态映射。
class TagsDetailPage extends ConsumerStatefulWidget {
  const TagsDetailPage({super.key, required this.tagId});

  final String tagId;

  @override
  ConsumerState<TagsDetailPage> createState() => _TagsDetailPageState();
}

class _TagsDetailPageState extends ConsumerState<TagsDetailPage> {
  /// 状态筛选（null = 全部，会话内状态，FR-VIEW-06）。
  TaskStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final narrow = AppBreakpoints.isNarrow(context);
    final tagsAsync = ref.watch(tagsStreamProvider);

    return tagsAsync.when(
      data: (tags) {
        final tag = tags.where((t) => t.id == widget.tagId).firstOrNull;
        if (tag == null) {
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
              title: Text(l10n.navTags),
              actions: [
                IconButton(
                  tooltip: l10n.search,
                  icon: const Icon(Icons.search, size: 22),
                  onPressed: () => context.push('/search'),
                ),
              ],
            ),
            body: EmptyState(
              icon: Icons.label_outline,
              message: l10n.emptyTags,
            ),
          );
        }
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
            title: Text(tag.name),
            actions: [
              IconButton(
                tooltip: l10n.search,
                icon: const Icon(Icons.search, size: 22),
                onPressed: () => context.push('/search'),
              ),
            ],
          ),
          body: ref
              .watch(allActiveTasksProvider)
              .when(
                loading: () => const LoadingView(),
                error: (e, st) {
                  logAsyncError(e, st);
                  return ErrorView(
                    onRetry: () => ref.invalidate(allActiveTasksProvider),
                  );
                },
                data: (allTasks) => ref
                    .watch(tagTasksProvider(widget.tagId))
                    .when(
                      data: (tasks) =>
                          _buildTaskList(context, l10n, tasks, allTasks),
                      loading: () => const LoadingView(),
                      error: (e, st) {
                        logAsyncError(e, st);
                        return ErrorView(
                          onRetry: () =>
                              ref.invalidate(tagTasksProvider(widget.tagId)),
                        );
                      },
                    ),
              ),
        );
      },
      loading: () => Scaffold(
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
          title: Text(l10n.navTags),
        ),
        body: const LoadingView(),
      ),
      error: (e, st) {
        logAsyncError(e, st);
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
            title: Text(l10n.navTags),
          ),
          body: ErrorView(onRetry: () => ref.invalidate(tagsStreamProvider)),
        );
      },
    );
  }

  Widget _buildTaskList(
    BuildContext context,
    AppLocalizations l10n,
    List<Task> tasks, // 该标签下任务（展示列表）。
    List<Task> allTasks, // 全量未删除任务（构建父子索引）。
  ) {
    // 用全量任务构建 children 索引：父任务即使其直接子任务未打该标签，
    // 也被正确识别为有子任务（审查发现 Bug：受限子集把带标签父任务当叶子，
    // 导致勾选被误启用并直接写 status，违反 AGENTS.md §3-2 派生状态约束）。
    final childrenIndex = indexChildrenByParent(allTasks);

    // 派生状态映射：有直接子任务的任务用 derivedStatus 计算
    // （参照 task_tree.dart 用法，AGENTS.md §3-2）。
    final effectiveStatuses = <String, TaskStatus>{
      for (final t in allTasks)
        if ((childrenIndex[t.id] ?? const <Task>[]).isNotEmpty)
          t.id: derivedStatus(t, childrenIndex[t.id]!),
    };

    final filtered = applyTaskFilter(
      tasks,
      effectiveStatuses,
      status: _filterStatus,
    );

    return Column(
      children: [
        _buildFilterBar(context, l10n),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(icon: Icons.label_outline, message: l10n.emptyTags)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceMd,
                    vertical: AppTokens.spaceSm,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final task = filtered[index];
                    final children = childrenIndex[task.id] ?? const <Task>[];
                    final effective = children.isEmpty
                        ? task.status
                        : derivedStatus(task, children);
                    return SimpleTaskTile(
                      task: task,
                      hasChildren: children.isNotEmpty,
                      isDone: effective == TaskStatus.done,
                      progressValue: taskProgress(task, allTasks),
                      onTap: () => openTaskEdit(context, taskId: task.id),
                      // 有子任务的任务状态由子任务派生，不给切换回调
                      //（SimpleTaskTile 在 hasChildren 时同样禁用勾选）。
                      onToggleDone: children.isEmpty
                          ? (value) => _toggleDone(task, value)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.spaceMd,
        AppTokens.spaceSm,
        AppTokens.spaceMd,
        0,
      ),
      child: Row(
        children: [
          Text(
            l10n.filterStatus,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppTokens.spaceSm),
          DropdownButton<TaskStatus?>(
            value: _filterStatus,
            isDense: true,
            items: [
              DropdownMenuItem<TaskStatus?>(
                value: null,
                child: Text(l10n.filterAll),
              ),
              for (final status in TaskStatus.values)
                DropdownMenuItem<TaskStatus?>(
                  value: status,
                  child: Text(_statusLabel(l10n, status)),
                ),
            ],
            onChanged: (value) => setState(() => _filterStatus = value),
          ),
        ],
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, TaskStatus status) =>
      switch (status) {
        TaskStatus.todo => l10n.statusTodo,
        TaskStatus.inProgress => l10n.statusInProgress,
        TaskStatus.done => l10n.statusDone,
        TaskStatus.cancelled => l10n.statusCancelled,
      };

  Future<void> _toggleDone(Task task, bool? value) async {
    final repo = ref.read(todoRepositoryProvider);
    final newStatus = value == true ? TaskStatus.done : TaskStatus.todo;
    try {
      await repo.updateTask(task.id, status: newStatus);
    } catch (_) {
      // 状态切换失败由数据流自动回滚，静默处理（与收件箱一致）。
    }
  }
}
