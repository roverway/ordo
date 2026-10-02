import 'package:intl/intl.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/tables.dart';
import 'package:ordo/core/utils/custom_view_models.dart';
import 'package:ordo/core/utils/derived.dart';
import 'package:ordo/core/utils/task_query_engine.dart';
import 'package:ordo/core/utils/tree.dart';
import '../ai_tool.dart';
import 'ai_date_parser.dart';

/// Read-only tool that queries tasks with multi-dimensional filtering, field projection,
/// and cursor-based pagination.
class QueryTasksTool extends AiTool {
  const QueryTasksTool();

  @override
  bool get isReadOnly => true;

  @override
  bool get isIdempotent => true;

  @override
  String get name => 'query_tasks';

  @override
  String get description =>
      'Query tasks with multi-dimensional filters: date range, completion status, priority, '
      'project, tags, text keywords, or completed timeframe. '
      'Default status filter returns pending tasks (todo & inProgress). Pass statuses: ["all"] to include completed tasks. '
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
            'Scheduled date scope: "overdue" (expired), "today", "tomorrow", "thisWeek", "noDate" (unscheduled), "completedToday", or "all". Default is "all".',
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
          'enum': ['all', 'todo', 'inProgress', 'done', 'cancelled'],
        },
        'description':
            'Filter by status. Default is ["todo", "inProgress"]. Pass ["all"] to view all tasks including completed.',
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
        'description':
            'Keyword search in task title or description/notes. (Alias: keyword)',
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
            'List of fields to include in output for token savings (e.g. ["id", "title", "dueDate", "status"]).',
      },
    },
    'required': [],
  };

  static final Set<String> _allowedKeys = {
    'dateScope',
    'completedScope',
    'completedAfter',
    'completedBefore',
    'statuses',
    'priorities',
    'projectIds',
    'tagIds',
    'searchQuery',
    'limit',
    'cursor',
    'fields',
    'sortBy',
    'sortDirection',
  };

  static final Set<String> _allowedAliases = {
    'keyword',
    'status',
    'priority',
    'projectId',
    'tagId',
  };

  @override
  Future<AiToolResult> execute(
    Map<String, dynamic> arguments,
    AiToolContext context,
  ) async {
    // 1. Validate argument keys against unexpected / misspelled parameters (resolves §5.1)
    for (final key in arguments.keys) {
      if (!_allowedKeys.contains(key) && !_allowedAliases.contains(key)) {
        return AiToolResult.failure(
          'Unknown parameter "$key". Allowed parameters: ${_allowedKeys.join(", ")}',
          code: 'INVALID_ARGUMENT',
          hint: key == 'keyword'
              ? 'Use "searchQuery" for keyword search.'
              : (key == 'status'
                    ? 'Use "statuses" to filter by status.'
                    : null),
        );
      }
    }

    // 2. Export all data
    final export = await context.repository.exportAll();

    // 3. Map dateScope with strict enum validation (resolves §5.2)
    DateScopeEnum dateScope = DateScopeEnum.all;
    if (arguments['dateScope'] != null) {
      final scopeStr = arguments['dateScope'].toString();
      DateScopeEnum? matched;
      for (final val in DateScopeEnum.values) {
        if (val.name == scopeStr) {
          matched = val;
          break;
        }
      }
      if (matched == null) {
        return AiToolResult.failure(
          'Invalid dateScope "$scopeStr". Allowed values: ${DateScopeEnum.values.map((e) => e.name).join(", ")}',
          code: 'INVALID_ARGUMENT',
        );
      }
      dateScope = matched;
    }

    // 4. Map completedScope and completed time range
    CompletedScopeEnum completedScope = CompletedScopeEnum.all;
    if (arguments['completedScope'] != null) {
      final scopeStr = arguments['completedScope'].toString();
      CompletedScopeEnum? matched;
      for (final val in CompletedScopeEnum.values) {
        if (val.name == scopeStr) {
          matched = val;
          break;
        }
      }
      if (matched == null) {
        return AiToolResult.failure(
          'Invalid completedScope "$scopeStr". Allowed values: ${CompletedScopeEnum.values.map((e) => e.name).join(", ")}',
          code: 'INVALID_ARGUMENT',
        );
      }
      completedScope = matched;
    }

    final completedAfterRaw = arguments['completedAfter'];
    final completedBeforeRaw = arguments['completedBefore'];
    final completedAfterUtcMs = AiDateParser.parseToUtcMs(completedAfterRaw);
    final completedBeforeUtcMs = AiDateParser.parseToUtcMs(completedBeforeRaw);

    final searchQuery =
        arguments['searchQuery']?.toString() ??
        arguments['keyword']?.toString();

    // 5. Map statuses with alias support and default pending tasks (resolves §5.3)
    final dynamic rawStatusesInput =
        arguments['statuses'] ??
        (arguments['status'] != null
            ? (arguments['status'] is List
                  ? arguments['status']
                  : [arguments['status']])
            : null);

    final statuses = <TaskStatus>[];
    if (rawStatusesInput != null) {
      if (rawStatusesInput is! List) {
        return AiToolResult.failure(
          'Parameter "statuses" must be an array of strings.',
          code: 'INVALID_ARGUMENT',
        );
      }
      final hasAll = rawStatusesInput.any(
        (item) => item.toString().toLowerCase() == 'all',
      );
      if (!hasAll) {
        for (final item in rawStatusesInput) {
          final str = item.toString();
          TaskStatus? matched;
          for (final val in TaskStatus.values) {
            if (val.name == str) {
              matched = val;
              break;
            }
          }
          if (matched == null) {
            return AiToolResult.failure(
              'Invalid status "$str" in statuses. Allowed values: all, ${TaskStatus.values.map((e) => e.name).join(", ")}',
              code: 'INVALID_ARGUMENT',
            );
          }
          statuses.add(matched);
        }
      }
    } else {
      // When searching specifically for completed scopes or general keyword search across history,
      // allow all statuses. But for dateScope schedule queries (today, tomorrow, overdue) or default queries,
      // default strictly to pending tasks [todo, inProgress] to avoid returning completed tasks.
      final hasCompletedFilter =
          completedScope != CompletedScopeEnum.all ||
          completedAfterUtcMs != null ||
          completedBeforeUtcMs != null;
      final isKeywordOnly =
          searchQuery != null &&
          searchQuery.isNotEmpty &&
          dateScope == DateScopeEnum.all;

      if (!hasCompletedFilter && !isKeywordOnly) {
        statuses.addAll([TaskStatus.todo, TaskStatus.inProgress]);
      }
    }

    // 6. Map priorities with alias support
    final dynamic rawPrioritiesInput =
        arguments['priorities'] ??
        (arguments['priority'] != null
            ? (arguments['priority'] is List
                  ? arguments['priority']
                  : [arguments['priority']])
            : null);

    final priorities = <TaskPriority>[];
    if (rawPrioritiesInput != null) {
      if (rawPrioritiesInput is! List) {
        return AiToolResult.failure(
          'Parameter "priorities" must be an array.',
          code: 'INVALID_ARGUMENT',
        );
      }
      for (final item in rawPrioritiesInput) {
        final str = item.toString().toLowerCase();
        TaskPriority? matched;
        for (final val in TaskPriority.values) {
          if (val.name.toLowerCase() == str) {
            matched = val;
            break;
          }
        }
        if (matched == null) {
          final parsedInt = int.tryParse(str);
          if (parsedInt != null && parsedInt >= 0 && parsedInt <= 3) {
            matched = TaskPriority.values[parsedInt];
          }
        }
        if (matched == null) {
          return AiToolResult.failure(
            'Invalid priority "$item" in priorities. Allowed: none, low, medium, high (or 0-3).',
            code: 'INVALID_ARGUMENT',
          );
        }
        priorities.add(matched);
      }
    }

    final dynamic rawProjectIds =
        arguments['projectIds'] ??
        (arguments['projectId'] != null
            ? (arguments['projectId'] is List
                  ? arguments['projectId']
                  : [arguments['projectId']])
            : null);
    final projectIds =
        (rawProjectIds as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];

    final dynamic rawTagIds =
        arguments['tagIds'] ??
        (arguments['tagId'] != null
            ? (arguments['tagId'] is List
                  ? arguments['tagId']
                  : [arguments['tagId']])
            : null);
    final tagIds =
        (rawTagIds as List?)?.map((e) => e.toString()).toList() ??
        const <String>[];

    final rawLimit = arguments['limit'];
    int limit = 30;
    if (rawLimit != null) {
      if (rawLimit is! num) {
        return AiToolResult.failure(
          'Parameter "limit" must be an integer (1-200).',
          code: 'INVALID_ARGUMENT',
        );
      }
      limit = rawLimit.toInt().clamp(1, 200);
    }

    final offset = int.tryParse(arguments['cursor']?.toString() ?? '') ?? 0;

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

    // 7. Prepare index structures for TaskQueryEngine
    final projectsById = {for (final p in export.projects) p.id: p};
    final taskTagIdsMap = {
      for (final entry in export.taskTagIds.entries)
        entry.key: entry.value.toSet(),
    };
    final tagsById = {for (final t in export.tags) t.id: t};
    final childrenIndex = indexChildrenByParent(export.tasks);

    // 8. Run filterFlat through TaskQueryEngine
    final matchedTasks = TaskQueryEngine.filterFlat(
      tasks: export.tasks,
      criteria: criteria,
      projectsById: projectsById,
      taskTagIdsMap: taskTagIdsMap,
      nowUtcMs: context.currentNowUtcMs,
    );

    // 9. Serialize matched tasks with complete metadata and field projection
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

      final isDone = effectiveStatus == TaskStatus.done;
      final completedSubtasks = directChildren.where((c) {
        final childChildren = childrenIndex[c.id] ?? const <Task>[];
        final st = childChildren.isEmpty
            ? c.status
            : derivedStatus(c, childChildren);
        return st == TaskStatus.done;
      }).length;

      final fullMap = <String, dynamic>{
        'id': t.id,
        'title': t.title,
        'description': t.description,
        'notes': t.description,
        'status': effectiveStatus.name,
        'isCompleted': isDone,
        'priority': t.priority.name,
        'priorityLevel': t.priority.index,
        'projectId': t.projectId,
        'projectName': proj?.name ?? 'Inbox',
        'tags': taskTags,
        'tagIds': currentTagIds,
        'startAt': t.startAt,
        'startDate': t.startAt != null
            ? dateFormat.format(
                DateTime.fromMillisecondsSinceEpoch(
                  t.startAt!,
                  isUtc: true,
                ).toLocal(),
              )
            : null,
        'dueAt': t.endAt,
        'dueDate': t.endAt != null
            ? dateFormat.format(
                DateTime.fromMillisecondsSinceEpoch(
                  t.endAt!,
                  isUtc: true,
                ).toLocal(),
              )
            : null,
        'completedAt': effectiveCompAt,
        'completedDate': effectiveCompAt != null
            ? dateFormat.format(
                DateTime.fromMillisecondsSinceEpoch(
                  effectiveCompAt,
                  isUtc: true,
                ).toLocal(),
              )
            : null,
        'createdAt': t.createdAt,
        'createdDate': dateFormat.format(
          DateTime.fromMillisecondsSinceEpoch(
            t.createdAt,
            isUtc: true,
          ).toLocal(),
        ),
        'updatedAt': t.updatedAt,
        'sortOrder': t.sortOrder,
        if (directChildren.isNotEmpty) ...{
          'subtaskCount': directChildren.length,
          'completedSubtaskCount': completedSubtasks,
        },
      };

      if (requestedFields == null || requestedFields.isEmpty) {
        return fullMap;
      }

      final filtered = <String, dynamic>{};
      for (final f in requestedFields) {
        if (fullMap.containsKey(f)) {
          filtered[f] = fullMap[f];
        }
      }
      filtered['id'] = t.id;
      return filtered;
    }).toList();

    final nextOffset = offset + serialized.length;
    final hasMore = nextOffset < matchedTasks.length;

    return AiToolResult.ok({
      'totalMatched': matchedTasks.length,
      'returnedCount': serialized.length,
      'limit': limit,
      'hasMore': hasMore,
      if (hasMore) 'nextCursor': nextOffset.toString(),
      'tasks': serialized,
    });
  }
}
