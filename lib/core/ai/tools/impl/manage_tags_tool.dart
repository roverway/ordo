import 'package:ordo/core/db/repositories/todo_repository.dart';
import '../ai_tool.dart';

/// Tool for managing tags: listing all tags, creating new tags, deleting obsolete/test tags, or renaming tags.
class ManageTagsTool extends AiTool {
  const ManageTagsTool();

  @override
  bool get isDestructive => false; // delete sub-action is handled inside

  @override
  String get name => 'manage_tags';

  @override
  String get description =>
      'Manages task tags: list existing tags with task usage counts, create a new tag, '
      'delete an obsolete/test tag (unbinding it from tasks), or rename an existing tag.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['list', 'create', 'delete', 'rename'],
        'description': 'Operation to perform on tags (required).',
      },
      'name': {
        'type': 'string',
        'description':
            'Tag name for create action, or lookup name for delete action.',
      },
      'tagId': {
        'type': 'string',
        'description': 'Tag ID for delete or rename action.',
      },
      'newName': {
        'type': 'string',
        'description': 'New name for rename action.',
      },
      'color': {
        'type': 'integer',
        'description': 'Optional integer color code for create/update.',
      },
    },
    'required': ['action'],
  };

  @override
  Future<AiToolResult> execute(
    Map<String, dynamic> arguments,
    AiToolContext context,
  ) async {
    final action = arguments['action']?.toString().toLowerCase().trim();
    if (action == null || action.isEmpty) {
      return AiToolResult.failure(
        'The "action" parameter is required (list, create, delete, rename).',
        code: 'INVALID_ARGUMENT',
      );
    }

    switch (action) {
      case 'list':
        final allTags = await context.repository.tags.getAll();
        final allTaskTags = await context.repository.tags.getAllTaskTags();

        final countMap = <String, int>{};
        for (final tt in allTaskTags) {
          countMap[tt.tagId] = (countMap[tt.tagId] ?? 0) + 1;
        }

        final list = allTags
            .where((t) => t.deleted == 0)
            .map(
              (t) => {
                'id': t.id,
                'name': t.name,
                'color': t.color,
                'taskCount': countMap[t.id] ?? 0,
              },
            )
            .toList();

        return AiToolResult.ok({
          'ok': true,
          'action': 'list',
          'total': list.length,
          'tags': list,
        });

      case 'create':
        final name = arguments['name']?.toString().trim();
        if (name == null || name.isEmpty) {
          return AiToolResult.failure(
            'The "name" parameter is required for tag creation.',
            code: 'INVALID_ARGUMENT',
          );
        }

        final existing = await context.repository.tags.getByName(name);
        if (existing != null && existing.deleted == 0) {
          return AiToolResult.ok({
            'ok': true,
            'action': 'create',
            'status': 'already_exists',
            'tag': {
              'id': existing.id,
              'name': existing.name,
              'color': existing.color,
            },
          });
        }

        int color = 0xFF4A90E2;
        final rawColor = arguments['color'];
        if (rawColor is num) {
          color = rawColor.toInt();
        } else if (rawColor is String) {
          final hex = rawColor.replaceAll('#', '').replaceAll('0x', '');
          final parsed = int.tryParse(hex, radix: 16);
          if (parsed != null) {
            color = hex.length <= 6 ? (0xFF000000 | parsed) : parsed;
          }
        }
        try {
          final created = await context.repository.createTag(
            name: name,
            color: color,
          );
          return AiToolResult.ok({
            'ok': true,
            'action': 'create',
            'status': 'created',
            'tag': {
              'id': created.id,
              'name': created.name,
              'color': created.color,
            },
          });
        } on RepositoryException catch (e) {
          return AiToolResult.failure(e.message, code: 'REPOSITORY_ERROR');
        }

      case 'delete':
        final tagId = (arguments['tagId'] ?? arguments['id'])
            ?.toString()
            .trim();
        final name = arguments['name']?.toString().trim();

        String? targetId = tagId;
        if (targetId == null || targetId.isEmpty) {
          if (name != null && name.isNotEmpty) {
            final tagByName = await context.repository.tags.getByName(name);
            targetId = tagByName?.id;
          }
        }

        if (targetId == null || targetId.isEmpty) {
          return AiToolResult.failure(
            'Either "tagId" or "name" is required for delete.',
            code: 'INVALID_ARGUMENT',
          );
        }

        final existing = await context.repository.tags.getById(targetId);
        if (existing == null || existing.deleted != 0) {
          return AiToolResult.failure(
            'Tag "$targetId" not found.',
            code: 'NOT_FOUND',
          );
        }

        try {
          await context.repository.deleteTag(targetId);
          return AiToolResult.ok({
            'ok': true,
            'action': 'delete',
            'status': 'deleted',
            'tagId': targetId,
            'name': existing.name,
          });
        } on RepositoryException catch (e) {
          return AiToolResult.failure(e.message, code: 'REPOSITORY_ERROR');
        }

      case 'rename':
        final tagId = (arguments['tagId'] ?? arguments['id'])
            ?.toString()
            .trim();
        final newName = arguments['newName']?.toString().trim();
        if (tagId == null ||
            tagId.isEmpty ||
            newName == null ||
            newName.isEmpty) {
          return AiToolResult.failure(
            '"tagId" and "newName" are required for rename.',
            code: 'INVALID_ARGUMENT',
          );
        }

        try {
          await context.repository.updateTag(tagId, name: newName);
          return AiToolResult.ok({
            'ok': true,
            'action': 'rename',
            'status': 'updated',
            'tagId': tagId,
            'newName': newName,
          });
        } on RepositoryException catch (e) {
          return AiToolResult.failure(e.message, code: 'REPOSITORY_ERROR');
        }

      default:
        return AiToolResult.failure(
          'Unknown action "$action". Allowed actions: list, create, delete, rename.',
          code: 'INVALID_ARGUMENT',
        );
    }
  }
}
