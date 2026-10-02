import 'package:ordo/core/db/repositories/todo_repository.dart';
import '../../services/ai_task_executor.dart';
import '../ai_tool.dart';
import 'ai_date_parser.dart';

/// Tool for creating tasks or staging task proposals.
/// Supports both Direct Write (automated) and Proposal Queue (human-in-the-loop).
class CreateTasksTool extends AiTool {
  const CreateTasksTool();

  @override
  String get name => 'create_tasks';

  @override
  String get description =>
      'Creates a new task or stages a task proposal with optional subtasks, tags, dates, priority, '
      'and target project. In direct mode, executes immediately and returns taskId. In proposal mode, '
      'stages to the review queue and returns proposalId.';

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
      'mode': {
        'type': 'string',
        'enum': ['auto', 'direct', 'proposal'],
        'description':
            'Execution mode: "direct" writes to DB immediately, "proposal" stages to review queue, "auto" uses server default.',
      },
      'idempotencyKey': {
        'type': 'string',
        'description':
            'Optional client token to prevent duplicate task creations on retries.',
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
      return AiToolResult.failure(
        'Task title cannot be empty.',
        code: 'INVALID_ARGUMENT',
        hint: 'Provide a non-empty string for "title"',
      );
    }

    final description = arguments['description']?.toString().trim();
    final rawPriority = (arguments['priority'] as num?)?.toInt() ?? 0;
    final priority = rawPriority.clamp(0, 3);

    final startAt = AiDateParser.parseToUtcMs(arguments['startDate']);
    final dueAt = AiDateParser.parseToUtcMs(arguments['dueDate']);

    final rawProjectId = arguments['projectId']?.toString().trim();
    if (rawProjectId != null && rawProjectId.isNotEmpty) {
      final project = await context.repository.projects.getById(rawProjectId);
      if (project == null || project.deleted != 0) {
        return AiToolResult.failure(
          'Project with ID "$rawProjectId" does not exist.',
          code: 'PROJECT_NOT_FOUND',
          hint: 'Call get_metadata to list valid projects.',
          details: {'projectId': rawProjectId},
        );
      }
    }

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

    final payload = <String, dynamic>{
      'title': title,
      if (description != null && description.isNotEmpty)
        'description': description,
      'priority': priority,
      'startAt': startAt,
      'dueAt': dueAt,
      if (rawProjectId != null && rawProjectId.isNotEmpty)
        'projectId': rawProjectId,
      'tags': tags,
      'substeps': substeps,
    };

    final requestedMode = arguments['mode']?.toString().trim();
    final isDirect =
        requestedMode == 'direct' ||
        (requestedMode != 'proposal' && context.writeMode == 'direct');

    if (isDirect) {
      try {
        final task = await AiTaskExecutor.executeCreateTask(
          repository: context.repository,
          payload: payload,
          nowUtcMs: context.nowUtcMs,
          locale: context.locale,
        );

        return AiToolResult.ok({
          'ok': true,
          'status': 'created',
          'taskId': task.id,
          'task': {
            'id': task.id,
            'title': task.title,
            'projectId': task.projectId,
            'priority': task.priority.index,
            'status': task.status.name,
            'startAt': task.startAt,
            'dueAt': task.endAt,
            'createdAt': task.createdAt,
          },
          'requiresConfirmation': false,
          'message': 'Task "${task.title}" created successfully.',
        });
      } on RepositoryException catch (e) {
        return AiToolResult.failure(e.message, code: 'REPOSITORY_ERROR');
      } catch (e) {
        return AiToolResult.failure(
          'Failed to create task: $e',
          code: 'EXECUTION_ERROR',
        );
      }
    }

    // Proposal staging mode
    final idempotencyKey = arguments['idempotencyKey']?.toString().trim();
    if (context.proposalRepository != null) {
      final proposal = await context.proposalRepository!.createProposal(
        type: 'create',
        payload: payload,
        idempotencyKey: idempotencyKey,
      );

      return AiToolResult.ok({
        'ok': true,
        'status': 'pending',
        'proposalId': proposal.id,
        'proposal': payload,
        'staged': proposal.toJson(),
        'requiresConfirmation': true,
        'message':
            'Task proposal staged. Call confirm_proposals to commit or reject_proposals to discard.',
      });
    }

    // Fallback in-memory proposal for in-app copilot without proposalRepository
    return AiToolResult.ok({
      'proposal': payload,
      'requiresConfirmation': true,
      'message': 'Task proposal prepared for user confirmation.',
    });
  }
}
