import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/utils/derived.dart';
import '../../core/utils/tree.dart';
import '../../core/utils/view_rules.dart' as view_rules;
import '../projects/project_providers.dart';

/// 今日视图展示模型（FR-VIEW-01，docs/10-requirements.md §9）。
///
/// 一行 = 一个入选任务 + 渲染所需的解析结果。
class TodayTaskView {
  const TodayTaskView({
    required this.task,
    required this.tags,
    required this.hasChildren,
    required this.effectiveStatus,
    required this.isOverdue,
    this.projectName,
    this.projectColor,
    this.progressValue,
    this.subtaskProgressText,
  });

  final Task task;

  /// 任务关联标签（N+1 查询，v1 允许，简单优先）。
  final List<Tag> tags;

  /// 是否有直接子任务（父任务集合 = stream 内 parentId 出现过的 id）。
  final bool hasChildren;

  /// 派生后状态：有子任务由 [derivedStatus] 派生（AGENTS.md §3-2），
  /// 无子任务时即 `task.status`。
  final TaskStatus effectiveStatus;

  /// 是否逾期（view_rules.isOverdue 判定结果，§9.3）。
  final bool isOverdue;

  /// 所属项目名称（跨项目列表展示用）。
  final String? projectName;

  /// 所属项目颜色值（ARGB 32位整数）。
  final int? projectColor;

  /// 有子任务任务的派生完成度（0.0–1.0，进度环用）；无子任务为 null。
  final double? progressValue;

  /// 子任务进度文案（如 "2/5"）；无子任务为 null。
  final String? subtaskProgressText;
}

/// 今日视图分组数据：逾期组 + 今天组（各组内已排序）。
class TodayViewData {
  const TodayViewData({required this.overdue, required this.today});

  /// 逾期组：endAt 升序（最紧迫在前）。
  final List<TodayTaskView> overdue;

  /// 今天组：startAt 升序（null 排最后），再按 updatedAt 降序。
  final List<TodayTaskView> today;

  bool get isEmpty => overdue.isEmpty && today.isEmpty;

  /// 待完成任务总数（逾期 + 今天中未完成项）。
  int get uncompletedCount =>
      overdue.where((v) => v.effectiveStatus != TaskStatus.done).length +
      today.where((v) => v.effectiveStatus != TaskStatus.done).length;

  /// 已完成任务总数
  int get completedCount =>
      overdue.where((v) => v.effectiveStatus == TaskStatus.done).length +
      today.where((v) => v.effectiveStatus == TaskStatus.done).length;

  /// 总任务数
  int get totalCount => overdue.length + today.length;
}

/// 由任务列表计算今日视图展示模型（纯函数 + IO，可单测）。
///
/// - 入选规则：`matchesToday` 命中 **或** 逾期（§9.1 / §9.3）**或** 今天内完成的任务
///   （已完成任务在今天视图中正常显示并在进度环/计数项中计数）。
/// - 无时间任务（startAt/endAt 均 null 且非今天完成）不入选。
Future<TodayViewData> buildTodayView({
  required List<Task> tasks,
  required DateTime now,
  required Future<List<Tag>> Function(String taskId) tagsForTask,
  Future<List<Project>> Function()? getAllProjects,
}) async {
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  final todayStartMs = todayStart.millisecondsSinceEpoch;
  final todayEndMs = todayEnd.millisecondsSinceEpoch;

  final projects = getAllProjects != null
      ? await getAllProjects()
      : const <Project>[];
  final projectsMap = {for (final p in projects) p.id: p};

  // 父任务集合：stream 内 parentId 出现过的 id（hasChildren 判定）。
  final parentIds = <String>{
    for (final t in tasks)
      if (t.parentId != null) t.parentId!,
  };
  final childrenIndex = indexChildrenByParent(tasks);

  final views = <TodayTaskView>[];
  for (final task in tasks) {
    final directChildren = childrenIndex[task.id] ?? const <Task>[];
    // 复用现有派生纯函数（derived.dart）：无子任务时返回 task.status，多级递归派生。
    final effectiveStatus = derivedStatus(task, directChildren, childrenIndex);

    final isOverdue = view_rules.isOverdue(task, effectiveStatus, todayStart);
    final isScheduledToday = view_rules.matchesToday(
      task,
      todayStart,
      todayEnd,
    );

    // 今天完成的任务：有效完成时间（completedAt 或父级派生完成时间）落在今天区间内。
    // 严格依赖 completedAt，历史 NULL 任务不误作为今日完成。
    final compAt = directChildren.isNotEmpty
        ? _getEffectiveCompletedAt(task, childrenIndex)
        : task.completedAt;

    final isDone = effectiveStatus == TaskStatus.done;
    final isCancelled = effectiveStatus == TaskStatus.cancelled;

    // 是否属于今天已完成：
    // 1. 实际在今天内完成（compAt 落在今天内）；
    // 2. 或者原本计划在今天且已完成，且未明确在今天之前完成（compAt 不是昨天/历史）。
    final bool completedToday;
    if (isDone) {
      if (compAt != null) {
        completedToday = compAt >= todayStartMs && compAt <= todayEndMs;
      } else {
        // 无 completedAt 的兼容：如果是今日计划任务，且未在历史完成
        completedToday = isScheduledToday;
      }
    } else {
      completedToday = false;
    }

    final isOpenToday = !isDone && !isCancelled && isScheduledToday;

    if (!isOpenToday && !isOverdue && !completedToday) continue;

    final tags = await tagsForTask(task.id);
    final project = projectsMap[task.projectId];
    final isParent = parentIds.contains(task.id);
    final counts = isParent ? taskSubtreeCounts(task, tasks) : null;

    views.add(
      TodayTaskView(
        task: task,
        tags: tags,
        hasChildren: isParent,
        effectiveStatus: effectiveStatus,
        isOverdue: isOverdue,
        projectName: project?.name,
        projectColor: project?.color,
        // 进度环（滴答式）：有子任务任务按整棵子树统计完成度。
        progressValue: isParent ? taskProgress(task, tasks) : null,
        subtaskProgressText: counts != null
            ? '${counts.done}/${counts.total}'
            : null,
      ),
    );
  }

  // 逾期组：endAt 升序（最紧迫在前）。isOverdue 保证 endAt 非空。
  final overdue = views.where((v) => v.isOverdue).toList()
    ..sort((a, b) => a.task.endAt!.compareTo(b.task.endAt!));

  // 今天组：startAt 升序（null 排最后），再按 updatedAt 降序。
  final today = views.where((v) => !v.isOverdue).toList()..sort(_compareToday);

  return TodayViewData(overdue: overdue, today: today);
}

/// 今天组排序：startAt 升序（null 排最后），再按 updatedAt 降序。
int _compareToday(TodayTaskView a, TodayTaskView b) {
  final aStart = a.task.startAt;
  final bStart = b.task.startAt;
  if (aStart == null && bStart == null) {
    return b.task.updatedAt.compareTo(a.task.updatedAt);
  }
  if (aStart == null) return 1;
  if (bStart == null) return -1;
  final byStart = aStart.compareTo(bStart);
  if (byStart != 0) return byStart;
  return b.task.updatedAt.compareTo(a.task.updatedAt);
}

/// 今日视图流式 Provider：监听全部未删除任务（updatedAt 降序），
/// 每次 DB 变更自动重算展示模型。
final todayViewProvider = StreamProvider<TodayViewData>((ref) async* {
  final repo = ref.watch(todoRepositoryProvider);
  yield* repo.tasks.watchAllActive().asyncMap(
    (tasks) => buildTodayView(
      tasks: tasks,
      now: DateTime.now(),
      tagsForTask: repo.tags.tagsForTask,
      getAllProjects: repo.projects.getAll,
    ),
  );
});

int? _getEffectiveCompletedAt(
  Task task,
  Map<String?, List<Task>> childrenIndex,
) {
  final directChildren = childrenIndex[task.id] ?? const <Task>[];
  if (directChildren.isEmpty) {
    return task.completedAt;
  }
  int? maxTime;
  for (final child in directChildren) {
    final t = _getEffectiveCompletedAt(child, childrenIndex);
    if (t != null && (maxTime == null || t > maxTime)) {
      maxTime = t;
    }
  }
  return maxTime;
}
