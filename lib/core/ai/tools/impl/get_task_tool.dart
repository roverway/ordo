import 'package:intl/intl.dart';
import 'package:ordo/core/utils/derived.dart';
import '../ai_tool.dart';

/// Tool for retrieving deep details of a single task including recursive subtask tree and tags.
class GetTaskTool extends AiTool {
  const GetTaskTool();

  @override
  bool get isReadOnly => true;

  @override
  bool get isIdempotent => true;

  @override
  String get name => 'get_task';

  @override
  String get description =>
      'Retrieves complete details of a single task by ID, including its recursive subtask tree, '
      'tags, project metadata, and derived completion status.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'taskId': {
        'type': 'string',
        'description': 'Unique identifier of the task.',
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
        details: {'taskId': taskId},
      );
    }

    final project = await context.repository.projects.getById(task.projectId);
    final tags = await context.repository.tags.tagsForTask(taskId);

    // Recursively build subtask tree
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    Future<List<Map<String, dynamic>>> buildChildrenTree(
      String parentId,
      int depth,
    ) async {
      if (depth > 5) return [];
      final directChildren = await context.repository.tasks.getDirectChildren(
        task.projectId,
        parentId,
      );
      final result = <Map<String, dynamic>>[];
      for (final child in directChildren) {
        final subchildren = await buildChildrenTree(child.id, depth + 1);
        result.add({
          'id': child.id,
          'title': child.title,
          'status': child.status.name,
          'priority': child.priority.index,
          'priorityLevel': child.priority.name,
          'sortOrder': child.sortOrder,
          'startAt': child.startAt,
          'dueAt': child.endAt,
          'dueDate': child.endAt != null
              ? dateFormat.format(
                  DateTime.fromMillisecondsSinceEpoch(
                    child.endAt!,
                    isUtc: true,
                  ).toLocal(),
                )
              : null,
          if (subchildren.isNotEmpty) 'subtasks': subchildren,
        });
      }
      return result;
    }

    final directChildrenTasks = await context.repository.tasks
        .getDirectChildren(task.projectId, task.id);
    final effectiveStatus = directChildrenTasks.isEmpty
        ? task.status
        : derivedStatus(task, directChildrenTasks);

    final subtasksTree = await buildChildrenTree(task.id, 0);

    return AiToolResult.ok({
      'task': {
        'id': task.id,
        'title': task.title,
        'description': task.description,
        'notes': task.notes,
        'status': effectiveStatus.name,
        'rawStatus': task.status.name,
        'priority': task.priority.index,
        'priorityLevel': task.priority.name,
        'projectId': task.projectId,
        'projectName': project?.name ?? 'Inbox',
        'parentId': task.parentId,
        'startAt': task.startAt,
        'startDate': task.startAt != null
            ? dateFormat.format(
                DateTime.fromMillisecondsSinceEpoch(
                  task.startAt!,
                  isUtc: true,
                ).toLocal(),
              )
            : null,
        'dueAt': task.endAt,
        'dueDate': task.endAt != null
            ? dateFormat.format(
                DateTime.fromMillisecondsSinceEpoch(
                  task.endAt!,
                  isUtc: true,
                ).toLocal(),
              )
            : null,
        'completedAt': task.completedAt,
        'completedDate': task.completedAt != null
            ? dateFormat.format(
                DateTime.fromMillisecondsSinceEpoch(
                  task.completedAt!,
                  isUtc: true,
                ).toLocal(),
              )
            : null,
        'createdAt': task.createdAt,
        'updatedAt': task.updatedAt,
        'tags': tags
            .map((t) => {'id': t.id, 'name': t.name, 'color': t.color})
            .toList(),
        'subtasks': subtasksTree,
      },
    });
  }
}
