import '../ai_tool.dart';

/// Tool for retrieving deep details of a single task including subtask tree and tags.
class GetTaskTool extends AiTool {
  const GetTaskTool();

  @override
  String get name => 'get_task';

  @override
  String get description =>
      'Retrieves complete details of a single task by ID, including its full subtask hierarchy, tags, and project name.';

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
    final subtasks = await context.repository.tasks.getDirectChildren(
      task.projectId,
      taskId,
    );

    return AiToolResult.ok({
      'task': {
        'id': task.id,
        'title': task.title,
        'description': task.description,
        'notes': task.notes,
        'status': task.status.name,
        'priority': task.priority.index,
        'projectId': task.projectId,
        'projectName': project?.name ?? 'Inbox',
        'parentId': task.parentId,
        'startAt': task.startAt,
        'dueAt': task.endAt,
        'completedAt': task.completedAt,
        'createdAt': task.createdAt,
        'updatedAt': task.updatedAt,
        'tags': tags
            .map((t) => {'id': t.id, 'name': t.name, 'color': t.color})
            .toList(),
        'subtasks': subtasks
            .map(
              (s) => {
                'id': s.id,
                'title': s.title,
                'status': s.status.name,
                'priority': s.priority.index,
                'sortOrder': s.sortOrder,
              },
            )
            .toList(),
      },
    });
  }
}
