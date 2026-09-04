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

  /// 是否属于逾期分组（无论未完成或今日完成）。
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

  /// 逾期组：endAt 升序（最紧迫在前）。包含逾期未完成 + 逾期今日完成。
  final List<TodayTaskView> overdue;

  /// 今天组：startAt 升序（null 排最后），再按 updatedAt 降序。包含今日排期未完成 + 今日完成未逾期。
  final List<TodayTaskView> today;

  bool get isEmpty => overdue.isEmpty && today.isEmpty;

  /// 待完成任务总数（逾期 + 今天中未完成项）。
  int get uncompletedCount =>
      overdue.where((v) => v.effectiveStatus != TaskStatus.done).length +
      today.where((v) => v.effectiveStatus != TaskStatus.done).length;

  /// 已完成任务总数（逾期今日完成 + 今天今日完成）。
  int get completedCount =>
      overdue.where((v) => v.effectiveStatus == TaskStatus.done).length +
      today.where((v) => v.effectiveStatus == TaskStatus.done).length;

  /// 总任务数
  int get totalCount => overdue.length + today.length;
}

/// 由任务列表计算今日视图展示模型（纯函数 + IO，可单测）。
///
/// 业务规则：
/// 1. 历史已完成任务（完成时间 < 今日开始）一律不显示（即使排期跨越今日）；
/// 2. 逾期任务（endAt < 今日开始）：未完成 或 今日完成，归入【逾期组】；
/// 3. 今天任务（!逾期）：排期包含今日未完成 或 今日完成（含无排期但今日完成），归入【今天组】。
Future<TodayViewData> buildTodayView({
  required List<Task> tasks,
  required DateTime now,
  Future<List<Tag>> Function(String taskId)? tagsForTask,
  Future<List<Project>> Function()? getAllProjects,
  Map<String, List<Tag>>? taskTagsMap,
  List<Project>? projects,
}) async {
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
  final todayStartMs = todayStart.millisecondsSinceEpoch;
  final todayEndMs = todayEnd.millisecondsSinceEpoch;

  final resolvedProjects =
      projects ??
      (getAllProjects != null ? await getAllProjects() : const <Project>[]);
  final projectsMap = {for (final p in resolvedProjects) p.id: p};

  final parentIds = <String>{
    for (final t in tasks)
      if (t.parentId != null) t.parentId!,
  };
  final childrenIndex = indexChildrenByParent(tasks);

  final overdueViews = <TodayTaskView>[];
  final todayViews = <TodayTaskView>[];

  for (final task in tasks) {
    final directChildren = childrenIndex[task.id] ?? const <Task>[];
    final effectiveStatus = derivedStatus(task, directChildren, childrenIndex);

    if (effectiveStatus == TaskStatus.cancelled) continue;

    final isDone = effectiveStatus == TaskStatus.done;
    final compAt = derivedCompletedAt(task, childrenIndex);

    final isScheduledToday = view_rules.matchesToday(
      task,
      todayStart,
      todayEnd,
    );

    // 完成状态检查：
    // 如果已完成：有效完成时间必须严格为今日。历史完成或缺失完成时间记录的已完成任务，坚决不进入今日页面。
    final bool completedToday;
    if (isDone) {
      if (compAt != null && compAt >= todayStartMs && compAt <= todayEndMs) {
        completedToday = true;
      } else {
        continue;
      }
    } else {
      completedToday = false;
    }

    final isPastDeadline = task.endAt != null && task.endAt! < todayStartMs;

    // 分组准入判定
    final bool isOverdueGroup;
    if (isPastDeadline) {
      // 逾期任务：未完成或今日完成均属于逾期组
      if (!isDone || completedToday) {
        isOverdueGroup = true;
      } else {
        continue;
      }
    } else {
      // 非逾期任务：排期在今日未完成 或 今日完成（含无排期今日完成）
      if ((!isDone && isScheduledToday) || (isDone && completedToday)) {
        isOverdueGroup = false;
      } else {
        continue;
      }
    }

    final List<Tag> tags;
    if (taskTagsMap != null) {
      tags = taskTagsMap[task.id] ?? const [];
    } else if (tagsForTask != null) {
      tags = await tagsForTask(task.id);
    } else {
      tags = const [];
    }

    final project = projectsMap[task.projectId];
    final isParent = parentIds.contains(task.id);
    final counts = isParent ? taskSubtreeCounts(task, tasks) : null;

    final viewItem = TodayTaskView(
      task: task,
      tags: tags,
      hasChildren: isParent,
      effectiveStatus: effectiveStatus,
      isOverdue: isOverdueGroup,
      projectName: project?.name,
      projectColor: project?.color,
      progressValue: isParent ? taskProgress(task, tasks) : null,
      subtaskProgressText: counts != null
          ? '${counts.done}/${counts.total}'
          : null,
    );

    if (isOverdueGroup) {
      overdueViews.add(viewItem);
    } else {
      todayViews.add(viewItem);
    }
  }

  // 逾期组：endAt 升序（最紧迫在前，安全非空排序）
  overdueViews.sort((a, b) => (a.task.endAt ?? 0).compareTo(b.task.endAt ?? 0));

  // 今天组：startAt 升序（null 排最后），再按 updatedAt 降序
  todayViews.sort(_compareToday);

  return TodayViewData(overdue: overdueViews, today: todayViews);
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
  yield* repo.tasks.watchAllActive().asyncMap((tasks) async {
    // 批量预查项目与标签关联，彻底消除 N+1 数据库查询
    final projects = await repo.projects.getAll();
    final allTags = await repo.tags.getAll();
    final allTaskTags = await repo.tags.getAllTaskTags();

    final tagsById = {for (final t in allTags) t.id: t};
    final taskTagsMap = <String, List<Tag>>{};
    for (final tt in allTaskTags) {
      final tag = tagsById[tt.tagId];
      if (tag != null) {
        taskTagsMap.putIfAbsent(tt.taskId, () => []).add(tag);
      }
    }

    return buildTodayView(
      tasks: tasks,
      now: DateTime.now(),
      taskTagsMap: taskTagsMap,
      projects: projects,
    );
  });
});
