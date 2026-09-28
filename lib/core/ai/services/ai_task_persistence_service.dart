import '../../db/database.dart';
import '../../db/repositories/todo_repository.dart';
import '../../theme/app_tokens.dart';
import '../models/ai_task_parse_result.dart';

/// Persistence outcome containing the created parent task, child tasks, and tags.
class AiTaskPersistenceResult {
  const AiTaskPersistenceResult({
    required this.parentTask,
    this.subtasks = const [],
    this.tags = const [],
  });

  /// Created root/parent task.
  final Task parentTask;

  /// Created child subtasks with parentId set to [parentTask.id].
  final List<Task> subtasks;

  /// Associated tags (either newly created or pre-existing).
  final List<Tag> tags;
}

/// Service that safely and atomically persists [AiTaskParseResult] into SQLite via [TodoRepository].
class AiTaskPersistenceService {
  AiTaskPersistenceService({required TodoRepository repository})
    : _repository = repository;

  final TodoRepository _repository;

  /// Persists parsed task elements inside a database transaction:
  /// 1. Creates the parent task (defaults to [inboxProjectId] if [projectId] is omitted);
  /// 2. Creates and links tags if present in the parse result;
  /// 3. Creates child tasks for all substeps with `parentId = parentTask.id`.
  Future<AiTaskPersistenceResult> persist(
    AiTaskParseResult parseResult, {
    String? projectId,
    String? inboxDisplayName = '收件箱',
    int? defaultTagColor,
  }) async {
    return _repository.database.transaction(() async {
      // 1. Create main task
      final parentTask = await _repository.createTask(
        projectId: projectId,
        inboxDisplayName: inboxDisplayName,
        title: parseResult.title,
        description: parseResult.description ?? '',
        startAt: parseResult.startAt,
        endAt: parseResult.dueAt,
        priority: parseResult.taskPriority,
      );

      // 2. Process and associate tags
      final createdOrFoundTags = <Tag>[];
      if (parseResult.tags.isNotEmpty) {
        final effectiveTagColor =
            defaultTagColor ?? AppTokens.colorNavTags.toARGB32();

        for (final tagName in parseResult.tags) {
          final trimmed = tagName.trim();
          if (trimmed.isEmpty) continue;

          var tag = await _repository.tags.getByName(trimmed);
          tag ??= await _repository.createTag(
            name: trimmed,
            color: effectiveTagColor,
          );
          if (!createdOrFoundTags.any((t) => t.id == tag!.id)) {
            createdOrFoundTags.add(tag);
          }
        }

        if (createdOrFoundTags.isNotEmpty) {
          await _repository.tags.setTaskTags(
            parentTask.id,
            createdOrFoundTags.map((t) => t.id).toList(),
          );
        }
      }

      // 3. Process and create subtasks
      final createdSubtasks = <Task>[];
      if (parseResult.substeps.isNotEmpty) {
        for (final step in parseResult.substeps) {
          final trimmedTitle = step.title.trim();
          if (trimmedTitle.isEmpty) continue;

          final subtask = await _repository.createTask(
            projectId: parentTask.projectId,
            parentId: parentTask.id,
            title: trimmedTitle,
            priority: parentTask.priority,
            inboxDisplayName: inboxDisplayName,
          );
          createdSubtasks.add(subtask);
        }
      }

      return AiTaskPersistenceResult(
        parentTask: parentTask,
        subtasks: createdSubtasks,
        tags: createdOrFoundTags,
      );
    });
  }
}
