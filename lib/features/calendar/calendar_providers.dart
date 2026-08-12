import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/utils/view_rules.dart';
import '../projects/project_providers.dart';

/// 日历视图模式（FR-VIEW-02）：月视图 / 周视图。
enum CalendarMode { month, week }

/// 日历视图状态：当前选中的日期 + 视图模式。
///
/// [selectedDate] 为本地时间，决定显示的月份/周；进入页面默认今天、月视图。
class CalendarState {
  const CalendarState({required this.selectedDate, required this.mode});

  final DateTime selectedDate;
  final CalendarMode mode;

  CalendarState copyWith({DateTime? selectedDate, CalendarMode? mode}) {
    return CalendarState(
      selectedDate: selectedDate ?? this.selectedDate,
      mode: mode ?? this.mode,
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
    );
  }

  /// 上一月：selectedDate 平移一个月（跨月时按目标月实际天数钳制日期）。
  void prevMonth() => _shiftMonth(-1);

  /// 下一月。
  void nextMonth() => _shiftMonth(1);

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
  final sunday = DateTime(selected.year, selected.month, monday.day + 6);
  return (
    start: DateTime(monday.year, monday.month, monday.day),
    end: DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59, 999),
  );
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
