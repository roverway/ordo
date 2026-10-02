import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/custom_view_models.dart';
import '../../core/utils/derived.dart';
import '../../core/utils/task_query_engine.dart';
import '../../core/utils/tree.dart';
import '../projects/project_providers.dart';

// 搜索与筛选状态管理（FR-VIEW-05 / FR-VIEW-06，M3）。
//
// - searchQueryProvider：防抖搜索（输入即搜，防抖 300ms，FR-VIEW-05 AC）；
// - searchFilterProvider：会话内筛选状态（FR-VIEW-06 AC：筛选条件在视图内
//   持久=会话内，故用普通 NotifierProvider，不使用 autoDispose）；
// - searchResultsProvider：查询（matchesSearch）+ 组合筛选（applyTaskFilter）
//   的结果流；筛选纯函数与时间段匹配均在 view_rules.dart。
// - searchHistoryProvider：最近搜索历史标签（支持快捷点击与一键清除）。
//
// 时间约定（view_rules.dart）：startAt/endAt 为 UTC 毫秒，时间段边界以本地
// 时间计算（docs/40-data-model.md §4），此处基于 DateTime.now() 推导。

/// 时间段筛选选项（FR-VIEW-06）。
enum TimeRange { all, today, week, month }

/// 搜索排序原则
enum SearchSortPrinciple { dueDate, priority, createdAt, title }

class SearchSortNotifier extends Notifier<SearchSortPrinciple> {
  @override
  SearchSortPrinciple build() => SearchSortPrinciple.dueDate;

  void setPrinciple(SearchSortPrinciple principle) {
    state = principle;
  }
}

final searchSortProvider =
    NotifierProvider<SearchSortNotifier, SearchSortPrinciple>(
      SearchSortNotifier.new,
    );

/// 由 [TimeRange] 计算本地时间段边界（闭区间，供 inTimeRange 毫秒比较）。
///
/// - all：不启用时间段筛选（返回 null）；
/// - today：[今日 00:00, 今日 23:59:59.999]；
/// - week：[本周一 00:00, 本周日 23:59:59.999]；
/// - month：[本月 1 日 00:00, 本月最后一天 23:59:59.999]。
///
/// 用日历算术（`DateTime(y, m, d ± k)`）推进，规避 DST 导致的 ±1h 漂移。
({DateTime? start, DateTime? end}) timeRangeBounds(
  TimeRange range,
  DateTime now,
) {
  switch (range) {
    case TimeRange.all:
      return (start: null, end: null);
    case TimeRange.today:
      final start = DateTime(now.year, now.month, now.day);
      return (
        start: start,
        end: DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
      );
    case TimeRange.week:
      final monday = DateTime(
        now.year,
        now.month,
        now.day - (now.weekday - DateTime.monday),
      );
      final sunday = DateTime(monday.year, monday.month, monday.day + 6);
      return (
        start: monday,
        end: DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999),
      );
    case TimeRange.month:
      final start = DateTime(now.year, now.month, 1);
      final last = DateTime(now.year, now.month + 1, 0);
      return (
        start: start,
        end: DateTime(last.year, last.month, last.day, 23, 59, 59, 999),
      );
  }
}

/// 防抖搜索 Notifier（FR-VIEW-05：输入即搜，防抖 300ms）。
///
/// [onQueryChanged] 每次输入重置计时器，到点才更新 query（触发结果流重算）；
/// dispose 时取消未触发的计时器。
class SearchQueryNotifier extends Notifier<String> {
  /// 防抖时长（FR-VIEW-05 AC）。
  static const Duration debounceDuration = AppTokens.searchDebounceDuration;

  Timer? _debounce;

  @override
  String build() {
    // 作用域销毁时取消未触发的防抖计时器。
    ref.onDispose(() => _debounce?.cancel());
    return '';
  }

  /// 输入变化：重置防抖计时器，到点才更新 query。
  void onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(debounceDuration, () {
      state = value;
    });
  }

  /// 立即更新 query（无需等待防抖，例如点击历史记录）。
  void setImmediate(String value) {
    _debounce?.cancel();
    state = value;
  }
}

/// 搜索查询 Provider（会话内保留，便于多次进出页面恢复输入）。
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

/// 最近搜索历史标签 Notifier
class SearchHistoryNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void add(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final list = List<String>.from(state);
    list.remove(trimmed);
    list.insert(0, trimmed);
    if (list.length > 8) {
      list.removeLast();
    }
    state = list;
  }

  void remove(String query) {
    state = state.where((item) => item != query).toList();
  }

  void clear() => state = const [];
}

/// 最近搜索历史标签 Provider
final searchHistoryProvider =
    NotifierProvider<SearchHistoryNotifier, List<String>>(
      SearchHistoryNotifier.new,
    );

/// 会话内筛选状态（FR-VIEW-06）。
class SearchFilterState {
  const SearchFilterState({
    this.status,
    this.tagId,
    this.range = TimeRange.all,
    this.projectId,
    this.priority,
    this.isTreeMode = false,
  });

  /// 状态筛选（null = 全部）。
  final TaskStatus? status;

  /// 标签筛选（null = 全部标签）。
  final String? tagId;

  /// 时间段筛选（默认全部）。
  final TimeRange range;

  /// 项目筛选（null = 全部项目）。
  final String? projectId;

  /// 优先级筛选（null = 全部优先级）。
  final TaskPriority? priority;

  /// 是否为树状层级视图（默认 false 为扁平列表）。
  final bool isTreeMode;

  /// 任意筛选条件激活。
  bool get isActive =>
      status != null ||
      tagId != null ||
      range != TimeRange.all ||
      projectId != null ||
      priority != null;

  SearchFilterState copyWith({
    TaskStatus? Function()? status,
    String? Function()? tagId,
    TimeRange? range,
    String? Function()? projectId,
    TaskPriority? Function()? priority,
    bool? isTreeMode,
  }) {
    return SearchFilterState(
      status: status != null ? status() : this.status,
      tagId: tagId != null ? tagId() : this.tagId,
      range: range ?? this.range,
      projectId: projectId != null ? projectId() : this.projectId,
      priority: priority != null ? priority() : this.priority,
      isTreeMode: isTreeMode ?? this.isTreeMode,
    );
  }
}

/// 会话内筛选状态 Notifier（FR-VIEW-06 AC：视图内持久=会话内）。
class SearchFilterNotifier extends Notifier<SearchFilterState> {
  @override
  SearchFilterState build() => const SearchFilterState();

  void setStatus(TaskStatus? status) {
    state = state.copyWith(status: () => status);
  }

  void setTagId(String? tagId) {
    state = state.copyWith(tagId: () => tagId);
  }

  void setTimeRange(TimeRange range) {
    state = state.copyWith(range: range);
  }

  void setProjectId(String? projectId) {
    state = state.copyWith(projectId: () => projectId);
  }

  void setPriority(TaskPriority? priority) {
    state = state.copyWith(priority: () => priority);
  }

  void setTreeMode(bool isTreeMode) {
    state = state.copyWith(isTreeMode: isTreeMode);
  }

  void toggleTreeMode() {
    state = state.copyWith(isTreeMode: !state.isTreeMode);
  }

  void clear() => state = SearchFilterState(isTreeMode: state.isTreeMode);
}

/// 会话内筛选状态 Provider（**勿改 autoDispose**，FR-VIEW-06）。
final searchFilterProvider =
    NotifierProvider<SearchFilterNotifier, SearchFilterState>(
      SearchFilterNotifier.new,
    );

/// 计算扁平任务列表的派生状态映射（id → 派生后状态）。
///
/// 有直接子任务的任务状态由子任务派生（AGENTS.md §3-2），叶子任务返回自身
/// 存储状态；`applyTaskFilter` 对映射缺失条目回退到 `task.status`。
/// 纯函数，可单测。
Map<String, TaskStatus> computeEffectiveStatuses(List<Task> tasks) {
  final childrenIndex = indexChildrenByParent(tasks);
  return {
    for (final t in tasks)
      if (t.deleted == 0)
        t.id: derivedStatus(t, childrenIndex[t.id] ?? const <Task>[]),
  };
}

final searchResultsProvider = StreamProvider<List<Task>>((ref) async* {
  final repo = ref.watch(todoRepositoryProvider);
  final allAsync = ref.watch(allActiveTasksProvider);
  final query = ref.watch(searchQueryProvider);
  final filter = ref.watch(searchFilterProvider);
  final sort = ref.watch(searchSortProvider);

  final all = allAsync.value ?? const <Task>[];
  final projects = ref.watch(projectsStreamProvider).value ?? const <Project>[];
  final projectsMap = {for (final p in projects) p.id: p};

  final taskTagIdsMap = <String, Set<String>>{};
  if (filter.tagId != null) {
    final tagged = await repo.tags.tasksForTag(filter.tagId!);
    for (final t in tagged) {
      taskTagIdsMap.putIfAbsent(t.id, () => {}).add(filter.tagId!);
    }
  }

  final dateScope = switch (filter.range) {
    TimeRange.all => DateScopeEnum.all,
    TimeRange.today => DateScopeEnum.today,
    TimeRange.week => DateScopeEnum.thisWeek,
    TimeRange.month => DateScopeEnum.customRange,
  };

  int? customStart;
  int? customEnd;
  if (filter.range == TimeRange.month) {
    final bounds = timeRangeBounds(TimeRange.month, DateTime.now());
    customStart = bounds.start?.millisecondsSinceEpoch;
    customEnd = bounds.end?.millisecondsSinceEpoch;
  }

  final criteria = FilterCriteria(
    statuses: filter.status != null ? [filter.status!] : const [],
    tagIds: filter.tagId != null ? [filter.tagId!] : const [],
    projectIds: filter.projectId != null ? [filter.projectId!] : const [],
    priorities: filter.priority != null ? [filter.priority!] : const [],
    dateScope: dateScope,
    customDateStart: customStart,
    customDateEnd: customEnd,
    searchQuery: query.trim().isEmpty ? null : query.trim(),
  );

  if (filter.isTreeMode) {
    final list = TaskQueryEngine.filterTree(
      tasks: all,
      criteria: criteria,
      projectsById: projectsMap,
      taskTagIdsMap: taskTagIdsMap,
      nowUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    yield sortTasksAsTree(list, sort);
  } else {
    final list = TaskQueryEngine.filterFlat(
      tasks: all,
      criteria: criteria,
      projectsById: projectsMap,
      taskTagIdsMap: taskTagIdsMap,
      nowUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    final sortedList = List<Task>.from(list);
    sortedList.sort((a, b) => compareTasksByPrinciple(a, b, sort));
    yield sortedList;
  }
});

/// 根据用户选定的排序原则对两个任务进行比较。
int compareTasksByPrinciple(Task a, Task b, SearchSortPrinciple sort) {
  switch (sort) {
    case SearchSortPrinciple.dueDate:
      final aTime = a.endAt ?? a.startAt;
      final bTime = b.endAt ?? b.startAt;
      if (aTime == null && bTime == null) {
        return b.updatedAt.compareTo(a.updatedAt);
      }
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      final cmp = aTime.compareTo(bTime);
      return cmp != 0 ? cmp : b.updatedAt.compareTo(a.updatedAt);
    case SearchSortPrinciple.priority:
      final cmp = b.priority.index.compareTo(a.priority.index);
      return cmp != 0 ? cmp : b.updatedAt.compareTo(a.updatedAt);
    case SearchSortPrinciple.createdAt:
      final cmp = b.createdAt.compareTo(a.createdAt);
      return cmp != 0 ? cmp : b.updatedAt.compareTo(a.updatedAt);
    case SearchSortPrinciple.title:
      final cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return cmp != 0 ? cmp : b.updatedAt.compareTo(a.updatedAt);
  }
}

/// 将过滤后的任务集合按树形拓扑结构（深度优先先序遍历 DFS）排序。
///
/// 保证：
/// 1. 根节点与各级同层级子任务均遵循用户选定的 [SearchSortPrinciple] 排序原则；
/// 2. 父任务必然先于子任务出现，子任务深度优先紧随其后；
/// 3. 若任务的 parentId 不在当前可见集合中，自动提升为可见根任务展示；
/// 4. 彻底消除扁平排序与层级树状展示的冲突。
List<Task> sortTasksAsTree(List<Task> tasks, SearchSortPrinciple sort) {
  if (tasks.isEmpty) return const [];

  final byId = {for (final t in tasks) t.id: t};
  final childrenIndex = <String?, List<Task>>{};

  for (final task in tasks) {
    final effectiveParentId =
        (task.parentId != null && byId.containsKey(task.parentId))
        ? task.parentId
        : null;
    childrenIndex.putIfAbsent(effectiveParentId, () => []).add(task);
  }

  final roots = childrenIndex[null] ?? <Task>[];
  roots.sort((a, b) => compareTasksByPrinciple(a, b, sort));

  final result = <Task>[];

  void walk(Task node) {
    result.add(node);
    final children = childrenIndex[node.id] ?? <Task>[];
    children.sort((a, b) => compareTasksByPrinciple(a, b, sort));
    for (final child in children) {
      walk(child);
    }
  }

  for (final root in roots) {
    walk(root);
  }

  return result;
}
