import '../ai_tool.dart';

/// Tool for querying staged task proposals in the review queue.
class ListProposalsTool extends AiTool {
  const ListProposalsTool();

  @override
  String get name => 'list_proposals';

  @override
  String get description =>
      'Lists staged task proposals currently in the human-in-the-loop review queue. '
      'Filter by status (pending, confirmed, rejected, expired, all).';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'status': {
        'type': 'string',
        'enum': ['pending', 'confirmed', 'rejected', 'expired', 'all'],
        'description': 'Filter by proposal status (default: "pending").',
      },
      'limit': {
        'type': 'integer',
        'description':
            'Maximum number of proposals to return (1-100, default: 20).',
      },
      'cursor': {
        'type': 'string',
        'description': 'Pagination cursor for subsequent pages.',
      },
    },
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

    final status = arguments['status']?.toString().trim() ?? 'pending';
    final limit = (arguments['limit'] as num?)?.toInt() ?? 20;
    final cursor = arguments['cursor']?.toString().trim();

    final proposals = await context.proposalRepository!.listProposals(
      status: status,
      limit: limit,
      cursor: cursor,
    );

    return AiToolResult.ok({
      'count': proposals.length,
      'statusFilter': status,
      'proposals': proposals.map((p) => p.toJson()).toList(),
      if (proposals.length >= limit)
        'nextCursor': proposals.last.createdAt.toString(),
    });
  }
}
