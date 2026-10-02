import '../ai_tool.dart';

/// Tool for deleting multiple tasks by ID.
class DeleteTasksTool extends AiTool {
  const DeleteTasksTool();

  @override
  bool get isDestructive => true;

  @override
  String get name => 'delete_tasks';

  @override
  String get description =>
      'Permanently deletes one or more tasks by their unique IDs (up to 100). '
      'Subtasks and tag associations are cascade cleaned. In direct mode, performs deletion immediately. '
      'In proposal mode, stages proposal to review queue. Supports dryRun: true to preview deletion targets.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'taskIds': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Array of task IDs to delete (required, maximum 100).',
      },
      'dryRun': {
        'type': 'boolean',
        'description':
            'If true, verifies task existence and previews deletion targets without modifying database state.',
      },
      'mode': {
        'type': 'string',
        'enum': ['auto', 'direct', 'proposal'],
        'description':
            'Execution mode: "direct" writes immediately, "proposal" stages to queue, "auto" uses server default.',
      },
      'idempotencyKey': {
        'type': 'string',
        'description': 'Optional client token for deduplication.',
      },
    },
    'required': ['taskIds'],
  };

  @override
  Future<AiToolResult> execute(
    Map<String, dynamic> arguments,
    AiToolContext context,
  ) async {
    final rawIds = arguments['taskIds'];
    if (rawIds is! List || rawIds.isEmpty) {
      return AiToolResult.failure(
        'The "taskIds" argument must be a non-empty list of task IDs.',
        code: 'INVALID_ARGUMENT',
      );
    }

    final taskIds = rawIds
        .map((e) => e.toString().trim())
        .where((id) => id.isNotEmpty)
        .toList();

    if (taskIds.length > 100) {
      return AiToolResult.failure(
        'Batch limit exceeded: maximum 100 task IDs allowed per call.',
        code: 'BATCH_LIMIT_EXCEEDED',
      );
    }

    // Preflight task existence check and title resolution (resolves §6.4)
    final existingTasks = <Map<String, dynamic>>[];
    final missingIds = <String>[];

    for (final id in taskIds) {
      final task = await context.repository.tasks.getActiveById(id);
      if (task != null) {
        existingTasks.add({
          'id': task.id,
          'title': task.title,
          'projectId': task.projectId,
          'status': task.status.name,
        });
      } else {
        missingIds.add(id);
      }
    }

    if (existingTasks.isEmpty) {
      return AiToolResult.failure(
        'None of the specified tasks were found.',
        code: 'NOT_FOUND',
        details: {'missingIds': missingIds},
      );
    }

    // Dry Run check
    if (arguments['dryRun'] == true) {
      return AiToolResult.ok({
        'ok': true,
        'dryRun': true,
        'targetsToDelete': existingTasks,
        if (missingIds.isNotEmpty) 'notFoundIds': missingIds,
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
      final results = <Map<String, dynamic>>[];
      var succeeded = 0;
      var failed = 0;

      for (final target in existingTasks) {
        final id = target['id'] as String;
        final title = target['title'] as String;
        try {
          await context.repository.deleteTask(id);
          succeeded++;
          results.add({
            'taskId': id,
            'title': title,
            'ok': true,
            'status': 'deleted',
          });
        } catch (e) {
          failed++;
          results.add({'taskId': id, 'ok': false, 'error': e.toString()});
        }
      }

      for (final id in missingIds) {
        failed++;
        results.add({
          'taskId': id,
          'ok': false,
          'error': 'Task not found or already deleted.',
        });
      }

      final resultData = <String, dynamic>{
        'ok': true,
        'status': 'executed',
        'writeMode': 'direct',
        'summary': {
          'requested': taskIds.length,
          'succeeded': succeeded,
          'failed': failed,
        },
        'results': results,
      };

      if (idempotencyKey != null &&
          idempotencyKey.isNotEmpty &&
          context.proposalRepository != null) {
        await context.proposalRepository!.recordDirectExecution(
          type: 'delete',
          idempotencyKey: idempotencyKey,
          result: resultData,
        );
      }

      return AiToolResult.ok(resultData);
    }

    // Proposal staging mode
    if (context.proposalRepository != null) {
      final proposal = await context.proposalRepository!.createProposal(
        type: 'delete',
        payload: {
          'taskIds': taskIds,
          'targets': existingTasks,
          if (missingIds.isNotEmpty) 'missingIds': missingIds,
        },
        idempotencyKey: idempotencyKey,
      );

      return AiToolResult.ok({
        'ok': true,
        'status': 'pending',
        'writeMode': 'review',
        'proposalId': proposal.id,
        'proposal': proposal.toJson(),
        'requiresConfirmation': true,
        'message':
            'Deletion proposal staged (${existingTasks.length} tasks). Call confirm_proposals to execute.',
      });
    }

    return AiToolResult.ok({
      'proposal': {'taskIds': taskIds, 'targets': existingTasks},
      'writeMode': 'review',
      'requiresConfirmation': true,
      'message': 'Deletion proposal prepared for user confirmation.',
    });
  }
}
