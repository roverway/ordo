import 'package:intl/intl.dart';
import '../ai_tool.dart';

/// Tool for proposing creation of a task with optional subtasks, tags, dates, and priorities.
/// Generates a structured proposal for user confirmation (Human-in-the-loop).
class CreateTasksTool extends AiTool {
  const CreateTasksTool();

  @override
  String get name => 'create_tasks';

  @override
  String get description =>
      'Proposes creating one or more tasks/subtasks with properties like title, priority, due date, '
      'tags, and breakdown steps. Call this whenever the user wants to add, schedule, or break down a task.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'title': {
        'type': 'string',
        'description': 'Main task title (required, concise and actionable).',
      },
      'description': {
        'type': 'string',
        'description': 'Detailed remarks, notes or context.',
      },
      'priority': {
        'type': 'integer',
        'enum': [0, 1, 2, 3],
        'description':
            'Priority level: 0=none, 1=low, 2=medium, 3=high (Eisenhower quadrant).',
      },
      'startDate': {
        'type': 'string',
        'description':
            'Starting date/time in ISO 8601 format (e.g. "2026-09-30T09:00:00") or "yyyy-MM-dd HH:mm".',
      },
      'dueDate': {
        'type': 'string',
        'description':
            'Due/deadline date/time in ISO 8601 format or "yyyy-MM-dd HH:mm".',
      },
      'projectId': {
        'type': 'string',
        'description': 'Target project ID if specified, or omit for inbox.',
      },
      'tags': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'List of tag names.',
      },
      'substeps': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'List of breakdown subtask titles in sequential order.',
      },
    },
    'required': ['title'],
  };

  @override
  Future<AiToolResult> execute(
    Map<String, dynamic> arguments,
    AiToolContext context,
  ) async {
    final title = arguments['title']?.toString().trim();
    if (title == null || title.isEmpty) {
      return AiToolResult.failure('Task title cannot be empty.');
    }

    final description = arguments['description']?.toString().trim();
    final priority = (arguments['priority'] as num?)?.toInt() ?? 0;

    int? parseDateToUtcMs(dynamic raw) {
      if (raw == null) return null;
      final str = raw.toString().trim();
      if (str.isEmpty) return null;
      try {
        final parsed = DateTime.tryParse(str);
        if (parsed != null) return parsed.toUtc().millisecondsSinceEpoch;
      } catch (_) {}
      try {
        final parsed = DateFormat('yyyy-MM-dd HH:mm').parse(str);
        return parsed.toUtc().millisecondsSinceEpoch;
      } catch (_) {}
      return null;
    }

    final startAt = parseDateToUtcMs(arguments['startDate']);
    final dueAt = parseDateToUtcMs(arguments['dueDate']);

    final tags =
        (arguments['tags'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];

    final rawSubsteps =
        (arguments['substeps'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];

    final substeps = List.generate(
      rawSubsteps.length,
      (i) => {'title': rawSubsteps[i], 'sortOrder': i},
    );

    return AiToolResult.ok({
      'proposal': {
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        'priority': priority,
        'startAt': ?startAt,
        'dueAt': ?dueAt,
        'tags': tags,
        'substeps': substeps,
      },
      'requiresConfirmation': true,
      'message': 'Task proposal prepared for user confirmation.',
    });
  }
}
