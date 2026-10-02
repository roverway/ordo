import 'package:intl/intl.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/tables.dart';
import 'package:ordo/core/utils/custom_view_models.dart';
import 'package:ordo/core/utils/derived.dart';
import 'package:ordo/core/utils/task_query_engine.dart';
import 'package:ordo/core/utils/tree.dart';
import '../ai_tool.dart';
import 'ai_date_parser.dart';

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
      'Supports field projection (fields) and cursor pagination.';

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
            'Filter tasks completed within a specific timeframe: "today", "yesterday", "thisWeek", "lastWeek", or "customRange".',
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
        'description':
            'Maximum number of tasks to return (default: 30, max: 200).',
      },
      'cursor': {
        'type': 'string',
        'description': 'Pagination cursor (0-based integer offset string).',
      },
      'fields': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'Optional field projection to reduce token usage (e.g. ["id", "title", "status", "dueDate"]).',
      },
    },
  };

  static int? _parseDateToUtcMs(dynamic raw) => AiDateParser.parseToUtcMs(raw);

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
    final rawLimit = (arguments['limit'] as num?)?.toInt() ?? 30;
    final limit = rawLimit.clamp(1, 200);

    final offset = int.tryParse(arguments['cursor']?.toString() ?? '') ?? 0;

    // Map completedScope and completion range
    CompletedScopeEnum completedScope = CompletedScopeEnum.all;
    if (arguments['completedScope'] != null) {
      final scopeStr = arguments['completedScope'].toString();
      for (final val in CompletedScopeEnum.values) {
        if (val.name == scopeStr) {
          completedScope = val;
          break;
        }
      }
    }

    final completedAfterRaw = arguments['completedAfter'];
    final completedBeforeRaw = arguments['completedBefore'];
    final completedAfterUtcMs = _parseDateToUtcMs(completedAfterRaw);
    final completedBeforeUtcMs = _parseDateToUtcMs(completedBeforeRaw);

    final criteria = FilterCriteria(
      dateScope: dateScope,
      statuses: statuses,
      priorities: priorities,
      projectIds: projectIds,
      tagIds: tagIds,
      searchQuery: searchQuery,
      completedScope: completedScope,
      completedAfterUtcMs: completedAfterUtcMs,
      completedBeforeUtcMs: completedBeforeUtcMs,
    );

    // 3. Prepare index structures for TaskQueryEngine
    final projectsById = {for (final p in export.projects) p.id: p};
    final taskTagIdsMap = {
      for (final entry in export.taskTagIds.entries)
        entry.key: entry.value.toSet(),
    };
    final tagsById = {for (final t in export.tags) t.id: t};
    final childrenIndex = indexChildrenByParent(export.tasks);

    // 4. Run unified filterFlat directly through TaskQueryEngine
    final matchedTasks = TaskQueryEngine.filterFlat(
      tasks: export.tasks,
      criteria: criteria,
      projectsById: projectsById,
      taskTagIdsMap: taskTagIdsMap,
      nowUtcMs: context.currentNowUtcMs,
    );

    // 5. Serialize matched tasks with complete metadata and field projection
    final requestedFields = (arguments['fields'] as List?)
        ?.map((e) => e.toString())
        .toSet();

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final pagedTasks = matchedTasks.skip(offset).take(limit);

    final serialized = pagedTasks.map((Task t) {
      final proj = projectsById[t.projectId];
      final currentTagIds = export.taskTagIds[t.id] ?? [];
      final taskTags = currentTagIds
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

      final fullMap = <String, dynamic>{
        'id': t.id,
        'title': t.title,
        if (t.description.isNotEmpty) 'description': t.description,
        'status': effectiveStatus.name,
        'priority': t.priority.name,
        'projectId': t.projectId,
        'projectName': proj?.name ?? 'Inbox',
        if (taskTags.isNotEmpty) 'tags': taskTags,
        if (currentTagIds.isNotEmpty) 'tagIds': currentTagIds,
        'startDate': ?startStr,
        'dueDate': ?dueStr,
        'isCompleted': isDone,
        'completedDate': ?completedStr,
        'completedAt': ?effectiveCompAt,
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

      if (requestedFields == null || requestedFields.isEmpty) {
        return fullMap;
      }

      // Filter by requested fields (always keep id and title)
      final filtered = <String, dynamic>{'id': t.id, 'title': t.title};
      for (final f in requestedFields) {
        if (fullMap.containsKey(f)) {
          filtered[f] = fullMap[f];
        }
      }
      return filtered;
    }).toList();

    final nextOffset = offset + serialized.length;
    final hasMore = nextOffset < matchedTasks.length;

    return AiToolResult.ok({
      'totalMatched': matchedTasks.length,
      'returnedCount': serialized.length,
      'offset': offset,
      if (hasMore) 'nextCursor': nextOffset.toString(),
      'tasks': serialized,
    });
  }
}
