import 'package:intl/intl.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/tables.dart';
import 'package:ordo/core/utils/custom_view_models.dart';
import 'package:ordo/core/utils/task_query_engine.dart';
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
      'project, tags, or text keywords. Always call this when the user asks about their tasks, schedule, '
      'overdue items, or progress.';

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
            'Date scope: "overdue" (expired), "today", "tomorrow", "thisWeek", "noDate" (unscheduled), "completedToday" (finished today), or "all". Default is "all".',
      },
      'statuses': {
        'type': 'array',
        'items': {
          'type': 'string',
          'enum': ['todo', 'inProgress', 'done', 'cancelled'],
        },
        'description':
            'Filter by status. Default is ["todo", "inProgress"] if asking for pending tasks.',
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

    // 4. Run unified filterFlat
    final matchedTasks = TaskQueryEngine.filterFlat(
      tasks: export.tasks,
      criteria: criteria,
      projectsById: projectsById,
      taskTagIdsMap: taskTagIdsMap,
      nowUtcMs: context.currentNowUtcMs,
    );

    // 5. Serialize matched tasks
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final limited = matchedTasks.take(limit).map((Task t) {
      final proj = projectsById[t.projectId];
      final taskTags = (export.taskTagIds[t.id] ?? [])
          .map((id) => tagsById[id]?.name)
          .whereType<String>()
          .toList();

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

      return {
        'id': t.id,
        'title': t.title,
        'status': t.status.name,
        'priority': t.priority.name,
        if (proj != null) 'project': proj.name,
        if (taskTags.isNotEmpty) 'tags': taskTags,
        'startDate': ?startStr,
        'dueDate': ?dueStr,
        'isCompleted': t.status == TaskStatus.done,
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
