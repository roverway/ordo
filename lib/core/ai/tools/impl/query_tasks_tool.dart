import 'package:intl/intl.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/tables.dart';
import 'package:ordo/core/utils/custom_view_models.dart';
import 'package:ordo/core/utils/derived.dart';
import 'package:ordo/core/utils/task_query_engine.dart';
import 'package:ordo/core/utils/tree.dart';
import '../ai_tool.dart';

/// Read-only tool reusing the unified [TaskQueryEngine] to perform multi-dimensional
/// filtering and searching over tasks directly from memory cache.
class QueryTasksTool extends AiTool {
  const QueryTasksTool();

  @override
  String get name => 'query_tasks';

  @override
  String get description =>
      'Query tasks with multi-dimensional filters: date range, completion status, priority, '
      'project, tags, text keywords, or completed timeframe (yesterday, today, thisWeek, lastWeek). '
      'Always call this when the user asks about their tasks, schedule, completed tasks, overdue items, or progress.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'dateScope': {
        'type': 'string',
        'enum': [
          'all',
          'overdue',
          'today',
          'tomorrow',
          'thisWeek',
          'noDate',
          'completedToday',
        ],
        'description':
            'Scheduled date scope: "overdue" (expired), "today", "tomorrow", "thisWeek", "noDate" (unscheduled), "completedToday" (finished today), or "all". Default is "all".',
      },
      'completedScope': {
        'type': 'string',
        'enum': [
          'all',
          'today',
          'yesterday',
          'thisWeek',
          'lastWeek',
          'customRange',
        ],
        'description':
            'Filter tasks completed within a specific timeframe: "today", "yesterday", "thisWeek", "lastWeek", or "customRange". Useful for answering "what did I complete yesterday/this week".',
      },
      'completedAfter': {
        'type': 'string',
        'description':
            'Filter tasks completed after this timestamp or ISO 8601 date / "yyyy-MM-dd HH:mm".',
      },
      'completedBefore': {
        'type': 'string',
        'description':
            'Filter tasks completed before this timestamp or ISO 8601 date / "yyyy-MM-dd HH:mm".',
      },
      'statuses': {
        'type': 'array',
        'items': {
          'type': 'string',
          'enum': ['todo', 'inProgress', 'done', 'cancelled'],
        },
        'description':
            'Filter by status. Default is ["todo", "inProgress"] if asking for pending tasks, or ["done"] for completed tasks.',
      },
      'priorities': {
        'type': 'array',
        'items': {
          'type': 'string',
          'enum': ['none', 'low', 'medium', 'high'],
        },
        'description': 'Filter by priority level: none, low, medium, high.',
      },
      'projectIds': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Filter by specific project IDs.',
      },
      'tagIds': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Filter by specific tag IDs.',
      },
      'searchQuery': {
        'type': 'string',
        'description': 'Keyword search in task title or description.',
      },
      'limit': {
        'type': 'integer',
        'description': 'Maximum number of tasks to return (default: 30).',
      },
    },
    'required': [],
  };

  int? _parseDateToUtcMs(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;
    final asInt = int.tryParse(str);
    if (asInt != null) return asInt;
    try {
      final parsed = DateTime.tryParse(str);
      if (parsed != null) return parsed.toUtc().millisecondsSinceEpoch;
    } catch (_) {}
    try {
      final parsed = DateFormat('yyyy-MM-dd HH:mm').parse(str);
      return parsed.toUtc().millisecondsSinceEpoch;
    } catch (_) {}
    try {
      final parsed = DateFormat('yyyy-MM-dd').parse(str);
      return parsed.toUtc().millisecondsSinceEpoch;
    } catch (_) {}
    return null;
  }

  @override
  Future<AiToolResult> execute(
    Map<String, dynamic> arguments,
    AiToolContext context,
  ) async {
    // 1. Export all data
    final export = await context.repository.exportAll();

    // 2. Map arguments to FilterCriteria
    DateScopeEnum dateScope = DateScopeEnum.all;
    if (arguments['dateScope'] != null) {
      final scopeStr = arguments['dateScope'].toString();
      for (final val in DateScopeEnum.values) {
        if (val.name == scopeStr) {
          dateScope = val;
          break;
        }
      }
    }

    final statuses = <TaskStatus>[];
    if (arguments['statuses'] is List) {
      for (final item in arguments['statuses'] as List) {
        final str = item.toString();
        for (final val in TaskStatus.values) {
          if (val.name == str) {
            statuses.add(val);
            break;
          }
        }
      }
    }

    final priorities = <TaskPriority>[];
    if (arguments['priorities'] is List) {
      for (final item in arguments['priorities'] as List) {
        final str = item.toString();
        for (final val in TaskPriority.values) {
          if (val.name == str) {
            priorities.add(val);
            break;
          }
        }
      }
    }

    final projectIds =
        (arguments['projectIds'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];

    final tagIds =
        (arguments['tagIds'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];

    final searchQuery = arguments['searchQuery']?.toString();
    final limit = (arguments['limit'] as num?)?.toInt() ?? 30;

    final criteria = FilterCriteria(
      dateScope: dateScope,
      statuses: statuses,
      priorities: priorities,
      projectIds: projectIds,
      tagIds: tagIds,
      searchQuery: searchQuery,
    );

    // 3. Prepare index structures for TaskQueryEngine
    final projectsById = {for (final p in export.projects) p.id: p};
    final taskTagIdsMap = {
      for (final entry in export.taskTagIds.entries)
        entry.key: entry.value.toSet(),
    };
    final tagsById = {for (final t in export.tags) t.id: t};
    final childrenIndex = indexChildrenByParent(export.tasks);

    // 4. Run unified filterFlat
    var matchedTasks = TaskQueryEngine.filterFlat(
      tasks: export.tasks,
      criteria: criteria,
      projectsById: projectsById,
      taskTagIdsMap: taskTagIdsMap,
      nowUtcMs: context.currentNowUtcMs,
    );

    // 5. Apply completedScope / completed timeframe filtering if requested
    final completedScope = arguments['completedScope']?.toString();
    final completedAfterRaw = arguments['completedAfter'];
    final completedBeforeRaw = arguments['completedBefore'];

    if ((completedScope != null && completedScope != 'all') ||
        completedAfterRaw != null ||
        completedBeforeRaw != null) {
      final nowLocal = DateTime.fromMillisecondsSinceEpoch(
        context.currentNowUtcMs,
        isUtc: true,
      ).toLocal();
      final todayStart = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

      int? rangeStartUtcMs;
      int? rangeEndUtcMs;

      if (completedScope == 'today') {
        rangeStartUtcMs = todayStart.toUtc().millisecondsSinceEpoch;
        rangeEndUtcMs =
            todayStart
                .add(const Duration(days: 1))
                .toUtc()
                .millisecondsSinceEpoch -
            1;
      } else if (completedScope == 'yesterday') {
        final yestStart = todayStart.subtract(const Duration(days: 1));
        rangeStartUtcMs = yestStart.toUtc().millisecondsSinceEpoch;
        rangeEndUtcMs = todayStart.toUtc().millisecondsSinceEpoch - 1;
      } else if (completedScope == 'thisWeek') {
        final weekday = todayStart.weekday; // 1=Mon .. 7=Sun
        final weekStart = todayStart.subtract(Duration(days: weekday - 1));
        rangeStartUtcMs = weekStart.toUtc().millisecondsSinceEpoch;
        rangeEndUtcMs =
            weekStart
                .add(const Duration(days: 7))
                .toUtc()
                .millisecondsSinceEpoch -
            1;
      } else if (completedScope == 'lastWeek') {
        final weekday = todayStart.weekday;
        final thisWeekStart = todayStart.subtract(Duration(days: weekday - 1));
        final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
        rangeStartUtcMs = lastWeekStart.toUtc().millisecondsSinceEpoch;
        rangeEndUtcMs = thisWeekStart.toUtc().millisecondsSinceEpoch - 1;
      }

      if (completedAfterRaw != null) {
        final customAfter = _parseDateToUtcMs(completedAfterRaw);
        if (customAfter != null) {
          rangeStartUtcMs = customAfter;
        }
      }
      if (completedBeforeRaw != null) {
        final customBefore = _parseDateToUtcMs(completedBeforeRaw);
        if (customBefore != null) {
          rangeEndUtcMs = customBefore;
        }
      }

      matchedTasks = matchedTasks.where((task) {
        final directChildren = childrenIndex[task.id] ?? const <Task>[];
        final effectiveStatus = directChildren.isEmpty
            ? task.status
            : derivedStatus(task, directChildren);
        if (effectiveStatus != TaskStatus.done) return false;

        final compAt = derivedCompletedAt(task, childrenIndex);
        if (compAt == null) return false;

        if (rangeStartUtcMs != null && compAt < rangeStartUtcMs) return false;
        if (rangeEndUtcMs != null && compAt > rangeEndUtcMs) return false;

        return true;
      }).toList();
    }

    // 6. Serialize matched tasks with complete metadata (completion time, subtask stats, etc.)
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final limited = matchedTasks.take(limit).map((Task t) {
      final proj = projectsById[t.projectId];
      final taskTags = (export.taskTagIds[t.id] ?? [])
          .map((id) => tagsById[id]?.name)
          .whereType<String>()
          .toList();

      final directChildren = childrenIndex[t.id] ?? const <Task>[];
      final effectiveStatus = directChildren.isEmpty
          ? t.status
          : derivedStatus(t, directChildren);
      final effectiveCompAt = derivedCompletedAt(t, childrenIndex);

      String? dueStr;
      if (t.endAt != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(
          t.endAt!,
          isUtc: true,
        ).toLocal();
        dueStr = dateFormat.format(dt);
      }

      String? startStr;
      if (t.startAt != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(
          t.startAt!,
          isUtc: true,
        ).toLocal();
        startStr = dateFormat.format(dt);
      }

      String? completedStr;
      if (effectiveCompAt != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(
          effectiveCompAt,
          isUtc: true,
        ).toLocal();
        completedStr = dateFormat.format(dt);
      }

      final createdDt = DateTime.fromMillisecondsSinceEpoch(
        t.createdAt,
        isUtc: true,
      ).toLocal();
      final createdStr = dateFormat.format(createdDt);

      final isDone = effectiveStatus == TaskStatus.done;

      return {
        'id': t.id,
        'title': t.title,
        if (t.description.isNotEmpty) 'description': t.description,
        'status': effectiveStatus.name,
        'priority': t.priority.name,
        if (proj != null) 'project': proj.name,
        if (taskTags.isNotEmpty) 'tags': taskTags,
        'startDate': ?startStr,
        'dueDate': ?dueStr,
        'isCompleted': isDone,
        if (completedStr != null) 'completedDate': completedStr,
        if (effectiveCompAt != null) 'completedAt': effectiveCompAt,
        'createdDate': createdStr,
        'createdAt': t.createdAt,
        if (directChildren.isNotEmpty) ...{
          'subtaskCount': directChildren.length,
          'completedSubtaskCount': directChildren.where((c) {
            final childChildren = childrenIndex[c.id] ?? const <Task>[];
            final st = childChildren.isEmpty
                ? c.status
                : derivedStatus(c, childChildren);
            return st == TaskStatus.done;
          }).length,
        },
        if (t.parentId != null) 'parentId': t.parentId,
      };
    }).toList();

    return AiToolResult.ok({
      'totalMatched': matchedTasks.length,
      'returnedCount': limited.length,
      'tasks': limited,
    });
  }
}
