import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/utils/view_rules.dart';
import '../projects/project_providers.dart';

/// 日历视图模式（FR-VIEW-02）：月视图 / 周视图。
enum CalendarMode { month, week }

/// 日历任务列表显示范围：当日（选中日）/ 该周（选中日所在周）/ 该月（选中日所在月）。
enum CalendarAgendaScope { day, week, month }

/// 日历视图状态：当前选中的日期 + 视图模式 + 任务列表显示范围。
///
/// [selectedDate] 为本地时间，决定显示的月份/周；进入页面默认今天、月视图、当日任务。
class CalendarState {
  const CalendarState({
    required this.selectedDate,
    required this.mode,
    this.agendaScope = CalendarAgendaScope.day,
  });

  final DateTime selectedDate;
  final CalendarMode mode;
  final CalendarAgendaScope agendaScope;

  CalendarState copyWith({
    DateTime? selectedDate,
    CalendarMode? mode,
    CalendarAgendaScope? agendaScope,
  }) {
    return CalendarState(
      selectedDate: selectedDate ?? this.selectedDate,
      mode: mode ?? this.mode,
      agendaScope: agendaScope ?? this.agendaScope,
    );
  }
}

/// 日历视图状态 Notifier（Riverpod 3.x Notifier 模式）。
class CalendarNotifier extends Notifier<CalendarState> {
  @override
  CalendarState build() {
    return CalendarState(
      selectedDate: DateTime.now(),
      mode: CalendarMode.month,
      agendaScope: CalendarAgendaScope.day,
    );
  }

  /// 选中指定日期。
  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  /// 设置任务列表显示范围（当日 / 该周 / 该月）。
  void setAgendaScope(CalendarAgendaScope agendaScope) {
    if (state.agendaScope != agendaScope) {
      state = state.copyWith(agendaScope: agendaScope);
    }
  }

  /// 设置视图模式（月 / 周）。
  void setMode(CalendarMode mode) {
    if (state.mode != mode) {
      state = state.copyWith(mode: mode);
    }
  }

  /// 上一月：selectedDate 平移一个月（跨月时按目标月实际天数钳制日期）。
  void prevMonth() => _shiftMonth(-1);

  /// 下一月。
  void nextMonth() => _shiftMonth(1);

  /// 上一周：selectedDate 前移 7 天。
  void prevWeek() {
    final cur = state.selectedDate;
    state = state.copyWith(
      selectedDate: DateTime(cur.year, cur.month, cur.day - 7),
    );
  }

  /// 下一周：selectedDate 后移 7 天。
  void nextWeek() {
    final cur = state.selectedDate;
    state = state.copyWith(
      selectedDate: DateTime(cur.year, cur.month, cur.day + 7),
    );
  }

  /// 切换至上一周期（根据当前月/周模式自适应）。
  void prevPeriod() {
    if (state.mode == CalendarMode.month) {
      prevMonth();
    } else {
      prevWeek();
    }
  }

  /// 切换至下一周期（根据当前月/周模式自适应）。
  void nextPeriod() {
    if (state.mode == CalendarMode.month) {
      nextMonth();
    } else {
      nextWeek();
    }
  }

  /// 月/周视图切换。
  void toggleView() {
    state = state.copyWith(
      mode: state.mode == CalendarMode.month
          ? CalendarMode.week
          : CalendarMode.month,
    );
  }

  /// 回到今天（保持当前视图模式）。
  void goToToday() {
    state = state.copyWith(selectedDate: DateTime.now());
  }

  void _shiftMonth(int delta) {
    final current = state.selectedDate;
    // DateTime 构造器自动归一化月份越界（如 12 月 + 1 → 次年 1 月）。
    final targetFirst = DateTime(current.year, current.month + delta, 1);
    final lastDay = DateTime(targetFirst.year, targetFirst.month + 1, 0).day;
    final day = current.day > lastDay ? lastDay : current.day;
    state = state.copyWith(
      selectedDate: DateTime(targetFirst.year, targetFirst.month, day),
    );
  }
}

/// 日历视图状态 Provider。
final calendarStateProvider = NotifierProvider<CalendarNotifier, CalendarState>(
  CalendarNotifier.new,
);

/// 当前模式显示区间（本地时间，闭区间；起点为 DateOnly 00:00，
/// 终点为当日 23:59:59.999）。
///
/// - 月视图：当月 1 日 00:00 至月末 23:59:59.999；
/// - 周视图：selectedDate 所在周 周一 00:00 至周日 23:59:59.999。
({DateTime start, DateTime end}) calendarRangeFor(CalendarState state) {
  final selected = state.selectedDate;
  if (state.mode == CalendarMode.month) {
    final first = DateTime(selected.year, selected.month, 1);
    final last = DateTime(selected.year, selected.month + 1, 0);
    return (
      start: DateTime(first.year, first.month, first.day),
      end: DateTime(last.year, last.month, last.day, 23, 59, 59, 999),
    );
  }
  final monday = DateTime(
    selected.year,
    selected.month,
    selected.day - (selected.weekday - DateTime.monday),
  );
  final sunday = DateTime(monday.year, monday.month, monday.day + 6);
  return (
    start: DateTime(monday.year, monday.month, monday.day),
    end: DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999),
  );
}

/// 当前议程任务列表显示区间（本地时间，闭区间；起点为 DateOnly 00:00，
/// 终点为末日 23:59:59.999）。
({DateTime start, DateTime end}) calendarAgendaRangeFor(CalendarState state) {
  final selected = state.selectedDate;
  switch (state.agendaScope) {
    case CalendarAgendaScope.day:
      return (
        start: DateTime(selected.year, selected.month, selected.day),
        end: DateTime(
          selected.year,
          selected.month,
          selected.day,
          23,
          59,
          59,
          999,
        ),
      );
    case CalendarAgendaScope.week:
      final monday = DateTime(
        selected.year,
        selected.month,
        selected.day - (selected.weekday - DateTime.monday),
      );
      final sunday = DateTime(monday.year, monday.month, monday.day + 6);
      return (
        start: DateTime(monday.year, monday.month, monday.day),
        end: DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999),
      );
    case CalendarAgendaScope.month:
      final first = DateTime(selected.year, selected.month, 1);
      final last = DateTime(selected.year, selected.month + 1, 0);
      return (
        start: DateTime(first.year, first.month, first.day),
        end: DateTime(last.year, last.month, last.day, 23, 59, 59, 999),
      );
  }
}

/// 根据日历状态和范围筛选并排序议程任务列表（纯函数）。
///
/// 匹配规则：以任务的开始到结束时间区间（含起始点）中任一天匹配到范围为准（[inTimeRange]）。
/// 排序规则：优先按开始时间/截止时间（`startAt ?? endAt`）升序排列，相同按 `updatedAt` 降序。
List<Task> tasksForAgendaScope({
  required List<Task> allTasks,
  required CalendarState state,
}) {
  final range = calendarAgendaRangeFor(state);
  final matched = allTasks
      .where((t) => inTimeRange(t, range.start, range.end))
      .toList();
  matched.sort((a, b) {
    final aTime = a.startAt ?? a.endAt ?? 0;
    final bTime = b.startAt ?? b.endAt ?? 0;
    final timeCmp = aTime.compareTo(bTime);
    if (timeCmp != 0) return timeCmp;
    return b.updatedAt.compareTo(a.updatedAt);
  });
  return matched;
}

/// 由全部任务构建按天分桶（纯函数）。
///
/// 键为本地 DateOnly（`DateTime(y, m, d)`，与 [calendarDaysForTask] 返回值一致）；
/// 对每个任务调 [calendarDaysForTask] 得到区间内应显示的日期集合，逐日入桶，
/// 跨天任务会出现在区间内每一天。桶内顺序继承流顺序（updatedAt 降序）。
/// 只放 [Task]——tags/派生状态由 UI 层按需解析（taskTagsProvider，
/// 定义于 task_providers），避免在流内做 N+1 查询拖慢订阅。
Map<DateTime, List<Task>> buildCalendarBuckets(
  List<Task> tasks,
  CalendarState state,
) {
  final range = calendarRangeFor(state);
  final buckets = <DateTime, List<Task>>{};
  for (final task in tasks) {
    for (final day in calendarDaysForTask(task, range.start, range.end)) {
      buckets.putIfAbsent(day, () => []).add(task);
    }
  }
  return buckets;
}

/// 按天取任务（UI 层 helper）：键归一为本地 DateOnly 再查桶。
List<Task> tasksForDay(Map<DateTime, List<Task>> buckets, DateTime day) {
  return buckets[DateTime(day.year, day.month, day.day)] ?? const [];
}

/// 日历按天分桶流：watch 状态 + 全部任务流，按当前模式重算区间与分桶。
///
/// 状态（翻月/切视图）变化或任务变更时自动重算；同一任务可出现在多天。
final calendarBucketsProvider = StreamProvider<Map<DateTime, List<Task>>>((
  ref,
) async* {
  final state = ref.watch(calendarStateProvider);
  final tasks = await ref.watch(allActiveTasksProvider.future);
  yield buildCalendarBuckets(tasks, state);
});
