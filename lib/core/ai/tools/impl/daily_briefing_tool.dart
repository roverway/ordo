import 'package:intl/intl.dart';
import 'package:ordo/core/db/tables.dart';
import '../ai_tool.dart';
import 'ai_date_parser.dart';

/// Read-only tool providing an all-in-one daily overview of tasks: overdue, due today,
/// in-progress, completed today/yesterday, and high-priority pending items.
class DailyBriefingTool extends AiTool {
  const DailyBriefingTool();

  @override
  bool get isReadOnly => true;

  @override
  bool get isIdempotent => true;

  @override
  String get name => 'daily_briefing';

  @override
  String get description =>
      'Retrieves a complete daily task briefing in a single call: overdue tasks, tasks due today, '
      'active in-progress items, tasks completed today and yesterday, and top-priority pending tasks.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'date': {
        'type': 'string',
        'description':
            'Target reference date in "yyyy-MM-dd" or relative format (default: today).',
      },
    },
    'required': [],
  };

  @override
  Future<AiToolResult> execute(
    Map<String, dynamic> arguments,
    AiToolContext context,
  ) async {
    final nowMs = context.currentNowUtcMs;
    DateTime baseDateTime = DateTime.fromMillisecondsSinceEpoch(
      nowMs,
      isUtc: true,
    ).toLocal();

    if (arguments['date'] != null) {
      try {
        final parsed = AiDateParser.parseToUtcMsStrict(
          arguments['date'],
          nowUtcMs: nowMs,
        );
        if (parsed != null) {
          baseDateTime = DateTime.fromMillisecondsSinceEpoch(
            parsed,
            isUtc: true,
          ).toLocal();
        }
      } catch (_) {}
    }

    final todayStart = DateTime(
      baseDateTime.year,
      baseDateTime.month,
      baseDateTime.day,
    );
    final todayEnd = DateTime(
      baseDateTime.year,
      baseDateTime.month,
      baseDateTime.day,
      23,
      59,
      59,
      999,
    );
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final yesterdayEnd = DateTime(
      yesterdayStart.year,
      yesterdayStart.month,
      yesterdayStart.day,
      23,
      59,
      59,
      999,
    );

    final todayStartMs = todayStart.toUtc().millisecondsSinceEpoch;
    final todayEndMs = todayEnd.toUtc().millisecondsSinceEpoch;
    final yesterdayStartMs = yesterdayStart.toUtc().millisecondsSinceEpoch;
    final yesterdayEndMs = yesterdayEnd.toUtc().millisecondsSinceEpoch;

    final export = await context.repository.exportAll();
    final projectsById = {for (final p in export.projects) p.id: p};

    final overdue = <Map<String, dynamic>>[];
    final dueToday = <Map<String, dynamic>>[];
    final inProgress = <Map<String, dynamic>>[];
    final completedToday = <Map<String, dynamic>>[];
    final completedYesterday = <Map<String, dynamic>>[];
    final highPriorityPending = <Map<String, dynamic>>[];

    final projectActiveCount = <String, int>{};
    final projectCompletedCount = <String, int>{};

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    for (final task in export.tasks) {
      if (task.deleted != 0) continue;

      final isCompleted =
          task.status == TaskStatus.done || task.status == TaskStatus.cancelled;
      final projName = projectsById[task.projectId]?.name ?? 'Inbox';

      if (isCompleted) {
        projectCompletedCount[task.projectId] =
            (projectCompletedCount[task.projectId] ?? 0) + 1;

        if (task.completedAt != null) {
          if (task.completedAt! >= todayStartMs &&
              task.completedAt! <= todayEndMs) {
            completedToday.add({
              'id': task.id,
              'title': task.title,
              'projectName': projName,
              'completedAt': dateFormat.format(
                DateTime.fromMillisecondsSinceEpoch(
                  task.completedAt!,
                  isUtc: true,
                ).toLocal(),
              ),
            });
          } else if (task.completedAt! >= yesterdayStartMs &&
              task.completedAt! <= yesterdayEndMs) {
            completedYesterday.add({
              'id': task.id,
              'title': task.title,
              'projectName': projName,
              'completedAt': dateFormat.format(
                DateTime.fromMillisecondsSinceEpoch(
                  task.completedAt!,
                  isUtc: true,
                ).toLocal(),
              ),
            });
          }
        }
      } else {
        projectActiveCount[task.projectId] =
            (projectActiveCount[task.projectId] ?? 0) + 1;

        final taskSummary = {
          'id': task.id,
          'title': task.title,
          'status': task.status.name,
          'priority': task.priority.name,
          'priorityLevel': task.priority.index,
          'projectName': projName,
          'dueDate': task.endAt != null
              ? dateFormat.format(
                  DateTime.fromMillisecondsSinceEpoch(
                    task.endAt!,
                    isUtc: true,
                  ).toLocal(),
                )
              : null,
        };

        if (task.status == TaskStatus.inProgress) {
          inProgress.add(taskSummary);
        }

        if (task.priority == TaskPriority.high) {
          highPriorityPending.add(taskSummary);
        }

        if (task.endAt != null) {
          if (task.endAt! < todayStartMs) {
            overdue.add(taskSummary);
          } else if (task.endAt! >= todayStartMs && task.endAt! <= todayEndMs) {
            dueToday.add(taskSummary);
          }
        }
      }
    }

    final projectSummaries = export.projects.where((p) => p.deleted == 0).map((
      p,
    ) {
      return {
        'id': p.id,
        'name': p.name,
        'activeTasks': projectActiveCount[p.id] ?? 0,
        'completedTasks': projectCompletedCount[p.id] ?? 0,
      };
    }).toList();

    return AiToolResult.ok({
      'referenceDate': DateFormat('yyyy-MM-dd').format(baseDateTime),
      'summary': {
        'overdueCount': overdue.length,
        'dueTodayCount': dueToday.length,
        'inProgressCount': inProgress.length,
        'completedTodayCount': completedToday.length,
        'completedYesterdayCount': completedYesterday.length,
        'highPriorityPendingCount': highPriorityPending.length,
      },
      'overdue': overdue,
      'dueToday': dueToday,
      'inProgress': inProgress,
      'highPriorityPending': highPriorityPending.take(5).toList(),
      'completedToday': completedToday,
      'completedYesterday': completedYesterday,
      'projectSummaries': projectSummaries,
    });
  }
}
