import 'package:ordo/core/db/repositories/todo_repository.dart';
import 'package:ordo/core/db/tables.dart';
import '../../services/ai_task_executor.dart';
import '../ai_tool.dart';
import 'ai_date_parser.dart';

/// Tool for updating existing tasks or staging update proposals.
/// Supports both Direct Write (automated) and Proposal Queue (human-in-the-loop).
class UpdateTaskTool extends AiTool {
  const UpdateTaskTool();

  @override
  String get name => 'update_task';

  @override
  String get description =>
      'Updates an existing task\'s status, priority, title, description, project, tags, or dates. '
      'In direct mode, executes immediately. In proposal mode, stages to review queue.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'taskId': {
        'type': 'string',
        'description': 'Unique identifier of the task to update.',
      },
      'title': {'type': 'string', 'description': 'New task title if renaming.'},
      'description': {
        'type': 'string',
        'description': 'New task description/notes.',
      },
      'status': {
        'type': 'string',
        'enum': ['todo', 'inProgress', 'done', 'cancelled'],
        'description': 'New status.',
      },
      'priority': {
        'type': 'integer',
        'enum': [0, 1, 2, 3],
        'description': 'New priority level: 0=none, 1=low, 2=medium, 3=high.',
      },
      'startDate': {
        'type': 'string',
        'description':
            'New start date in ISO 8601 format, or "clear" to remove.',
      },
      'dueDate': {
        'type': 'string',
        'description':
            'New due date in ISO 8601 format or "yyyy-MM-dd HH:mm", or "clear" to remove due date.',
      },
      'projectId': {
        'type': 'string',
        'description':
            'Target project ID if moving this task to another project.',
      },
      'tags': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'List of tag names to replace current tags.',
      },
      'mode': {
        'type': 'string',
        'enum': ['auto', 'direct', 'proposal'],
        'description':
            'Execution mode: "direct" writes to DB immediately, "proposal" stages to review queue, "auto" uses server default.',
      },
      'idempotencyKey': {
        'type': 'string',
        'description': 'Optional client token for deduplication.',
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
        hint: 'Provide "taskId" of the target task.',
      );
    }

    final task = await context.repository.tasks.getActiveById(taskId);
    if (task == null) {
      return AiToolResult.failure(
        'Task with ID "$taskId" not found.',
        code: 'NOT_FOUND',
        hint: 'Call query_tasks to find active task IDs.',
        details: {'taskId': taskId},
      );
    }

    final rawProjectId = arguments['projectId']?.toString().trim();
    if (rawProjectId != null && rawProjectId.isNotEmpty) {
      final project = await context.repository.projects.getById(rawProjectId);
      if (project == null || project.deleted != 0) {
        return AiToolResult.failure(
          'Target project "$rawProjectId" does not exist.',
          code: 'PROJECT_NOT_FOUND',
          hint: 'Call get_metadata to list valid projects.',
          details: {'projectId': rawProjectId},
        );
      }
    }

    final title = arguments['title']?.toString().trim();
    final description = arguments['description']?.toString().trim();
    final statusStr = arguments['status']?.toString().trim();
    final priority = (arguments['priority'] as num?)?.toInt();
    final dueDateRaw = arguments['dueDate']?.toString().trim();
    final startDateRaw = arguments['startDate']?.toString().trim();

    TaskStatus? newStatus;
    if (statusStr != null) {
      for (final s in TaskStatus.values) {
        if (s.name == statusStr) {
          newStatus = s;
          break;
        }
      }
    }

    TaskPriority? newPriority;
    if (priority != null &&
        priority >= 0 &&
        priority < TaskPriority.values.length) {
      newPriority = TaskPriority.values[priority];
    }

    int? newDueAtMs;
    bool clearDueDate = false;
    if (dueDateRaw != null) {
      if (dueDateRaw == 'clear' || dueDateRaw == 'none' || dueDateRaw.isEmpty) {
        clearDueDate = true;
      } else {
        newDueAtMs = AiDateParser.parseToUtcMs(dueDateRaw);
      }
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
      'startDate': ?startDateRaw,
      'projectId': ?rawProjectId,
      if (arguments.containsKey('tags')) 'tags': arguments['tags'],
    };

    final requestedMode = arguments['mode']?.toString().trim();
    final isDirect =
        requestedMode == 'direct' ||
        (requestedMode != 'proposal' && context.writeMode == 'direct');

    if (isDirect) {
      try {
        final updatedTask = await AiTaskExecutor.executeUpdateTask(
          repository: context.repository,
          payload: payload,
          nowUtcMs: context.nowUtcMs,
        );

        return AiToolResult.ok({
          'ok': true,
          'status': 'updated',
          'taskId': updatedTask.id,
          'task': {
            'id': updatedTask.id,
            'title': updatedTask.title,
            'status': updatedTask.status.name,
            'priority': updatedTask.priority.index,
            'projectId': updatedTask.projectId,
            'startAt': updatedTask.startAt,
            'dueAt': updatedTask.endAt,
          },
          'requiresConfirmation': false,
          'message': 'Task "${updatedTask.title}" updated successfully.',
        });
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
    final idempotencyKey = arguments['idempotencyKey']?.toString().trim();
    if (context.proposalRepository != null) {
      final proposal = await context.proposalRepository!.createProposal(
        type: 'update',
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
            'Task update proposal staged. Call confirm_proposals to commit or reject_proposals to discard.',
      });
    }

    return AiToolResult.ok({
      'proposal': payload,
      'requiresConfirmation': true,
      'message': 'Task modification proposal prepared for user confirmation.',
    });
  }
}
