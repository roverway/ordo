import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/ai/tools/ai_tool.dart';
import 'package:ordo/core/ai/tools/ai_tool_registry.dart';
import 'package:ordo/core/ai/tools/impl/create_tasks_tool.dart';
import 'package:ordo/core/ai/tools/impl/get_metadata_tool.dart';
import 'package:ordo/core/ai/tools/impl/query_tasks_tool.dart';
import 'package:ordo/core/ai/tools/impl/update_task_tool.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/repositories/todo_repository.dart';
import 'package:ordo/core/db/tables.dart';

import '../../../helpers/db_test_setup.dart';

void main() {
  late AppDatabase db;
  late TodoRepository repository;

  setUp(() async {
    db = openTestDatabase();
    repository = TodoRepository(database: db);
    await repository.ensureInboxProject('收件箱');
  });

  tearDown(() async {
    await db.close();
  });

  group('AiToolRegistry', () {
    test('registers standard tools and outputs multi-protocol formats', () {
      final registry = AiToolRegistry.standard();

      expect(registry.has('query_tasks'), isTrue);
      expect(registry.has('get_metadata'), isTrue);
      expect(registry.has('create_tasks'), isTrue);
      expect(registry.has('update_task'), isTrue);

      // OpenAI format
      final openAiTools = registry.toOpenAiTools();
      expect(openAiTools.length, 4);
      final queryToolSpec = openAiTools.firstWhere(
        (t) => t['function']['name'] == 'query_tasks',
      );
      expect(queryToolSpec['type'], 'function');
      expect(queryToolSpec['function']['parameters'], isNotNull);

      // Claude format
      final claudeTools = registry.toClaudeTools();
      expect(claudeTools.length, 4);
      final claudeQuerySpec = claudeTools.firstWhere(
        (t) => t['name'] == 'query_tasks',
      );
      expect(claudeQuerySpec['name'], 'query_tasks');
      expect(claudeQuerySpec['input_schema'], isNotNull);
    });
  });

  group('GetMetadataTool', () {
    test(
      'returns accurate current time, weekday, and project taxonomy',
      () async {
        await repository.projects.insert(
          ProjectsCompanion.insert(
            id: 'proj-work',
            name: '工作项目',
            sortOrder: 1,
            color: 0xFF00FF00,
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );

        await repository.tags.insert(
          TagsCompanion.insert(
            id: 'tag-urgent',
            name: '紧急',
            color: 0xFFFF0000,
            sortOrder: 1,
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );

        final tool = const GetMetadataTool();
        final fixedUtcMs = DateTime.utc(
          2026,
          9,
          29,
          10,
          0,
          0,
        ).millisecondsSinceEpoch;
        final context = AiToolContext(
          repository: repository,
          nowUtcMs: fixedUtcMs,
        );

        final result = await tool.execute({}, context);
        expect(result.success, isTrue);

        final data = result.data as Map<String, dynamic>;
        expect(data['now'], isNotNull);
        expect(data['now']['date'], contains('2026-09-29'));

        final projects = data['projects'] as List;
        expect(projects.any((p) => p['name'] == '工作项目'), isTrue);

        final tags = data['tags'] as List;
        expect(tags.any((t) => t['name'] == '紧急'), isTrue);
      },
    );
  });

  group('QueryTasksTool & TaskQueryEngine Integration', () {
    test('filters tasks by completion status, keyword, and priority', () async {
      final now = DateTime.utc(2026, 9, 29, 12, 0, 0);
      final nowMs = now.millisecondsSinceEpoch;

      // Insert Task 1: pending (todo), keyword "需求评审", high priority
      await repository.tasks.insert(
        TasksCompanion.insert(
          id: 'task-1',
          projectId: 'inbox',
          title: '需求评审会议',
          sortOrder: 0,
          priority: const Value(TaskPriority.high),
          status: TaskStatus.todo,
          createdAt: nowMs - 10000,
          updatedAt: nowMs - 10000,
        ),
      );

      // Insert Task 2: completed (done), keyword "周报整理", low priority
      await repository.tasks.insert(
        TasksCompanion.insert(
          id: 'task-2',
          projectId: 'inbox',
          title: '周报整理',
          sortOrder: 1,
          priority: const Value(TaskPriority.low),
          status: TaskStatus.done,
          completedAt: Value(nowMs - 5000),
          createdAt: nowMs - 20000,
          updatedAt: nowMs - 5000,
        ),
      );

      final tool = const QueryTasksTool();
      final context = AiToolContext(repository: repository, nowUtcMs: nowMs);

      // Query 1: Uncompleted tasks only (statuses: ['todo', 'inProgress'])
      final uncompletedResult = await tool.execute({
        'statuses': ['todo', 'inProgress'],
      }, context);
      expect(uncompletedResult.success, isTrue);
      final uncompletedTasks =
          (uncompletedResult.data as Map<String, dynamic>)['tasks'] as List;
      expect(uncompletedTasks.length, 1);
      expect(uncompletedTasks.first['id'], 'task-1');

      // Query 2: Filter by searchQuery "周报"
      final keywordResult = await tool.execute({'searchQuery': '周报'}, context);
      expect(keywordResult.success, isTrue);
      final keywordTasks =
          (keywordResult.data as Map<String, dynamic>)['tasks'] as List;
      expect(keywordTasks.length, 1);
      expect(keywordTasks.first['title'], '周报整理');

      // Query 3: Filter by high priority
      final priorityResult = await tool.execute({
        'priorities': ['high'],
      }, context);
      expect(priorityResult.success, isTrue);
      final priorityTasks =
          (priorityResult.data as Map<String, dynamic>)['tasks'] as List;
      expect(priorityTasks.length, 1);
      expect(priorityTasks.first['id'], 'task-1');
    });

    test(
      'returns rich metadata (completedDate, subtasks) and filters by completedScope correctly',
      () async {
        final now = DateTime.utc(2026, 9, 29, 12, 0, 0);
        final nowMs = now.millisecondsSinceEpoch;

        // 插入昨天完成的任务 (2026-09-28 15:00 UTC)
        final yestCompMs = DateTime.utc(
          2026,
          9,
          28,
          15,
          0,
          0,
        ).millisecondsSinceEpoch;
        await repository.tasks.insert(
          TasksCompanion.insert(
            id: 'task-yesterday-done',
            projectId: 'inbox',
            title: '昨天完成的任务',
            description: const Value('详细说明文案'),
            status: TaskStatus.done,
            completedAt: Value(yestCompMs),
            sortOrder: 0,
            createdAt: yestCompMs - 3600000,
            updatedAt: yestCompMs,
          ),
        );

        // 插入含子任务的父任务：子任务全部完成，父任务自动派生为已完成
        final parentCreatedAt = nowMs - 7200000;
        await repository.tasks.insert(
          TasksCompanion.insert(
            id: 'parent-task',
            projectId: 'inbox',
            title: '发布会准备',
            status: TaskStatus.todo,
            sortOrder: 1,
            createdAt: parentCreatedAt,
            updatedAt: nowMs,
          ),
        );

        final childComp1 = nowMs - 1800000;
        final childComp2 = nowMs - 900000; // 最晚完成的子任务时间
        await repository.tasks.insert(
          TasksCompanion.insert(
            id: 'child-1',
            projectId: 'inbox',
            parentId: const Value('parent-task'),
            title: '准备演讲稿',
            status: TaskStatus.done,
            completedAt: Value(childComp1),
            sortOrder: 0,
            createdAt: parentCreatedAt,
            updatedAt: childComp1,
          ),
        );
        await repository.tasks.insert(
          TasksCompanion.insert(
            id: 'child-2',
            projectId: 'inbox',
            parentId: const Value('parent-task'),
            title: '核对演示设备',
            status: TaskStatus.done,
            completedAt: Value(childComp2),
            sortOrder: 1,
            createdAt: parentCreatedAt,
            updatedAt: childComp2,
          ),
        );

        final tool = const QueryTasksTool();
        final context = AiToolContext(repository: repository, nowUtcMs: nowMs);

        // 查询 1：按 completedScope: 'yesterday' 检索
        final yesterdayResult = await tool.execute({
          'completedScope': 'yesterday',
        }, context);
        expect(yesterdayResult.success, isTrue);
        final yestTasks =
            (yesterdayResult.data as Map<String, dynamic>)['tasks'] as List;
        expect(yestTasks.any((t) => t['id'] == 'task-yesterday-done'), isTrue);
        final yestTask = yestTasks.firstWhere(
          (t) => t['id'] == 'task-yesterday-done',
        );
        expect(yestTask['completedDate'], isNotNull);
        expect(yestTask['completedAt'], yestCompMs);
        expect(yestTask['description'], '详细说明文案');
        expect(yestTask['createdDate'], isNotNull);

        // 查询 2：按 completedScope: 'today' 检索父任务及其派生完成状态
        final todayResult = await tool.execute({
          'completedScope': 'today',
        }, context);
        expect(todayResult.success, isTrue);
        final todayTasks =
            (todayResult.data as Map<String, dynamic>)['tasks'] as List;
        final parentMatch = todayTasks.firstWhere(
          (t) => t['id'] == 'parent-task',
        );
        expect(parentMatch['status'], 'done');
        expect(parentMatch['isCompleted'], isTrue);
        expect(parentMatch['completedAt'], childComp2);
        expect(parentMatch['subtaskCount'], 2);
        expect(parentMatch['completedSubtaskCount'], 2);
      },
    );
  });

  group('CreateTasksTool', () {
    test(
      'produces task proposal payload matching AiTaskParseResult schema',
      () async {
        final tool = const CreateTasksTool();
        final context = AiToolContext(repository: repository);

        final result = await tool.execute({
          'title': '搭建自动化编译脚本',
          'description': '包含 CI/CD 配置',
          'priority': 2,
          'tags': ['开发', '运维'],
          'substeps': ['编写 Makefile', '配置 GitHub Actions'],
        }, context);

        expect(result.success, isTrue);
        final data = result.data as Map<String, dynamic>;
        expect(data['requiresConfirmation'], isTrue);
        final proposal = data['proposal'] as Map<String, dynamic>;
        expect(proposal['title'], '搭建自动化编译脚本');
        expect(proposal['priority'], 2);
        expect(proposal['tags'], containsAll(['开发', '运维']));
        expect((proposal['substeps'] as List).length, 2);
      },
    );
  });

  group('UpdateTaskTool', () {
    test(
      'produces update action proposal for modifying existing task',
      () async {
        // First insert task-target
        await repository.tasks.insert(
          TasksCompanion.insert(
            id: 'task-target',
            projectId: 'inbox',
            title: '原任务标题',
            status: TaskStatus.todo,
            sortOrder: 0,
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );

        final tool = const UpdateTaskTool();
        final context = AiToolContext(repository: repository);

        final result = await tool.execute({
          'taskId': 'task-target',
          'status': 'done',
          'title': '修改后的任务标题',
        }, context);

        expect(result.success, isTrue);
        final data = result.data as Map<String, dynamic>;
        expect(data['requiresConfirmation'], isTrue);
        final proposal = data['proposal'] as Map<String, dynamic>;
        expect(proposal['taskId'], 'task-target');
        expect(proposal['newStatus'], 'done');
        expect(proposal['newTitle'], '修改后的任务标题');
      },
    );
  });
}
