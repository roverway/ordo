import 'package:intl/intl.dart';
import 'package:ordo/core/db/tables.dart';
import 'package:ordo/core/db/repositories/todo_repository.dart';
import '../../services/ai_task_executor.dart';
import '../ai_tool.dart';
import 'ai_date_parser.dart';

/// Tool for updating an existing task or staging an update proposal.
class UpdateTaskTool extends AiTool {
  const UpdateTaskTool();

  @override
  String get name => 'update_task';

  @override
  String get description =>
      'Updates attributes of an existing task (title, description, status, priority, dueDate, clearDueDate, projectId, tags). '
      'In direct mode, applies changes immediately and returns updated task. In proposal mode, stages proposal to review queue.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'taskId': {
        'type': 'string',
        'description': 'Unique identifier of the task to update (required).',
      },
      'title': {'type': 'string', 'description': 'New title for the task.'},
      'description': {
        'type': 'string',
        'description': 'New detailed description or remarks.',
      },
      'status': {
        'type': 'string',
        'enum': ['todo', 'inProgress', 'done', 'cancelled'],
        'description':
            'New completion status. Note: Tasks with subtasks derive their status automatically.',
      },
      'priority': {
        'type': 'integer',
        'enum': [0, 1, 2, 3],
        'description': 'New priority level: 0=none, 1=low, 2=medium, 3=high.',
      },
      'dueDate': {
        'type': 'string',
        'description':
            'New due/deadline date/time in ISO 8601, "yyyy-MM-dd HH:mm", or relative terms ("tomorrow", "today"). Pass "clear" or "none" to remove.',
      },
      'startDate': {
        'type': 'string',
        'description': 'New start date/time in ISO 8601 or "yyyy-MM-dd HH:mm".',
      },
      'clearDueDate': {
        'type': 'boolean',
        'description': 'Set true to explicitly clear existing due date.',
      },
      'projectId': {
        'type': 'string',
        'description': 'Move task to a different project by project ID.',
      },
      'tags': {
        'type': 'array',
        'items': {'type': 'string'},
        'description':
            'Full replacement list of tag names for this task. Pass empty list [] to clear all tags.',
      },
      'mode': {
        'type': 'string',
        'enum': ['auto', 'direct', 'proposal'],
        'description':
            'Execution mode: "direct" writes immediately, "proposal" stages to queue, "auto" uses server default.',
      },
      'dryRun': {
        'type': 'boolean',
        'description':
            'If true, returns simulated before/after diff without modifying database state.',
      },
      'idempotencyKey': {
        'type': 'string',
        'description': 'Optional client token for deduplication on retries.',
      },
    },
    'required': ['taskId'],
  };

  @override
  Future<AiToolResult> execute(
    Map<String, dynamic> arguments,
    AiToolContext context,
  ) async {
    final taskId = arguments['taskId']?.toString().trim();
    if (taskId == null || taskId.isEmpty) {
      return AiToolResult.failure(
        'taskId is required.',
        code: 'INVALID_ARGUMENT',
      );
    }

    final task = await context.repository.tasks.getActiveById(taskId);
    if (task == null) {
      return AiToolResult.failure(
        'Task with ID "$taskId" not found.',
        code: 'NOT_FOUND',
        hint: 'Use query_tasks to find active task IDs.',
        details: {'taskId': taskId},
      );
    }

    final title = arguments['title']?.toString().trim();
    if (arguments.containsKey('title') && (title == null || title.isEmpty)) {
      return AiToolResult.failure(
        'Task title cannot be empty.',
        code: 'INVALID_ARGUMENT',
        hint: 'Provide a non-empty string when updating title.',
      );
    }

    final description = arguments['description']?.toString().trim();

    TaskStatus? newStatus;
    if (arguments['status'] != null) {
      final statusStr = arguments['status'].toString();
      for (final s in TaskStatus.values) {
        if (s.name == statusStr) {
          newStatus = s;
          break;
        }
      }
      if (newStatus == null) {
        return AiToolResult.failure(
          'Invalid status "$statusStr". Allowed values: ${TaskStatus.values.map((e) => e.name).join(", ")}',
          code: 'INVALID_ARGUMENT',
        );
      }
    }

    TaskPriority? newPriority;
    if (arguments['priority'] != null) {
      final rawP = arguments['priority'];
      if (rawP is num) {
        final pInt = rawP.toInt().clamp(0, 3);
        newPriority = TaskPriority.values[pInt];
      } else if (rawP is String) {
        final parsed = int.tryParse(rawP);
        if (parsed != null) {
          newPriority = TaskPriority.values[parsed.clamp(0, 3)];
        } else {
          for (final p in TaskPriority.values) {
            if (p.name.toLowerCase() == rawP.toLowerCase()) {
              newPriority = p;
              break;
            }
          }
        }
      }
      if (newPriority == null) {
        return AiToolResult.failure(
          'Invalid priority "$rawP". Allowed values: 0, 1, 2, 3 or none, low, medium, high.',
          code: 'INVALID_ARGUMENT',
        );
      }
    }

    final rawProjectId = arguments['projectId']?.toString().trim();
    if (rawProjectId != null && rawProjectId.isNotEmpty) {
      final proj = await context.repository.projects.getById(rawProjectId);
      if (proj == null || proj.deleted != 0) {
        return AiToolResult.failure(
          'Target project "$rawProjectId" does not exist.',
          code: 'PROJECT_NOT_FOUND',
          hint: 'Call get_metadata to see available projects.',
          details: {'projectId': rawProjectId},
        );
      }
    }

    int? newDueAtMs;
    bool clearDueDate = arguments['clearDueDate'] == true;
    final dueDateRaw = arguments['dueDate']?.toString().trim();
    if (dueDateRaw != null) {
      if (dueDateRaw == 'clear' || dueDateRaw == 'none' || dueDateRaw.isEmpty) {
        clearDueDate = true;
      } else {
        try {
          newDueAtMs = AiDateParser.parseToUtcMsStrict(
            dueDateRaw,
            nowUtcMs: context.nowUtcMs,
          );
        } on FormatException catch (e) {
          return AiToolResult.failure(
            e.message,
            code: 'UNPARSEABLE_DATE',
            hint:
                'Provide dates in YYYY-MM-DD, YYYY-MM-DD HH:mm, or ISO-8601 format, or relative terms like "today", "tomorrow".',
            details: {'raw': dueDateRaw, 'field': 'dueDate'},
          );
        }
      }
    }

    int? newStartAtMs;
    final startDateRaw = arguments['startDate']?.toString().trim();
    if (startDateRaw != null && startDateRaw.isNotEmpty) {
      try {
        newStartAtMs = AiDateParser.parseToUtcMsStrict(
          startDateRaw,
          nowUtcMs: context.nowUtcMs,
        );
      } on FormatException catch (e) {
        return AiToolResult.failure(
          e.message,
          code: 'UNPARSEABLE_DATE',
          hint:
              'Provide dates in YYYY-MM-DD, YYYY-MM-DD HH:mm, or ISO-8601 format, or relative terms like "today", "tomorrow".',
          details: {'raw': startDateRaw, 'field': 'startDate'},
        );
      }
    }

    final hasAnyUpdate =
        title != null ||
        description != null ||
        newStatus != null ||
        newPriority != null ||
        clearDueDate ||
        newDueAtMs != null ||
        newStartAtMs != null ||
        (rawProjectId != null && rawProjectId.isNotEmpty) ||
        arguments.containsKey('tags');

    if (!hasAnyUpdate) {
      return AiToolResult.failure(
        'No update fields provided for task "$taskId".',
        code: 'INVALID_ARGUMENT',
        hint:
            'Specify at least one attribute to modify: title, description, status, priority, dueDate, clearDueDate, projectId, or tags.',
      );
    }

    final payload = <String, dynamic>{
      'taskId': task.id,
      'originalTitle': task.title,
      if (title != null && title.isNotEmpty) 'newTitle': title,
      'description': ?description,
      'newStatus': ?newStatus?.name,
      'newPriority': ?newPriority?.index,
      if (clearDueDate) 'clearDueDate': true,
      'newDueDate': ?newDueAtMs,
      'startDate': ?newStartAtMs,
      'projectId': ?rawProjectId,
      if (arguments.containsKey('tags')) 'tags': arguments['tags'],
    };

    final previousValues = <String, dynamic>{
      'title': task.title,
      'status': task.status.name,
      'priority': task.priority.index,
      'priorityLevel': task.priority.name,
      'dueAt': task.endAt,
      'projectId': task.projectId,
    };

    // Preflight dryRun check
    if (arguments['dryRun'] == true) {
      return AiToolResult.ok({
        'ok': true,
        'dryRun': true,
        'taskId': task.id,
        'previousValues': previousValues,
        'simulatedChanges': payload,
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
    final effectiveWriteMode = context.writeMode == 'review'
        ? 'review'
        : (requestedMode == 'proposal' ? 'review' : 'direct');
    final isDirect = effectiveWriteMode == 'direct';

    if (isDirect) {
      try {
        final updatedTask = await AiTaskExecutor.executeUpdateTask(
          repository: context.repository,
          payload: payload,
          nowUtcMs: context.nowUtcMs,
        );

        final updatedFields = <String>[
          if (title != null && title != task.title) 'title',
          if (description != null && description != task.description)
            'description',
          if (newStatus != null && newStatus != task.status) 'status',
          if (newPriority != null && newPriority != task.priority) 'priority',
          if (clearDueDate || (newDueAtMs != null && newDueAtMs != task.endAt))
            'dueDate',
          if (newStartAtMs != null && newStartAtMs != task.startAt) 'startDate',
          if (rawProjectId != null && rawProjectId != task.projectId)
            'projectId',
          if (arguments.containsKey('tags')) 'tags',
        ];

        final resultData = <String, dynamic>{
          'ok': true,
          'status': 'updated',
          'writeMode': 'direct',
          'taskId': updatedTask.id,
          'updatedFields': updatedFields,
          'previousValues': previousValues,
          'currentValues': {
            'title': updatedTask.title,
            'status': updatedTask.status.name,
            'priority': updatedTask.priority.index,
            'priorityLevel': updatedTask.priority.name,
            'startAt': updatedTask.startAt,
            'startDate': updatedTask.startAt != null
                ? DateFormat('yyyy-MM-dd HH:mm').format(
                    DateTime.fromMillisecondsSinceEpoch(
                      updatedTask.startAt!,
                      isUtc: true,
                    ).toLocal(),
                  )
                : null,
            'dueAt': updatedTask.endAt,
            'dueDate': updatedTask.endAt != null
                ? DateFormat('yyyy-MM-dd HH:mm').format(
                    DateTime.fromMillisecondsSinceEpoch(
                      updatedTask.endAt!,
                      isUtc: true,
                    ).toLocal(),
                  )
                : null,
            'projectId': updatedTask.projectId,
          },
          'requiresConfirmation': false,
          'message': 'Task "${updatedTask.title}" updated successfully.',
        };

        if (idempotencyKey != null &&
            idempotencyKey.isNotEmpty &&
            context.proposalRepository != null) {
          await context.proposalRepository!.recordDirectExecution(
            type: 'update',
            idempotencyKey: idempotencyKey,
            result: resultData,
          );
        }

        return AiToolResult.ok(resultData);
      } on RepositoryException catch (e) {
        return AiToolResult.failure(e.message, code: 'REPOSITORY_ERROR');
      } catch (e) {
        return AiToolResult.failure(
          'Failed to update task: $e',
          code: 'EXECUTION_ERROR',
        );
      }
    }

    // Proposal staging mode
    if (context.proposalRepository != null) {
      final proposal = await context.proposalRepository!.createProposal(
        type: 'update',
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
            'Update proposal staged for task "${task.title}". Call confirm_proposals to commit.',
      });
    }

    return AiToolResult.ok({
      'proposal': payload,
      'writeMode': 'review',
      'requiresConfirmation': true,
      'message': 'Task update proposal prepared for user confirmation.',
    });
  }
}
