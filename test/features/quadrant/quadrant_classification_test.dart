import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/tables.dart';
import 'package:todo/features/quadrant/models/quadrant_models.dart';
import 'package:todo/features/quadrant/providers/quadrant_providers.dart';

void main() {
  final now = DateTime(2026, 9, 22, 14, 30);
  final endOfTodayMs = DateTime(
    2026,
    9,
    22,
    23,
    59,
    59,
    999,
  ).millisecondsSinceEpoch;
  final overdueMs = DateTime(2026, 9, 21, 18, 0).millisecondsSinceEpoch;
  final futureMs = DateTime(2026, 9, 25, 12, 0).millisecondsSinceEpoch;

  Task createTask({
    required String id,
    required TaskPriority priority,
    int? endAt,
    String projectId = 'inbox',
    String? parentId,
  }) {
    return Task(
      id: id,
      projectId: projectId,
      parentId: parentId,
      title: 'Task $id',
      description: '',
      notes: '',
      status: TaskStatus.todo,
      priority: priority,
      endAt: endAt,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
      sortOrder: 0,
      deleted: 0,
    );
  }

  group('classifyTask tests', () {
    test('Q1: high or medium priority + today or overdue endAt', () {
      final t1 = createTask(
        id: '1',
        priority: TaskPriority.high,
        endAt: endOfTodayMs,
      );
      final t2 = createTask(
        id: '2',
        priority: TaskPriority.medium,
        endAt: overdueMs,
      );

      expect(classifyTask(t1, now), QuadrantType.urgentImportant);
      expect(classifyTask(t2, now), QuadrantType.urgentImportant);
    });

    test('Q2: high or medium priority + future or null endAt', () {
      final t1 = createTask(
        id: '1',
        priority: TaskPriority.high,
        endAt: futureMs,
      );
      final t2 = createTask(
        id: '2',
        priority: TaskPriority.medium,
        endAt: null,
      );

      expect(classifyTask(t1, now), QuadrantType.notUrgentImportant);
      expect(classifyTask(t2, now), QuadrantType.notUrgentImportant);
    });

    test('Q3: low or none priority + today or overdue endAt', () {
      final t1 = createTask(
        id: '1',
        priority: TaskPriority.low,
        endAt: endOfTodayMs,
      );
      final t2 = createTask(
        id: '2',
        priority: TaskPriority.none,
        endAt: overdueMs,
      );

      expect(classifyTask(t1, now), QuadrantType.urgentUnimportant);
      expect(classifyTask(t2, now), QuadrantType.urgentUnimportant);
    });

    test('Q4: low or none priority + future or null endAt', () {
      final t1 = createTask(
        id: '1',
        priority: TaskPriority.low,
        endAt: futureMs,
      );
      final t2 = createTask(id: '2', priority: TaskPriority.none, endAt: null);

      expect(classifyTask(t1, now), QuadrantType.notUrgentUnimportant);
      expect(classifyTask(t2, now), QuadrantType.notUrgentUnimportant);
    });
  });

  group('calculateQuadrantMutation tests', () {
    test('Move Q4 task to Q1 (becomes high priority & endOfToday)', () {
      final task = createTask(
        id: 'q4',
        priority: TaskPriority.none,
        endAt: null,
        projectId: 'project_work',
      );

      final mutation = calculateQuadrantMutation(
        QuadrantType.urgentImportant,
        task,
        now,
      );

      expect(mutation.priority, TaskPriority.high);
      expect(mutation.endAt, endOfTodayMs);
    });

    test('Move Q1 task to Q2 (stays high priority & clears today endAt)', () {
      final task = createTask(
        id: 'q1',
        priority: TaskPriority.high,
        endAt: endOfTodayMs,
      );

      final mutation = calculateQuadrantMutation(
        QuadrantType.notUrgentImportant,
        task,
        now,
      );

      expect(mutation.priority, TaskPriority.high);
      expect(mutation.endAt, isNull);
    });

    test(
      'Move Q1 task to Q3 (becomes none priority & preserves urgent endAt)',
      () {
        final task = createTask(
          id: 'q1',
          priority: TaskPriority.high,
          endAt: overdueMs,
        );

        final mutation = calculateQuadrantMutation(
          QuadrantType.urgentUnimportant,
          task,
          now,
        );

        expect(mutation.priority, TaskPriority.none);
        expect(mutation.endAt, overdueMs);
      },
    );

    test(
      'Move Q2 task (medium priority, future endAt) to Q3 (none priority, endOfToday)',
      () {
        final task = createTask(
          id: 'q2',
          priority: TaskPriority.medium,
          endAt: futureMs,
        );

        final mutation = calculateQuadrantMutation(
          QuadrantType.urgentUnimportant,
          task,
          now,
        );

        expect(mutation.priority, TaskPriority.none);
        expect(mutation.endAt, endOfTodayMs);
      },
    );

    test('Move Q3 task to Q4 (stays low priority & clears today endAt)', () {
      final task = createTask(
        id: 'q3',
        priority: TaskPriority.low,
        endAt: endOfTodayMs,
      );

      final mutation = calculateQuadrantMutation(
        QuadrantType.notUrgentUnimportant,
        task,
        now,
      );

      expect(mutation.priority, TaskPriority.low);
      expect(mutation.endAt, isNull);
    });

    test(
      'Move Q4 task (none priority, future endAt) to Q2 (high priority, keeps future endAt)',
      () {
        final task = createTask(
          id: 'q4',
          priority: TaskPriority.none,
          endAt: futureMs,
        );

        final mutation = calculateQuadrantMutation(
          QuadrantType.notUrgentImportant,
          task,
          now,
        );

        expect(mutation.priority, TaskPriority.high);
        expect(mutation.endAt, futureMs);
      },
    );
  });

  group('QuadrantFilterState tests', () {
    test('matches all tasks when selectedProjectIds is null', () {
      const state = QuadrantFilterState();
      final t1 = createTask(
        id: '1',
        priority: TaskPriority.none,
        projectId: 'p1',
      );
      final t2 = createTask(
        id: '2',
        priority: TaskPriority.none,
        projectId: 'p2',
      );

      expect(state.isCustomScoped, isFalse);
      expect(state.matches(t1), isTrue);
      expect(state.matches(t2), isTrue);
    });

    test('matches only tasks in selectedProjectIds', () {
      final state = const QuadrantFilterState().copyWith(
        selectedProjectIds: {'p1'},
      );
      final t1 = createTask(
        id: '1',
        priority: TaskPriority.none,
        projectId: 'p1',
      );
      final t2 = createTask(
        id: '2',
        priority: TaskPriority.none,
        projectId: 'p2',
      );

      expect(state.isCustomScoped, isTrue);
      expect(state.matches(t1), isTrue);
      expect(state.matches(t2), isFalse);
    });

    test('clearProjectIds resets to null', () {
      final state = const QuadrantFilterState(
        selectedProjectIds: {'p1'},
      ).copyWith(clearProjectIds: true);

      expect(state.isCustomScoped, isFalse);
      expect(state.selectedProjectIds, isNull);
    });
  });

  group('buildQuadrantData tests', () {
    test('categorizes and sorts tasks into 4 quadrants', () {
      final t1 = createTask(
        id: 'q1',
        priority: TaskPriority.high,
        endAt: endOfTodayMs,
      );
      final t2 = createTask(id: 'q2', priority: TaskPriority.high, endAt: null);
      final t3 = createTask(
        id: 'q3',
        priority: TaskPriority.low,
        endAt: overdueMs,
      );
      final t4 = createTask(id: 'q4', priority: TaskPriority.none, endAt: null);

      final data = buildQuadrantData(
        tasks: [t4, t3, t2, t1],
        now: now,
        filter: const QuadrantFilterState(),
        taskTagsMap: {},
        projects: [],
      );

      expect(data.q1UrgentImportant.length, 1);
      expect(data.q1UrgentImportant.first.task.id, 'q1');
      expect(data.q2NotUrgentImportant.length, 1);
      expect(data.q2NotUrgentImportant.first.task.id, 'q2');
      expect(data.q3UrgentUnimportant.length, 1);
      expect(data.q3UrgentUnimportant.first.task.id, 'q3');
      expect(data.q4NotUrgentUnimportant.length, 1);
      expect(data.q4NotUrgentUnimportant.first.task.id, 'q4');
      expect(data.totalCount, 4);
    });

    test('filters tasks by selectedProjectIds', () {
      final t1 = createTask(
        id: '1',
        priority: TaskPriority.high,
        endAt: endOfTodayMs,
        projectId: 'work',
      );
      final t2 = createTask(
        id: '2',
        priority: TaskPriority.high,
        endAt: endOfTodayMs,
        projectId: 'personal',
      );

      final data = buildQuadrantData(
        tasks: [t1, t2],
        now: now,
        filter: const QuadrantFilterState(selectedProjectIds: {'work'}),
        taskTagsMap: {},
        projects: [],
      );

      expect(data.q1UrgentImportant.length, 1);
      expect(data.q1UrgentImportant.first.task.id, '1');
    });

    test(
      'hides completed tasks by default and shows when showCompleted is true',
      () {
        final tActive = createTask(
          id: 'active',
          priority: TaskPriority.high,
          endAt: endOfTodayMs,
        );
        final tDone = Task(
          id: 'done',
          projectId: 'inbox',
          parentId: null,
          title: 'Done task',
          description: '',
          notes: '',
          status: TaskStatus.done,
          priority: TaskPriority.high,
          endAt: endOfTodayMs,
          sortOrder: 0,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          deleted: 0,
        );

        final dataDefault = buildQuadrantData(
          tasks: [tActive, tDone],
          now: now,
          filter: const QuadrantFilterState(),
          taskTagsMap: {},
          projects: [],
        );
        expect(dataDefault.q1UrgentImportant.length, 1);
        expect(dataDefault.q1UrgentImportant.first.task.id, 'active');

        final dataWithDone = buildQuadrantData(
          tasks: [tActive, tDone],
          now: now,
          filter: const QuadrantFilterState(showCompleted: true),
          taskTagsMap: {},
          projects: [],
        );
        expect(dataWithDone.q1UrgentImportant.length, 2);
      },
    );

    test(
      'isOverdue correctly marks yesterday tasks as overdue and today tasks as not overdue',
      () {
        final tDueToday = createTask(
          id: 'today',
          priority: TaskPriority.high,
          endAt: endOfTodayMs,
        );
        final tOverdue = createTask(
          id: 'yesterday',
          priority: TaskPriority.high,
          endAt: overdueMs,
        );

        final data = buildQuadrantData(
          tasks: [tDueToday, tOverdue],
          now: now,
          filter: const QuadrantFilterState(),
          taskTagsMap: {},
          projects: [],
        );

        final todayItem = data.q1UrgentImportant.firstWhere(
          (e) => e.task.id == 'today',
        );
        final overdueItem = data.q1UrgentImportant.firstWhere(
          (e) => e.task.id == 'yesterday',
        );

        expect(
          todayItem.isOverdue,
          isFalse,
          reason: 'Task due today must not be marked overdue',
        );
        expect(
          overdueItem.isOverdue,
          isTrue,
          reason: 'Task due yesterday must be marked overdue',
        );
      },
    );

    test(
      'totalAllCount and completedCount dynamically match selectedProjectIds (folders/lists)',
      () {
        final t1 = createTask(
          id: '1',
          priority: TaskPriority.high,
          endAt: endOfTodayMs,
          projectId: 'projectA',
        );
        final t2Done = Task(
          id: '2',
          projectId: 'projectA',
          parentId: null,
          title: 'Done A',
          description: '',
          notes: '',
          status: TaskStatus.done,
          priority: TaskPriority.high,
          endAt: endOfTodayMs,
          sortOrder: 0,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          deleted: 0,
        );
        final t3 = createTask(
          id: '3',
          priority: TaskPriority.low,
          endAt: null,
          projectId: 'projectB',
        );
        final t4Done = Task(
          id: '4',
          projectId: 'projectB',
          parentId: null,
          title: 'Done B',
          description: '',
          notes: '',
          status: TaskStatus.done,
          priority: TaskPriority.low,
          endAt: null,
          sortOrder: 0,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          deleted: 0,
        );

        final allTasks = [t1, t2Done, t3, t4Done];

        // 1. 无筛选（全部项目）：包含全量 4 个任务，2 个已完成
        final dataAll = buildQuadrantData(
          tasks: allTasks,
          now: now,
          filter: const QuadrantFilterState(),
          taskTagsMap: {},
          projects: [],
        );
        expect(dataAll.totalAllCount, 4);
        expect(dataAll.completedCount, 2);
        expect(dataAll.activeTotalCount, 2);

        // 2. 筛选 projectA：仅统计 projectA 的 2 个任务，1 个已完成
        final dataA = buildQuadrantData(
          tasks: allTasks,
          now: now,
          filter: const QuadrantFilterState(selectedProjectIds: {'projectA'}),
          taskTagsMap: {},
          projects: [],
        );
        expect(dataA.totalAllCount, 2);
        expect(dataA.completedCount, 1);
        expect(dataA.activeTotalCount, 1);

        // 3. 筛选 projectB：仅统计 projectB 的 2 个任务，1 个已完成
        final dataB = buildQuadrantData(
          tasks: allTasks,
          now: now,
          filter: const QuadrantFilterState(selectedProjectIds: {'projectB'}),
          taskTagsMap: {},
          projects: [],
        );
        expect(dataB.totalAllCount, 2);
        expect(dataB.completedCount, 1);
        expect(dataB.activeTotalCount, 1);
      },
    );
  });

  group('QuadrantFilterNotifier tests', () {
    test('toggleProject, toggleFolder, resetAll flow', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(quadrantFilterProvider.notifier);
      expect(container.read(quadrantFilterProvider).isCustomScoped, isFalse);

      final allIds = {'p1', 'p2', 'p3'};

      // Toggle p1 -> custom scoped with {'p2', 'p3'}
      notifier.toggleProject('p1', allIds);
      expect(container.read(quadrantFilterProvider).selectedProjectIds, {
        'p2',
        'p3',
      });

      // Toggle p1 back -> all included -> reset to null (unscoped)
      notifier.toggleProject('p1', allIds);
      expect(container.read(quadrantFilterProvider).isCustomScoped, isFalse);

      // Toggle folder ['p1', 'p2']
      notifier.toggleFolder(['p1', 'p2'], allIds);
      expect(container.read(quadrantFilterProvider).selectedProjectIds, {'p3'});

      // Reset all
      notifier.resetAll();
      expect(container.read(quadrantFilterProvider).isCustomScoped, isFalse);

      // Toggle show completed
      expect(container.read(quadrantFilterProvider).showCompleted, isFalse);
      notifier.toggleShowCompleted();
      expect(container.read(quadrantFilterProvider).showCompleted, isTrue);
    });
  });
}
