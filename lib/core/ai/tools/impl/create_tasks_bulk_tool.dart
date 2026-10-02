import 'package:ordo/core/db/repositories/todo_repository.dart';
import '../../services/ai_task_executor.dart';
import '../ai_tool.dart';

/// Tool for bulk creating tasks with validation preflight (dryRun) support.
class CreateTasksBulkTool extends AiTool {
  const CreateTasksBulkTool();

  @override
  String get name => 'create_tasks_bulk';

  @override
  String get description =>
      'Creates multiple tasks in a single call (max 100). Supports "dryRun": true for preflight validation '
      'without modifying state. Non-atomic per-item execution reporting individual success/failure.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'tasks': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'title': {
              'type': 'string',
              'description': 'Task title (required).',
            },
            'description': {
              'type': 'string',
              'description': 'Task description/notes.',
            },
            'priority': {
              'type': 'integer',
              'enum': [0, 1, 2, 3],
            },
            'startDate': {
              'type': 'string',
              'description': 'ISO 8601 start date.',
            },
            'dueDate': {'type': 'string', 'description': 'ISO 8601 due date.'},
            'projectId': {
              'type': 'string',
              'description': 'Target project ID.',
            },
            'tags': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Tag names.',
            },
            'substeps': {
              'type': 'array',
              'items': {'type': 'string'},
              'description': 'Subtask titles.',
            },
          },
          'required': ['title'],
        },
        'description': 'Array of task definitions to create (max 100).',
      },
      'dryRun': {
        'type': 'boolean',
        'description':
            'If true, validates all items and returns schema/relation check results without creating anything.',
      },
      'mode': {
        'type': 'string',
        'enum': ['auto', 'direct', 'proposal'],
        'description':
            'Execution mode: "direct" commits immediately, "proposal" stages to review queue.',
      },
      'idempotencyKey': {
        'type': 'string',
        'description': 'Optional client token for deduplication.',
      },
    },
    'required': ['tasks'],
  };

  @override
  Future<AiToolResult> execute(
    Map<String, dynamic> arguments,
    AiToolContext context,
  ) async {
    final rawTasks = arguments['tasks'];
    if (rawTasks is! List || rawTasks.isEmpty) {
      return AiToolResult.failure(
        '"tasks" must be a non-empty array of task objects.',
        code: 'INVALID_ARGUMENT',
      );
    }

    if (rawTasks.length > 100) {
      return AiToolResult.failure(
        'Batch limit exceeded: maximum 100 tasks allowed per call.',
        code: 'BATCH_LIMIT_EXCEEDED',
        details: {'count': rawTasks.length, 'limit': 100},
      );
    }

    final isDryRun = arguments['dryRun'] == true;
    final requestedMode = arguments['mode']?.toString().trim();
    final isDirect =
        requestedMode == 'direct' ||
        (requestedMode != 'proposal' && context.writeMode == 'direct');

    // 1. Dry Run / Preflight validation mode
    if (isDryRun) {
      final validationResults = <Map<String, dynamic>>[];
      var validCount = 0;
      var invalidCount = 0;

      for (var i = 0; i < rawTasks.length; i++) {
        final item = rawTasks[i];
        if (item is! Map<String, dynamic>) {
          invalidCount++;
          validationResults.add({
            'index': i,
            'valid': false,
            'error': 'Item must be an object.',
          });
          continue;
        }

        final title = item['title']?.toString().trim();
        if (title == null || title.isEmpty) {
          invalidCount++;
          validationResults.add({
            'index': i,
            'valid': false,
            'error': 'Title is required.',
          });
          continue;
        }

        final pid = item['projectId']?.toString().trim();
        if (pid != null && pid.isNotEmpty) {
          final project = await context.repository.projects.getById(pid);
          if (project == null || project.deleted != 0) {
            invalidCount++;
            validationResults.add({
              'index': i,
              'valid': false,
              'error': 'Project "$pid" does not exist.',
            });
            continue;
          }
        }

        validCount++;
        validationResults.add({
          'index': i,
          'valid': true,
          'preview': {'title': title, 'projectId': pid ?? 'inbox'},
        });
      }

      return AiToolResult.ok({
        'dryRun': true,
        'summary': {
          'total': rawTasks.length,
          'valid': validCount,
          'invalid': invalidCount,
        },
        'results': validationResults,
      });
    }

    // 2. Direct Write Mode
    if (isDirect) {
      final results = <Map<String, dynamic>>[];
      var succeeded = 0;
      var failed = 0;

      for (var i = 0; i < rawTasks.length; i++) {
        final item = rawTasks[i];
        if (item is! Map<String, dynamic>) {
          failed++;
          results.add({
            'index': i,
            'ok': false,
            'error': 'Item must be a JSON object.',
          });
          continue;
        }

        try {
          final task = await AiTaskExecutor.executeCreateTask(
            repository: context.repository,
            payload: item,
            nowUtcMs: context.nowUtcMs,
            locale: context.locale,
          );

          succeeded++;
          results.add({
            'index': i,
            'ok': true,
            'taskId': task.id,
            'title': task.title,
            'projectId': task.projectId,
          });
        } on RepositoryException catch (e) {
          failed++;
          results.add({'index': i, 'ok': false, 'error': e.message});
        } catch (e) {
          failed++;
          results.add({'index': i, 'ok': false, 'error': e.toString()});
        }
      }

      return AiToolResult.ok({
        'dryRun': false,
        'summary': {
          'total': rawTasks.length,
          'succeeded': succeeded,
          'failed': failed,
        },
        'results': results,
      });
    }

    // 3. Proposal Mode
    final idempotencyKey = arguments['idempotencyKey']?.toString().trim();
    if (context.proposalRepository != null) {
      final proposal = await context.proposalRepository!.createProposal(
        type: 'bulk_create',
        payload: {'tasks': rawTasks},
        idempotencyKey: idempotencyKey,
      );

      return AiToolResult.ok({
        'ok': true,
        'status': 'pending',
        'proposalId': proposal.id,
        'proposal': {'tasks': rawTasks},
        'staged': proposal.toJson(),
        'requiresConfirmation': true,
        'message':
            'Bulk creation proposal staged (${rawTasks.length} tasks). Call confirm_proposals to execute.',
      });
    }

    return AiToolResult.ok({
      'proposal': {'tasks': rawTasks},
      'requiresConfirmation': true,
      'message': 'Bulk creation proposal prepared for user confirmation.',
    });
  }
}
