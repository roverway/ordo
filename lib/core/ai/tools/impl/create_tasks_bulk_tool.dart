import 'package:intl/intl.dart';
import '../../services/ai_task_executor.dart';
import '../ai_tool.dart';
import 'ai_date_parser.dart';

/// Tool for creating multiple tasks in a single operation.
/// Supports up to 100 tasks per batch with preflight validation (dryRun).
class CreateTasksBulkTool extends AiTool {
  const CreateTasksBulkTool();

  @override
  String get name => 'create_tasks_bulk';

  @override
  String get description =>
      'Creates multiple tasks in a single call (up to 100 items). Supports preflight validation via dryRun: true. '
      'Non-atomic: individual item failures are reported in the response without failing valid tasks.';

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
            'description': {'type': 'string'},
            'priority': {
              'type': 'integer',
              'enum': [0, 1, 2, 3],
            },
            'startDate': {'type': 'string'},
            'dueDate': {'type': 'string'},
            'projectId': {'type': 'string'},
            'tags': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'substeps': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
          'required': ['title'],
        },
        'description': 'List of task objects to create (maximum 100).',
      },
      'dryRun': {
        'type': 'boolean',
        'description':
            'If true, validates all items and dates without executing any writes.',
      },
      'mode': {
        'type': 'string',
        'enum': ['auto', 'direct', 'proposal'],
        'description':
            'Execution mode: "direct" writes immediately, "proposal" stages to queue, "auto" uses server default.',
      },
      'idempotencyKey': {
        'type': 'string',
        'description': 'Optional client token for batch deduplication.',
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
        'The "tasks" argument must be a non-empty list of task objects.',
        code: 'INVALID_ARGUMENT',
      );
    }

    if (rawTasks.length > 100) {
      return AiToolResult.failure(
        'Batch limit exceeded: maximum 100 tasks allowed per call, but received ${rawTasks.length}.',
        code: 'BATCH_LIMIT_EXCEEDED',
        hint: 'Split large batches into chunks of 100 items or fewer.',
        details: {'count': rawTasks.length, 'limit': 100},
      );
    }

    final isDryRun = arguments['dryRun'] == true;
    final requestedMode = arguments['mode']?.toString().trim();
    // Server-enforced write security ceiling:
    final effectiveWriteMode = context.writeMode == 'review'
        ? 'review'
        : (requestedMode == 'proposal' ? 'review' : 'direct');
    final isDirect = effectiveWriteMode == 'direct';

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

        // Strict date validation in dryRun (resolves §5.5)
        String? dateError;
        if (item.containsKey('dueDate') && item['dueDate'] != null) {
          try {
            AiDateParser.parseToUtcMsStrict(
              item['dueDate'],
              nowUtcMs: context.nowUtcMs,
            );
          } on FormatException catch (e) {
            dateError = 'dueDate: ${e.message}';
          }
        }
        if (dateError == null &&
            item.containsKey('startDate') &&
            item['startDate'] != null) {
          try {
            AiDateParser.parseToUtcMsStrict(
              item['startDate'],
              nowUtcMs: context.nowUtcMs,
            );
          } on FormatException catch (e) {
            dateError = 'startDate: ${e.message}';
          }
        }
        if (dateError != null) {
          invalidCount++;
          validationResults.add({
            'index': i,
            'valid': false,
            'error': dateError,
          });
          continue;
        }

        validCount++;
        validationResults.add({
          'index': i,
          'valid': true,
          'preview': {'title': title, 'projectId': pid ?? 'inbox'},
        });
      }

      return AiToolResult.ok({
        'ok': true,
        'dryRun': true,
        'writeMode': effectiveWriteMode,
        'summary': {
          'total': rawTasks.length,
          'valid': validCount,
          'invalid': invalidCount,
        },
        'validations': validationResults,
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

    // 2. Direct write mode (executed if permitted by server policy)
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
            'error': 'Item at index $i is not an object.',
          });
          continue;
        }

        try {
          int? dueAt;
          if (item['dueDate'] != null) {
            dueAt = AiDateParser.parseToUtcMsStrict(
              item['dueDate'],
              nowUtcMs: context.nowUtcMs,
            );
          }
          int? startAt;
          if (item['startDate'] != null) {
            startAt = AiDateParser.parseToUtcMsStrict(
              item['startDate'],
              nowUtcMs: context.nowUtcMs,
            );
          }

          final payload = <String, dynamic>{
            'title': item['title'],
            if (item['description'] != null) 'description': item['description'],
            if (item['priority'] != null) 'priority': item['priority'],
            'startAt': ?startAt,
            'dueAt': ?dueAt,
            if (item['projectId'] != null) 'projectId': item['projectId'],
            if (item['tags'] != null) 'tags': item['tags'],
            if (item['substeps'] != null)
              'substeps': (item['substeps'] as List)
                  .asMap()
                  .entries
                  .map((e) => {'title': e.value, 'sortOrder': e.key})
                  .toList(),
          };

          final task = await AiTaskExecutor.executeCreateTask(
            repository: context.repository,
            payload: payload,
            nowUtcMs: context.nowUtcMs,
            locale: context.locale,
          );

          succeeded++;
          results.add({
            'index': i,
            'ok': true,
            'taskId': task.id,
            'title': task.title,
            'status': task.status.name,
            'dueDate': task.endAt != null
                ? DateFormat('yyyy-MM-dd HH:mm').format(
                    DateTime.fromMillisecondsSinceEpoch(
                      task.endAt!,
                      isUtc: true,
                    ).toLocal(),
                  )
                : null,
          });
        } catch (e) {
          failed++;
          results.add({'index': i, 'ok': false, 'error': e.toString()});
        }
      }

      final resultData = <String, dynamic>{
        'ok': true,
        'status': 'executed',
        'writeMode': 'direct',
        'summary': {
          'total': rawTasks.length,
          'succeeded': succeeded,
          'failed': failed,
        },
        'results': results,
      };

      if (idempotencyKey != null &&
          idempotencyKey.isNotEmpty &&
          context.proposalRepository != null) {
        await context.proposalRepository!.recordDirectExecution(
          type: 'create_bulk',
          idempotencyKey: idempotencyKey,
          result: resultData,
        );
      }

      return AiToolResult.ok(resultData);
    }

    // 3. Proposal staging mode
    if (context.proposalRepository != null) {
      final proposal = await context.proposalRepository!.createProposal(
        type: 'create_bulk',
        payload: {'tasks': rawTasks},
        idempotencyKey: idempotencyKey,
      );

      return AiToolResult.ok({
        'ok': true,
        'status': 'pending',
        'writeMode': 'review',
        'proposalId': proposal.id,
        'summary': {'total': rawTasks.length},
        'staged': proposal.toJson(),
        'requiresConfirmation': true,
        'message':
            'Bulk creation proposal staged (${rawTasks.length} tasks). Call confirm_proposals to commit.',
      });
    }

    return AiToolResult.ok({
      'proposal': {'tasks': rawTasks},
      'writeMode': 'review',
      'requiresConfirmation': true,
      'message': 'Bulk creation proposal prepared for user confirmation.',
    });
  }
}
