import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/ai/models/ai_task_parse_result.dart';
import 'package:ordo/core/ai/services/ai_task_persistence_service.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/repositories/todo_repository.dart';
import 'package:ordo/core/db/tables.dart';

import '../../helpers/db_test_setup.dart';

void main() {
  late AppDatabase db;
  late TodoRepository repository;
  late AiTaskPersistenceService persistenceService;

  setUp(() async {
    db = openTestDatabase();
    repository = TodoRepository(database: db);
    persistenceService = AiTaskPersistenceService(repository: repository);
    // Ensure inbox project is initialized
    await repository.ensureInboxProject('收件箱');
  });

  tearDown(() async {
    await db.close();
  });

  group('AiTaskPersistenceService', () {
    test(
      'persists single task into inbox project with priority and due date',
      () async {
        const parseResult = AiTaskParseResult(
          title: '整理桌面',
          description: '归类纸质文件',
          priority: 1, // low
          dueAt: 1727533200000,
          startAt: 1727500800000,
        );

        final result = await persistenceService.persist(parseResult);

        expect(result.parentTask.title, '整理桌面');
        expect(result.parentTask.description, '归类纸质文件');
        expect(result.parentTask.priority, TaskPriority.low);
        expect(result.parentTask.projectId, inboxProjectId);
        expect(result.parentTask.startAt, 1727500800000);
        expect(result.parentTask.endAt, 1727533200000);
        expect(result.subtasks, isEmpty);

        // Verify in DB
        final dbTask = await repository.tasks.getActiveById(
          result.parentTask.id,
        );
        expect(dbTask, isNotNull);
        expect(dbTask!.title, '整理桌面');
      },
    );

    test(
      'AC-03: persists parent task and creates 3 subtasks with parentId relationship',
      () async {
        const parseResult = AiTaskParseResult(
          title: '项目周报',
          priority: 2, // medium
          substeps: [
            AiSubstep(title: '收集数据', sortOrder: 0),
            AiSubstep(title: '起草周报内容', sortOrder: 1),
            AiSubstep(title: '校对并发送邮件', sortOrder: 2),
          ],
        );

        final result = await persistenceService.persist(parseResult);

        expect(result.parentTask.title, '项目周报');
        expect(result.subtasks.length, 3);

        for (var i = 0; i < 3; i++) {
          final subtask = result.subtasks[i];
          expect(subtask.parentId, result.parentTask.id);
          expect(subtask.projectId, result.parentTask.projectId);
          expect(subtask.title, parseResult.substeps[i].title);
        }

        // Verify hierarchy in database
        final children = await repository.tasks.getDirectChildren(
          result.parentTask.projectId,
          result.parentTask.id,
        );
        expect(children.length, 3);
        expect(children.map((c) => c.title).toList(), [
          '收集数据',
          '起草周报内容',
          '校对并发送邮件',
        ]);
      },
    );

    test(
      'creates new tags and links them to the task without duplication',
      () async {
        // Pre-create one tag in DB
        final existingTag = await repository.createTag(
          name: '工作',
          color: 0xFF123456,
        );

        const parseResult = AiTaskParseResult(
          title: '开周会',
          priority: 2,
          tags: ['工作', '行政', '工作'], // '工作' exists, '行政' is new, duplicate '工作'
        );

        final result = await persistenceService.persist(parseResult);

        expect(result.tags.length, 2);
        expect(result.tags.map((t) => t.name).toSet(), {'工作', '行政'});

        // Tag '工作' should retain original ID and color
        final workTag = result.tags.firstWhere((t) => t.name == '工作');
        expect(workTag.id, existingTag.id);

        // Verify task_tags in repository
        final linkedTags = await repository.tags.tagsForTask(
          result.parentTask.id,
        );
        expect(linkedTags.length, 2);
        expect(linkedTags.map((t) => t.name).toSet(), {'工作', '行政'});
      },
    );

    test(
      'persists task into custom project when projectId is specified',
      () async {
        final customProject = await repository.createProject(
          name: '测试项目',
          color: 0xFF00AAFF,
        );

        const parseResult = AiTaskParseResult(
          title: '特定项目任务',
          priority: 3, // high
        );

        final result = await persistenceService.persist(
          parseResult,
          projectId: customProject.id,
        );

        expect(result.parentTask.projectId, customProject.id);
        final dbTask = await repository.tasks.getActiveById(
          result.parentTask.id,
        );
        expect(dbTask!.projectId, customProject.id);
      },
    );
  });
}
