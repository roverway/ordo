// 视图匹配纯函数（docs/10-requirements.md §9 / FR-VIEW-05 / FR-VIEW-06）。
//
// 纯函数：不依赖 Widget / Riverpod / 数据库，输入输出可单测
// （70-milestones.md M3 DoD）。
//
// 时间约定（docs/40-data-model.md §4）：Task.startAt / Task.endAt 一律为
// UTC 毫秒 int，用 `DateTime.fromMillisecondsSinceEpoch(ms)` 得到本地时间；
// 「今天」边界与区间边界（rangeStart / rangeEnd）由调用方以本地时间传入。

import '../db/database.dart';
import '../db/tables.dart';

/// 今日视图匹配（§9.1，FR-VIEW-01）。
///
/// [todayStart] / [todayEnd] 为本地「今天」边界（闭区间），毫秒比较。
/// 满足任一条件即入选：
/// 1. `startAt` 落在 [todayStart, todayEnd]；
/// 2. `endAt` 落在 [todayStart, todayEnd]；
/// 3. `startAt <= todayEnd` 且 `endAt != null` 且 `endAt >= todayEnd`
///    （跨天区间覆盖今天）。
/// 无时间任务（startAt 与 endAt 均为 null）不入选。
bool matchesToday(Task task, DateTime todayStart, DateTime todayEnd) {
  final startAt = task.startAt;
  final endAt = task.endAt;
  if (startAt == null && endAt == null) return false;

  final startMs = todayStart.millisecondsSinceEpoch;
  final endMs = todayEnd.millisecondsSinceEpoch;
  if (startAt != null && startAt >= startMs && startAt <= endMs) return true;
  if (endAt != null && endAt >= startMs && endAt <= endMs) return true;
  if (startAt != null && endAt != null && startAt <= endMs && endAt >= endMs) {
    return true;
  }
  return false;
}

/// 逾期判定（§9.3，FR-VIEW-01 AC：过期未完成的任务标红）。
///
/// `endAt != null` 且 `endAt < todayStart`（毫秒比较）且 [effectiveStatus]
/// 不是 `done/cancelled` → 逾期。
///
/// [effectiveStatus] 为派生后状态（有子任务的任务由子任务派生，
/// AGENTS.md §3-2），由调用方传入；无子任务时即 `task.status`。
bool isOverdue(Task task, TaskStatus effectiveStatus, DateTime todayStart) {
  final endAt = task.endAt;
  if (endAt == null) return false;
  if (endAt >= todayStart.millisecondsSinceEpoch) return false;
  return effectiveStatus != TaskStatus.done &&
      effectiveStatus != TaskStatus.cancelled;
}

/// 日历视图应显示的本地日期集合（§9.2，FR-VIEW-02），裁剪到
/// [rangeStart, rangeEnd] 范围内。
///
/// - startAt 与 endAt 都有 → [startAt, endAt] 区间内每天；
/// - 仅 endAt → 截止日当天；
/// - 仅 startAt → 开始日当天；
/// - 都无 → 空集。
///
/// 返回值为 DateOnly（`DateTime(y, m, d)`，本地时间），逐天用日历算术推进
/// （`DateTime(y, m, d + 1)`）以规避 DST 导致的 ±1h 漂移。
Set<DateTime> calendarDaysForTask(
  Task task,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final startAt = task.startAt;
  final endAt = task.endAt;
  if (startAt == null && endAt == null) return const {};

  final rangeStartDay = DateTime(
    rangeStart.year,
    rangeStart.month,
    rangeStart.day,
  );
  final rangeEndDay = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);

  DateTime startDay;
  DateTime endDay;
  if (startAt != null && endAt != null) {
    final s = DateTime.fromMillisecondsSinceEpoch(startAt);
    final e = DateTime.fromMillisecondsSinceEpoch(endAt);
    startDay = DateTime(s.year, s.month, s.day);
    endDay = DateTime(e.year, e.month, e.day);
  } else {
    final only = DateTime.fromMillisecondsSinceEpoch(endAt ?? startAt!);
    startDay = DateTime(only.year, only.month, only.day);
    endDay = startDay;
  }

  // 裁剪到 [rangeStartDay, rangeEndDay]。
  final first = startDay.isBefore(rangeStartDay) ? rangeStartDay : startDay;
  final last = endDay.isAfter(rangeEndDay) ? rangeEndDay : endDay;
  if (last.isBefore(first)) return const {};

  final days = <DateTime>{};
  var day = first;
  while (!day.isAfter(last)) {
    days.add(day);
    day = DateTime(day.year, day.month, day.day + 1);
  }
  return days;
}

/// 搜索匹配（FR-VIEW-05）：`query.trim()` 为空 → false；否则大小写不敏感的
/// substring 匹配（`toLowerCase().contains(...)`），title / description /
/// notes 任一命中即 true（v1 不做中文分词）。
bool matchesSearch(Task task, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return false;
  return task.title.toLowerCase().contains(q) ||
      task.description.toLowerCase().contains(q) ||
      task.notes.toLowerCase().contains(q);
}

/// 时间段筛选（FR-VIEW-06）：任务与区间有交集即 true。
///
/// 语义与 §9.2 日历匹配对齐（定稿补充）：
/// - startAt 与 endAt 都有 → 区间 [startAt, endAt] 与 [rangeStart, rangeEnd] 有交集；
/// - 仅 startAt → startAt 落在区间内（开始日显示）；
/// - 仅 endAt → endAt 落在区间内（截止日显示）；
/// - 都为空 → false（无时间任务不参与时间段筛选）。
/// 均为毫秒比较。
bool inTimeRange(Task task, DateTime rangeStart, DateTime rangeEnd) {
  final startAt = task.startAt;
  final endAt = task.endAt;
  if (startAt == null && endAt == null) return false;
  final startMs = rangeStart.millisecondsSinceEpoch;
  final endMs = rangeEnd.millisecondsSinceEpoch;
  if (startAt != null && endAt != null) {
    return startAt <= endMs && endAt >= startMs;
  }
  if (startAt != null) {
    return startAt >= startMs && startAt <= endMs;
  }
  return endAt! >= startMs && endAt <= endMs;
}

/// 组合筛选纯函数（FR-VIEW-06）：多个条件 AND 叠加。
///
/// - [status]：按 [effectiveStatuses] 映射的**派生后状态**匹配（有子任务的
///   任务状态由子任务派生，AGENTS.md §3-2）；映射缺失的条目回退到
///   `task.status`。
/// - [rangeStart] / [rangeEnd]：均非 null 时按 [inTimeRange] 时间段筛选。
/// - [allowedTaskIds]：非 null 时只保留 id 在集合内的任务（标签筛选，
///   标签关联由调用方解析为 taskId 集合）。
List<Task> applyTaskFilter(
  List<Task> tasks,
  Map<String, TaskStatus> effectiveStatuses, {
  TaskStatus? status,
  DateTime? rangeStart,
  DateTime? rangeEnd,
  Set<String>? allowedTaskIds,
}) {
  return tasks.where((t) {
    if (status != null && (effectiveStatuses[t.id] ?? t.status) != status) {
      return false;
    }
    if (rangeStart != null &&
        rangeEnd != null &&
        !inTimeRange(t, rangeStart, rangeEnd)) {
      return false;
    }
    if (allowedTaskIds != null && !allowedTaskIds.contains(t.id)) {
      return false;
    }
    return true;
  }).toList();
}
