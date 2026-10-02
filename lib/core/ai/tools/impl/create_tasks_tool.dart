import 'package:intl/intl.dart';
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
            'Starting date/time in ISO 8601 format (e.g. "2026-09-30T09:00:00"), "yyyy-MM-dd HH:mm", or relative terms like "today", "tomorrow".',
      },
      'dueDate': {
        'type': 'string',
        'description':
            'Due/deadline date/time in ISO 8601 format, "yyyy-MM-dd HH:mm", or relative terms like "today", "tomorrow", "in 3 days".',
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
            'Execution mode: "direct" writes to DB immediately (subject to server permission), "proposal" stages to review queue, "auto" uses server default.',
      },
      'dryRun': {
        'type': 'boolean',
        'description':
            'If true, validates task parameters and returns a preview without modifying database state.',
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
    final rawPriority = arguments['priority'];
    int priority = 0;
    if (rawPriority != null) {
      if (rawPriority is num) {
        priority = rawPriority.toInt().clamp(0, 3);
      } else if (rawPriority is String) {
        final p = int.tryParse(rawPriority);
        if (p != null) {
          priority = p.clamp(0, 3);
        } else {
          switch (rawPriority.toLowerCase()) {
            case 'high':
              priority = 3;
              break;
            case 'medium':
              priority = 2;
              break;
            case 'low':
              priority = 1;
              break;
            default:
              priority = 0;
          }
        }
      }
    }

    int? startAt;
    if (arguments.containsKey('startDate') && arguments['startDate'] != null) {
      try {
        startAt = AiDateParser.parseToUtcMsStrict(
          arguments['startDate'],
          nowUtcMs: context.nowUtcMs,
        );
      } on FormatException catch (e) {
        return AiToolResult.failure(
          e.message,
          code: 'UNPARSEABLE_DATE',
          hint:
              'Provide dates in YYYY-MM-DD, YYYY-MM-DD HH:mm, or ISO-8601 format, or relative terms like "today", "tomorrow".',
          details: {'raw': arguments['startDate'], 'field': 'startDate'},
        );
      }
    }

    int? dueAt;
    if (arguments.containsKey('dueDate') && arguments['dueDate'] != null) {
      try {
        dueAt = AiDateParser.parseToUtcMsStrict(
          arguments['dueDate'],
          nowUtcMs: context.nowUtcMs,
        );
      } on FormatException catch (e) {
        return AiToolResult.failure(
          e.message,
          code: 'UNPARSEABLE_DATE',
          hint:
              'Provide dates in YYYY-MM-DD, YYYY-MM-DD HH:mm, or ISO-8601 format, or relative terms like "today", "tomorrow".',
          details: {'raw': arguments['dueDate'], 'field': 'dueDate'},
        );
      }
    }

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

    // Preflight dryRun check
    if (arguments['dryRun'] == true) {
      return AiToolResult.ok({
        'ok': true,
        'dryRun': true,
        'valid': true,
        'preview': payload,
      });
    }

    // Check idempotency preflight
    final idempotencyKey = arguments['idempotencyKey']?.toString().trim();
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      if (context.proposalRepository != null) {
        final existing = await context.proposalRepository!
            .getExecutionByIdempotencyKey(idempotencyKey);
        if (existing != null) {
          final replay = Map<String, dynamic>.from(existing);
          replay['idempotentReplay'] = true;
          return AiToolResult.ok(replay);
        }
      }
    }

    final requestedMode = arguments['mode']?.toString().trim();
    // Server-enforced write security ceiling:
    // If server policy is 'review', direct write is strictly prohibited regardless of client argument.
    final effectiveWriteMode = context.writeMode == 'review'
        ? 'review'
        : (requestedMode == 'proposal' ? 'review' : 'direct');
    final isDirect = effectiveWriteMode == 'direct';

    if (isDirect) {
      try {
        final task = await AiTaskExecutor.executeCreateTask(
          repository: context.repository,
          payload: payload,
          nowUtcMs: context.nowUtcMs,
          locale: context.locale,
        );

        final resultData = <String, dynamic>{
          'ok': true,
          'status': 'created',
          'writeMode': 'direct',
          'taskId': task.id,
          'task': {
            'id': task.id,
            'title': task.title,
            'projectId': task.projectId,
            'priority': task.priority.index,
            'priorityLevel': task.priority.name,
            'status': task.status.name,
            'startAt': task.startAt,
            'startDate': task.startAt != null
                ? DateFormat('yyyy-MM-dd HH:mm').format(
                    DateTime.fromMillisecondsSinceEpoch(
                      task.startAt!,
                      isUtc: true,
                    ).toLocal(),
                  )
                : null,
            'dueAt': task.endAt,
            'dueDate': task.endAt != null
                ? DateFormat('yyyy-MM-dd HH:mm').format(
                    DateTime.fromMillisecondsSinceEpoch(
                      task.endAt!,
                      isUtc: true,
                    ).toLocal(),
                  )
                : null,
            'createdAt': task.createdAt,
          },
          'requiresConfirmation': false,
          'message': 'Task "${task.title}" created successfully.',
        };

        if (idempotencyKey != null &&
            idempotencyKey.isNotEmpty &&
            context.proposalRepository != null) {
          await context.proposalRepository!.recordDirectExecution(
            type: 'create',
            idempotencyKey: idempotencyKey,
            result: resultData,
          );
        }

        return AiToolResult.ok(resultData);
      } on RepositoryException catch (e) {
        return AiToolResult.failure(e.message, code: 'REPOSITORY_ERROR');
      } catch (e) {
        return AiToolResult.failure(
          'Failed to create task: $e',
          code: 'EXECUTION_ERROR',
        );
      }
    }

    // Proposal staging mode (enforced by server or requested by client)
    if (context.proposalRepository != null) {
      final proposal = await context.proposalRepository!.createProposal(
        type: 'create',
        payload: payload,
        idempotencyKey: idempotencyKey,
      );

      return AiToolResult.ok({
        'ok': true,
        'status': 'pending',
        'writeMode': 'review',
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
      'writeMode': 'review',
      'requiresConfirmation': true,
      'message': 'Task proposal prepared for user confirmation.',
    });
  }
}
