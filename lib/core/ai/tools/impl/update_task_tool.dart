import 'package:intl/intl.dart';
import 'package:ordo/core/db/tables.dart';
import '../ai_tool.dart';

/// Tool for proposing updates to existing tasks (title, status, priority, due date).
/// Follows human-in-the-loop review principle.
class UpdateTaskTool extends AiTool {
  const UpdateTaskTool();

  @override
  String get name => 'update_task';

  @override
  String get description =>
      'Proposes updating an existing task\'s status, priority, title, or due date. '
      'Rules: 1. If a task has subtasks, its status is derived automatically from subtasks, so do not update parent status directly. '
      '2. Specify taskId and only the fields to be changed.';

  @override
  Map<String, dynamic> get inputSchema => {
    'type': 'object',
    'properties': {
      'taskId': {
        'type': 'string',
        'description': 'Unique identifier of the task to update.',
      },
      'title': {'type': 'string', 'description': 'New task title if renaming.'},
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
      'dueDate': {
        'type': 'string',
        'description':
            'New due date in ISO 8601 format or "yyyy-MM-dd HH:mm", or "clear" to remove due date.',
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
      return AiToolResult.failure('taskId is required.');
    }

    final task = await context.repository.tasks.getActiveById(taskId);
    if (task == null) {
      return AiToolResult.failure('Task with ID "$taskId" not found.');
    }

    final title = arguments['title']?.toString().trim();
    final statusStr = arguments['status']?.toString().trim();
    final priority = (arguments['priority'] as num?)?.toInt();
    final dueDateRaw = arguments['dueDate']?.toString().trim();

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
        final parsedIso = DateTime.tryParse(dueDateRaw);
        if (parsedIso != null) {
          newDueAtMs = parsedIso.toUtc().millisecondsSinceEpoch;
        } else {
          try {
            final parsedFmt = DateFormat('yyyy-MM-dd HH:mm').parse(dueDateRaw);
            newDueAtMs = parsedFmt.toUtc().millisecondsSinceEpoch;
          } catch (_) {}
        }
      }
    }

    return AiToolResult.ok({
      'proposal': {
        'taskId': task.id,
        'originalTitle': task.title,
        if (title != null && title.isNotEmpty) 'newTitle': title,
        if (newStatus != null) 'newStatus': newStatus.name,
        if (newPriority != null) 'newPriority': newPriority.index,
        if (clearDueDate) 'clearDueDate': true,
        'newDueDate': ?newDueAtMs,
      },
      'requiresConfirmation': true,
      'message': 'Task modification proposal prepared for user confirmation.',
    });
  }
}
