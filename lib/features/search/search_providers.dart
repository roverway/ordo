// 搜索与筛选状态管理（FR-VIEW-05 / FR-VIEW-06，M3）。
//
// - searchQueryProvider：防抖搜索（输入即搜，防抖 300ms，FR-VIEW-05 AC）；
// - searchFilterProvider：会话内筛选状态（FR-VIEW-06 AC：筛选条件在视图内
//   持久=会话内，故用普通 NotifierProvider，不使用 autoDispose）；
// - searchResultsProvider：查询（matchesSearch）+ 组合筛选（applyTaskFilter）
//   的结果流；筛选纯函数与时间段匹配均在 view_rules.dart。
//
// 时间约定（view_rules.dart）：startAt/endAt 为 UTC 毫秒，时间段边界以本地
// 时间计算（docs/40-data-model.md §4），此处基于 DateTime.now() 推导。

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/utils/derived.dart';
import '../../core/utils/tree.dart';
import '../../core/utils/view_rules.dart';
import '../projects/project_providers.dart';

/// 时间段筛选选项（FR-VIEW-06）。
enum TimeRange { all, today, week, month }

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
  static const Duration debounceDuration = Duration(milliseconds: 300);

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
}

/// 搜索查询 Provider（会话内保留，便于多次进出页面恢复输入）。
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

/// 会话内筛选状态（FR-VIEW-06）。
class SearchFilterState {
  const SearchFilterState({
    this.status,
    this.tagId,
    this.range = TimeRange.all,
  });

  /// 状态筛选（null = 全部）。
  final TaskStatus? status;

  /// 标签筛选（null = 全部标签）。
  final String? tagId;

  /// 时间段筛选（默认全部）。
  final TimeRange range;

  /// 任一筛选条件激活。
  bool get isActive =>
      status != null || tagId != null || range != TimeRange.all;
}

/// 会话内筛选状态 Notifier（FR-VIEW-06 AC：视图内持久=会话内）。
class SearchFilterNotifier extends Notifier<SearchFilterState> {
  @override
  SearchFilterState build() => const SearchFilterState();

  void setStatus(TaskStatus? status) {
    state = SearchFilterState(
      status: status,
      tagId: state.tagId,
      range: state.range,
    );
  }

  void setTagId(String? tagId) {
    state = SearchFilterState(
      status: state.status,
      tagId: tagId,
      range: state.range,
    );
  }

  void setTimeRange(TimeRange range) {
    state = SearchFilterState(
      status: state.status,
      tagId: state.tagId,
      range: range,
    );
  }

  void clear() => state = const SearchFilterState();
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

/// 搜索结果流（FR-VIEW-05/06）：`watchAllActive` → `matchesSearch` →
/// `applyTaskFilter` 组合筛选（状态/时间段/标签，多条件 AND 叠加）。
///
/// - 空/空白查询 → 空列表（matchesSearch 语义），页面显示提示；
/// - 状态筛选按派生状态匹配（有子任务的任务由子任务派生）；
/// - 时间段筛选由 [TimeRange] 基于 `DateTime.now()` 计算本地边界；
/// - 标签筛选由 tagId 解析为 taskId 白名单（tasksForTag）。
final searchResultsProvider = StreamProvider<List<Task>>((ref) async* {
  final repo = ref.watch(todoRepositoryProvider);
  final allAsync = ref.watch(allActiveTasksProvider);
  final query = ref.watch(searchQueryProvider);
  final filter = ref.watch(searchFilterProvider);

  final all = allAsync.value ?? const <Task>[];
  final effectiveStatuses = computeEffectiveStatuses(all);

  // FR-VIEW-05：大小写不敏感 substring 匹配 title/description/notes；
  // 空查询 → 空结果（页面显示提示）。
  final matched = all.where((t) => matchesSearch(t, query)).toList();

  // FR-VIEW-06：时间段边界（本地时区）。
  final bounds = timeRangeBounds(filter.range, DateTime.now());

  // FR-VIEW-06：标签筛选 → taskId 白名单。
  Set<String>? allowedTaskIds;
  final tagId = filter.tagId;
  if (tagId != null) {
    final tagged = await repo.tags.tasksForTag(tagId);
    allowedTaskIds = {for (final t in tagged) t.id};
  }

  yield applyTaskFilter(
    matched,
    effectiveStatuses,
    status: filter.status,
    rangeStart: bounds.start,
    rangeEnd: bounds.end,
    allowedTaskIds: allowedTaskIds,
  );
});
