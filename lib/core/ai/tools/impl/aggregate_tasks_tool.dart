import 'package:drift/drift.dart';
import 'package:ordo/core/db/tables.dart';
import '../ai_tool.dart';

/// Tool for aggregated statistical queries on tasks (reducing LLM token consumption).
class AggregateTasksTool extends AiTool {
  const AggregateTasksTool();

  @override
  String get name => 'aggregate_tasks';

  @override
  String get description =>
      'Returns aggregated task counts grouped by status, priority, project, or tag. '
      'Drastically saves tokens when summarizing workload or generating reports.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'groupBy': {
        'type': 'string',
        'enum': ['status', 'priority', 'project', 'tag'],
        'description': 'Dimension to aggregate by (required).',
      },
      'projectId': {
        'type': 'string',
        'description': 'Optional project ID filter.',
      },
      'status': {
        'type': 'string',
        'enum': ['todo', 'inProgress', 'done', 'cancelled'],
        'description': 'Optional status filter.',
      },
    },
    'required': ['groupBy'],
  };

  @override
  Future<AiToolResult> execute(
    Map<String, dynamic> arguments,
    AiToolContext context,
  ) async {
    final groupBy = arguments['groupBy']?.toString().trim();
    if (groupBy == null || groupBy.isEmpty) {
      return AiToolResult.failure(
        'groupBy parameter is required.',
        code: 'INVALID_ARGUMENT',
      );
    }

    final db = context.repository.db;
    final projectId = arguments['projectId']?.toString().trim();
    final status = arguments['status']?.toString().trim();

    final whereClauses = <String>['t.deleted = 0'];
    final variables = <Variable>[];

    if (projectId != null && projectId.isNotEmpty) {
      whereClauses.add('t.project_id = ?');
      variables.add(Variable.withString(projectId));
    }

    if (status != null && status.isNotEmpty) {
      whereClauses.add('t.status = ?');
      variables.add(Variable.withString(status));
    }

    final whereSql = whereClauses.join(' AND ');

    // 1. Total count
    final totalRow = await db
        .customSelect(
          'SELECT COUNT(*) as total FROM tasks t WHERE $whereSql',
          variables: variables,
        )
        .getSingle();
    final total = totalRow.read<int>('total');

    // 2. Buckets by groupBy dimension
    final buckets = <Map<String, dynamic>>[];

    if (groupBy == 'status') {
      final rows = await db
          .customSelect(
            'SELECT t.status, COUNT(*) as count FROM tasks t WHERE $whereSql GROUP BY t.status',
            variables: variables,
          )
          .get();

      for (final r in rows) {
        final st = r.read<String>('status');
        buckets.add({'key': st, 'count': r.read<int>('count')});
      }
    } else if (groupBy == 'priority') {
      final rows = await db
          .customSelect(
            'SELECT t.priority, COUNT(*) as count FROM tasks t WHERE $whereSql GROUP BY t.priority ORDER BY t.priority DESC',
            variables: variables,
          )
          .get();

      for (final r in rows) {
        final p = r.read<int>('priority');
        final priorityName = p >= 0 && p < TaskPriority.values.length
            ? TaskPriority.values[p].name
            : 'unknown';
        buckets.add({
          'key': priorityName,
          'priority': p,
          'count': r.read<int>('count'),
        });
      }
    } else if (groupBy == 'project') {
      final rows = await db.customSelect('''
        SELECT t.project_id, p.name as project_name, COUNT(*) as count
        FROM tasks t
        LEFT JOIN projects p ON t.project_id = p.id
        WHERE $whereSql
        GROUP BY t.project_id
        ''', variables: variables).get();

      for (final r in rows) {
        final pid = r.read<String>('project_id');
        final pName =
            r.readNullable<String>('project_name') ??
            (pid == 'inbox' ? 'Inbox' : pid);
        buckets.add({
          'key': pid,
          'projectName': pName,
          'count': r.read<int>('count'),
        });
      }
    } else if (groupBy == 'tag') {
      final rows = await db.customSelect('''
        SELECT tt.tag_id, tg.name as tag_name, COUNT(*) as count
        FROM task_tags tt
        JOIN tasks t ON tt.task_id = t.id
        LEFT JOIN tags tg ON tt.tag_id = tg.id
        WHERE $whereSql
        GROUP BY tt.tag_id
        ''', variables: variables).get();

      for (final r in rows) {
        final tid = r.read<String>('tag_id');
        final tName = r.readNullable<String>('tag_name') ?? tid;
        buckets.add({
          'key': tid,
          'tagName': tName,
          'count': r.read<int>('count'),
        });
      }
    } else {
      return AiToolResult.failure(
        'Unsupported groupBy dimension "$groupBy". Use "status", "priority", "project", or "tag".',
        code: 'INVALID_ARGUMENT',
      );
    }

    return AiToolResult.ok({
      'total': total,
      'groupBy': groupBy,
      'buckets': buckets,
    });
  }
}
