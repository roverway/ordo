import 'package:drift/drift.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/repositories/todo_repository.dart';
import 'package:ordo/core/db/tables.dart';
import '../tools/impl/ai_date_parser.dart';

/// Unified executor for creating, updating, and deleting tasks.
/// Single source of truth shared by Direct Write (MCP & Copilot)
/// and Proposal Confirmation.
class AiTaskExecutor {
  const AiTaskExecutor._();

  /// Executes task creation directly in [repository].
  static Future<Task> executeCreateTask({
    required TodoRepository repository,
    required Map<String, dynamic> payload,
    int? nowUtcMs,
    String locale = 'zh',
  }) async {
    final title = payload['title']?.toString().trim();
    if (title == null || title.isEmpty) {
      throw RepositoryException('Task title cannot be empty.');
    }

    final description = payload['description']?.toString().trim() ?? '';
    final rawPriority = (payload['priority'] as num?)?.toInt() ?? 0;
    final priority = TaskPriority.values[rawPriority.clamp(0, 3)];

    final startAt = payload['startAt'] is num
        ? (payload['startAt'] as num).toInt()
        : AiDateParser.parseToUtcMs(payload['startDate']);
    final endAt = payload['dueAt'] is num
        ? (payload['dueAt'] as num).toInt()
        : AiDateParser.parseToUtcMs(payload['dueDate']);

    final rawProjectId = payload['projectId']?.toString().trim();
    String? effectiveProjectId;
    if (rawProjectId != null && rawProjectId.isNotEmpty) {
      final project = await repository.projects.getById(rawProjectId);
      if (project == null || project.deleted != 0) {
        throw RepositoryException('Project with ID "$rawProjectId" not found.');
      }
      effectiveProjectId = rawProjectId;
    } else {
      await repository.ensureInboxProject('收件箱');
      effectiveProjectId = inboxProjectId;
    }

    // Create main task
    final task = await repository.createTask(
      projectId: effectiveProjectId,
      title: title,
      description: description,
      startAt: startAt,
      endAt: endAt,
      priority: priority,
    );

    // Link tags if provided
    final rawTags = payload['tags'];
    if (rawTags is List && rawTags.isNotEmpty) {
      final tagIds = <String>[];
      for (final t in rawTags) {
        final tagName = t.toString().trim();
        if (tagName.isEmpty) continue;
        var tag = await repository.tags.getByName(tagName);
        tag ??= await repository.createTag(name: tagName, color: 0xFF3B82F6);
        tagIds.add(tag.id);
      }
      if (tagIds.isNotEmpty) {
        await repository.tags.setTaskTags(task.id, tagIds);
      }
    }

    // Create subtasks if provided
    final rawSubsteps = payload['substeps'];
    if (rawSubsteps is List && rawSubsteps.isNotEmpty) {
      for (final step in rawSubsteps) {
        String? stepTitle;
        if (step is Map) {
          stepTitle = step['title']?.toString().trim();
        } else if (step is String) {
          stepTitle = step.trim();
        }
        if (stepTitle != null && stepTitle.isNotEmpty) {
          await repository.createTask(
            projectId: task.projectId,
            parentId: task.id,
            title: stepTitle,
          );
        }
      }
    }

    return (await repository.tasks.getById(task.id)) ?? task;
  }

  /// Executes task update directly in [repository].
  static Future<Task> executeUpdateTask({
    required TodoRepository repository,
    required Map<String, dynamic> payload,
    int? nowUtcMs,
  }) async {
    final taskId = payload['taskId']?.toString().trim();
    if (taskId == null || taskId.isEmpty) {
      throw RepositoryException('taskId is required.');
    }

    final task = await repository.tasks.getActiveById(taskId);
    if (task == null) {
      throw RepositoryException('Task with ID "$taskId" not found.');
    }

    // 1. Move project if requested
    final rawProjectId = payload['projectId']?.toString().trim();
    if (rawProjectId != null &&
        rawProjectId.isNotEmpty &&
        rawProjectId != task.projectId) {
      final project = await repository.projects.getById(rawProjectId);
      if (project == null || project.deleted != 0) {
        throw RepositoryException('Project with ID "$rawProjectId" not found.');
      }
      await repository.moveTaskToProject(taskId, rawProjectId);
    }

    // 2. Parse fields
    final title =
        payload['title']?.toString().trim() ??
        payload['newTitle']?.toString().trim();
    final description = payload['description']?.toString().trim();

    final statusStr =
        payload['status']?.toString().trim() ??
        payload['newStatus']?.toString().trim();
    TaskStatus? newStatus;
    if (statusStr != null) {
      for (final s in TaskStatus.values) {
        if (s.name == statusStr) {
          newStatus = s;
          break;
        }
      }
    }

    final rawPriority = (payload['priority'] ?? payload['newPriority']) as num?;
    TaskPriority? newPriority;
    if (rawPriority != null) {
      final idx = rawPriority.toInt();
      if (idx >= 0 && idx < TaskPriority.values.length) {
        newPriority = TaskPriority.values[idx];
      }
    }

    Value<int?> startAtVal = const Value.absent();
    if (payload.containsKey('startDate')) {
      final sd = payload['startDate']?.toString().trim();
      startAtVal = Value(
        sd != null && sd.isNotEmpty ? AiDateParser.parseToUtcMs(sd) : null,
      );
    }

    Value<int?> endAtVal = const Value.absent();
    final clearDueDate = payload['clearDueDate'] == true;
    final dueDateRaw = payload['dueDate']?.toString().trim();
    if (clearDueDate || dueDateRaw == 'clear' || dueDateRaw == 'none') {
      endAtVal = const Value(null);
    } else if (payload.containsKey('newDueDate') &&
        payload['newDueDate'] is num) {
      endAtVal = Value((payload['newDueDate'] as num).toInt());
    } else if (dueDateRaw != null && dueDateRaw.isNotEmpty) {
      endAtVal = Value(AiDateParser.parseToUtcMs(dueDateRaw));
    }

    await repository.updateTask(
      taskId,
      title: title != null && title.isNotEmpty ? title : null,
      description: description,
      status: newStatus,
      priority: newPriority,
      startAt: startAtVal,
      endAt: endAtVal,
    );

    // 3. Update tags if provided
    if (payload.containsKey('tags')) {
      final rawTags = payload['tags'];
      if (rawTags is List) {
        final tagIds = <String>[];
        for (final t in rawTags) {
          final tagName = t.toString().trim();
          if (tagName.isEmpty) continue;
          var tag = await repository.tags.getByName(tagName);
          tag ??= await repository.createTag(name: tagName, color: 0xFF3B82F6);
          tagIds.add(tag.id);
        }
        await repository.tags.setTaskTags(taskId, tagIds);
      }
    }

    return (await repository.tasks.getActiveById(taskId)) ?? task;
  }
}
