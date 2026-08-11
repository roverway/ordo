import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/derived.dart';
import '../../core/utils/tree.dart';
import '../../core/utils/view_rules.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/simple_task_tile.dart';
import '../projects/project_providers.dart';
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
    final tagsAsync = ref.watch(tagsStreamProvider);

    return tagsAsync.when(
      data: (tags) {
        final tag = tags.where((t) => t.id == widget.tagId).firstOrNull;
        if (tag == null) {
          return AppShell(
            title: l10n.navTags,
            child: EmptyState(
              icon: Icons.label_outline,
              message: l10n.emptyTags,
            ),
          );
        }
        return AppShell(
          title: tag.name,
          child: ref
              .watch(tagTasksProvider(widget.tagId))
              .when(
                data: (tasks) => _buildTaskList(context, l10n, tasks),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
              ),
        );
      },
      loading: () => AppShell(
        title: l10n.navTags,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppShell(
        title: l10n.navTags,
        child: Center(child: Text(e.toString())),
      ),
    );
  }

  Widget _buildTaskList(
    BuildContext context,
    AppLocalizations l10n,
    List<Task> tasks,
  ) {
    final childrenIndex = indexChildrenByParent(tasks);

    // 派生状态映射：有直接子任务的任务用 derivedStatus 计算
    // （参照 task_tree.dart 用法，AGENTS.md §3-2）。
    final effectiveStatuses = <String, TaskStatus>{
      for (final t in tasks)
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
                      onTap: () => context.push('/task/${task.id}'),
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
