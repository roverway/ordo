// 搜索页（FR-VIEW-05 / FR-VIEW-06，M3）。
//
// - 输入即搜：防抖 300ms（searchQueryProvider），按标题/描述/备注匹配；
// - 结果按最近更新排序（DAO watchAllActive 已按 updatedAt 降序）；
// - 筛选条：状态/标签/时间段多条件叠加（会话内持久，searchFilterProvider）；
// - 空查询 → 提示；有查询无结果 → 空态（emptySearch）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/derived.dart';
import '../../core/utils/tree.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/loading_view.dart';
import '../../shared/widgets/simple_task_tile.dart';
import '../../shared/widgets/task_filter_bar.dart';
import '../projects/project_providers.dart';
import '../tags/tag_providers.dart';
import '../tasks/task_edit_page.dart';
import 'search_providers.dart';

/// Search page — M3: debounced full-text search + filters.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  /// 输入框控制器：进入页面时同步会话内 query，多次进出不丢已输入内容。
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(
      text: ref.read(searchQueryProvider),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resultsAsync = ref.watch(searchResultsProvider);
    final allAsync = ref.watch(allActiveTasksProvider);
    final filter = ref.watch(searchFilterProvider);
    final tagsAsync = ref.watch(tagsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.search)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.spaceMd,
              AppTokens.spaceMd,
              AppTokens.spaceMd,
              AppTokens.spaceXs,
            ),
            child: TextField(
              controller: _queryController,
              onChanged: (value) =>
                  ref.read(searchQueryProvider.notifier).onQueryChanged(value),
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          TaskFilterBar(
            status: filter.status,
            tagId: filter.tagId,
            range: filter.range,
            tags: tagsAsync.value ?? const [],
            onStatusChanged: (status) =>
                ref.read(searchFilterProvider.notifier).setStatus(status),
            onTagChanged: (tagId) =>
                ref.read(searchFilterProvider.notifier).setTagId(tagId),
            onTimeRangeChanged: (range) =>
                ref.read(searchFilterProvider.notifier).setTimeRange(range),
            onClear: () => ref.read(searchFilterProvider.notifier).clear(),
          ),
          Expanded(
            child: resultsAsync.when(
              data: (results) => _buildResults(
                context,
                l10n,
                results,
                allAsync.value ?? const <Task>[],
              ),
              loading: () => const LoadingView(),
              error: (e, st) {
                logAsyncError(e, st);
                return ErrorView(
                  onRetry: () => ref.invalidate(searchResultsProvider),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    AppLocalizations l10n,
    List<Task> results,
    List<Task> allTasks,
  ) {
    final query = ref.watch(searchQueryProvider);

    // 空查询：提示搜索（FR-VIEW-05）。
    if (query.trim().isEmpty) {
      return EmptyState(icon: Icons.search, message: l10n.searchHint);
    }
    // 有查询但无匹配结果。
    if (results.isEmpty) {
      return EmptyState(icon: Icons.search_off, message: l10n.emptySearch);
    }

    final childrenIndex = indexChildrenByParent(allTasks);
    final effectiveStatuses = computeEffectiveStatuses(allTasks);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceSm,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final task = results[index];
        final hasChildren =
            (childrenIndex[task.id] ?? const <Task>[]).isNotEmpty;
        final isDone =
            (effectiveStatuses[task.id] ?? task.status) == TaskStatus.done;
        return SimpleTaskTile(
          task: task,
          hasChildren: hasChildren,
          isDone: isDone,
          progressValue: taskProgress(task, allTasks),
          onTap: () => openTaskEdit(context, taskId: task.id),
          onToggleDone: hasChildren
              ? null
              : (value) => _toggleDone(ref, task, value),
        );
      },
    );
  }

  Future<void> _toggleDone(WidgetRef ref, Task task, bool? value) async {
    final repo = ref.read(todoRepositoryProvider);
    final newStatus = value == true ? TaskStatus.done : TaskStatus.todo;
    try {
      await repo.updateTask(task.id, status: newStatus);
    } catch (_) {
      // 静默失败：状态会经流自动回滚（与 inbox 页一致）。
    }
  }
}
