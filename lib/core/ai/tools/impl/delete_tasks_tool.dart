import '../ai_tool.dart';

/// Tool for deleting tasks (batch support, direct or proposal staging).
class DeleteTasksTool extends AiTool {
  const DeleteTasksTool();

  @override
  String get name => 'delete_tasks';

  @override
  String get description =>
      'Deletes one or more tasks by their IDs (cascading to subtasks). '
      'In direct mode, deletes immediately. In proposal mode, stages to review queue.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'taskIds': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'Array of task IDs to delete (max 100).',
      },
      'mode': {
        'type': 'string',
        'enum': ['auto', 'direct', 'proposal'],
        'description':
            'Execution mode: "direct" deletes immediately, "proposal" stages to review queue.',
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
        'taskIds must be a non-empty array of task IDs.',
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

    final requestedMode = arguments['mode']?.toString().trim();
    final isDirect =
        requestedMode == 'direct' ||
        (requestedMode != 'proposal' && context.writeMode == 'direct');

    if (isDirect) {
      final results = <Map<String, dynamic>>[];
      var succeeded = 0;
      var failed = 0;

      for (final id in taskIds) {
        try {
          await context.repository.deleteTask(id);
          succeeded++;
          results.add({'taskId': id, 'ok': true, 'status': 'deleted'});
        } catch (e) {
          failed++;
          results.add({'taskId': id, 'ok': false, 'error': e.toString()});
        }
      }

      return AiToolResult.ok({
        'summary': {
          'total': taskIds.length,
          'succeeded': succeeded,
          'failed': failed,
        },
        'results': results,
      });
    }

    // Proposal staging mode
    final idempotencyKey = arguments['idempotencyKey']?.toString().trim();
    if (context.proposalRepository != null) {
      final proposal = await context.proposalRepository!.createProposal(
        type: 'delete',
        payload: {'taskIds': taskIds},
        idempotencyKey: idempotencyKey,
      );

      return AiToolResult.ok({
        'ok': true,
        'status': 'pending',
        'proposalId': proposal.id,
        'proposal': proposal.toJson(),
        'requiresConfirmation': true,
        'message':
            'Deletion proposal staged (${taskIds.length} tasks). Call confirm_proposals to execute.',
      });
    }

    return AiToolResult.ok({
      'proposal': {'taskIds': taskIds},
      'requiresConfirmation': true,
      'message': 'Deletion proposal prepared for user confirmation.',
    });
  }
}
