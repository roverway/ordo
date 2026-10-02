import 'package:ordo/core/db/repositories/todo_repository.dart';
import '../ai_tool.dart';

/// Tool for rejecting staged task proposals.
class RejectProposalsTool extends AiTool {
  const RejectProposalsTool();

  @override
  String get name => 'reject_proposals';

  @override
  String get description =>
      'Rejects one or more staged task proposals from the review queue, marking them discarded.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'proposalIds': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'List of proposal IDs to reject (max 100).',
      },
    },
    'required': ['proposalIds'],
  };

  @override
  Future<AiToolResult> execute(
    Map<String, dynamic> arguments,
    AiToolContext context,
  ) async {
    if (context.proposalRepository == null) {
      return AiToolResult.failure(
        'Proposal review queue is not enabled on this server.',
        code: 'NOT_SUPPORTED',
      );
    }

    final rawIds = arguments['proposalIds'];
    if (rawIds is! List || rawIds.isEmpty) {
      return AiToolResult.failure(
        'proposalIds must be a non-empty list of proposal IDs.',
        code: 'INVALID_ARGUMENT',
      );
    }

    final proposalIds = rawIds
        .map((e) => e.toString().trim())
        .where((id) => id.isNotEmpty)
        .toList();

    if (proposalIds.length > 100) {
      return AiToolResult.failure(
        'Batch limit exceeded: maximum 100 proposals allowed per call.',
        code: 'BATCH_LIMIT_EXCEEDED',
      );
    }

    final results = <Map<String, dynamic>>[];
    var succeeded = 0;
    var failed = 0;

    for (final id in proposalIds) {
      try {
        await context.proposalRepository!.rejectProposal(id);
        succeeded++;
        results.add({'proposalId': id, 'ok': true, 'status': 'rejected'});
      } on RepositoryException catch (e) {
        failed++;
        results.add({'proposalId': id, 'ok': false, 'error': e.message});
      } catch (e) {
        failed++;
        results.add({'proposalId': id, 'ok': false, 'error': e.toString()});
      }
    }

    return AiToolResult.ok({
      'summary': {
        'total': proposalIds.length,
        'succeeded': succeeded,
        'failed': failed,
      },
      'results': results,
    });
  }
}
