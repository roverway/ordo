import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/db/database.dart';
import 'package:ordo/core/db/tables.dart';
import 'package:ordo/core/utils/custom_view_models.dart';

void main() {
  group('FilterCriteria JSON Serialization', () {
    test('round-trip toJson & fromJson', () {
      const criteria = FilterCriteria(
        folderIds: ['f1', 'unassigned'],
        projectIds: ['p1', 'p2'],
        tagIds: ['t1'],
        tagMatchAll: true,
        priorities: [TaskPriority.high, TaskPriority.medium],
        statuses: [TaskStatus.todo, TaskStatus.inProgress],
        dateScope: DateScopeEnum.today,
        hierarchyScope: HierarchyScopeEnum.rootOnly,
        searchQuery: 'test',
      );

      final json = criteria.toJson();
      final restored = FilterCriteria.fromJson(json);

      expect(restored.folderIds, ['f1', 'unassigned']);
      expect(restored.projectIds, ['p1', 'p2']);
      expect(restored.tagIds, ['t1']);
      expect(restored.tagMatchAll, true);
      expect(restored.priorities, [TaskPriority.high, TaskPriority.medium]);
      expect(restored.statuses, [TaskStatus.todo, TaskStatus.inProgress]);
      expect(restored.dateScope, DateScopeEnum.today);
      expect(restored.hierarchyScope, HierarchyScopeEnum.rootOnly);
      expect(restored.searchQuery, 'test');
      expect(restored.hasActiveFilter, true);
    });

    test('empty criteria hasActiveFilter is false', () {
      const empty = FilterCriteria();
      expect(empty.hasActiveFilter, false);
    });
  });

  group('CustomViewPanelConfig & Presets', () {
    test('encodePanelsJson and decodePanelsJson', () {
      final panels = createStatusKanbanPanels(
        titleTodo: '待办',
        titleInProgress: '处理中',
        titleDone: '完成',
      );
      expect(panels.length, 3);
      expect(panels[0].title, '待办');
      expect(panels[0].filter.statuses, [TaskStatus.todo]);

      final encoded = encodePanelsJson(panels);
      final decoded = decodePanelsJson(encoded);
      expect(decoded.length, 3);
      expect(decoded[0].title, '待办');
      expect(decoded[0].filter.statuses, [TaskStatus.todo]);
    });

    test('createPriorityKanbanPanels generates 4 panels', () {
      final panels = createPriorityKanbanPanels();
      expect(panels.length, 4);
      expect(panels[0].filter.priorities, [TaskPriority.high]);
      expect(panels[1].filter.priorities, [TaskPriority.medium]);
      expect(panels[2].filter.priorities, [TaskPriority.low]);
      expect(panels[3].filter.priorities, [TaskPriority.none]);
    });
  });

  group('matchesFilter Pure Function', () {
    final nowUtc = DateTime.utc(2026, 8, 24, 12, 0).millisecondsSinceEpoch;
    final p1 = Project(
      id: 'p1',
      name: '项目1',
      color: 0,
      description: '',
      folderId: 'f1',
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
      deleted: 0,
    );
    final p2 = Project(
      id: 'p2',
      name: '未分组项目',
      color: 0,
      description: '',
      folderId: null,
      sortOrder: 1,
      createdAt: 0,
      updatedAt: 0,
      deleted: 0,
    );
    final projectsById = {'p1': p1, 'p2': p2};

    final task1 = Task(
      id: 'task1',
      projectId: 'p1',
      parentId: null,
      title: '买牛奶',
      description: '全脂牛奶',
      notes: '',
      startAt: null,
      endAt: null,
      status: TaskStatus.todo,
      priority: TaskPriority.high,
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
      deleted: 0,
    );

    final task2 = Task(
      id: 'task2',
      projectId: 'p2',
      parentId: 'task1',
      title: '低脂牛奶',
      description: '',
      notes: '',
      startAt: null,
      endAt: null,
      status: TaskStatus.inProgress,
      priority: TaskPriority.low,
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
      deleted: 0,
    );

    test('folder matching including unassigned', () {
      // 匹配 f1
      expect(
        matchesFilter(
          task1,
          const FilterCriteria(folderIds: ['f1']),
          byId: {'task1': task1},
          directChildren: [],
          projectsById: projectsById,
          taskTagIds: {},
          nowUtcMs: nowUtc,
        ),
        isTrue,
      );

      // task2 在 p2 (folderId == null)，匹配 'unassigned'
      expect(
        matchesFilter(
          task2,
          const FilterCriteria(folderIds: ['unassigned']),
          byId: {'task2': task2},
          directChildren: [],
          projectsById: projectsById,
          taskTagIds: {},
          nowUtcMs: nowUtc,
        ),
        isTrue,
      );
      expect(
        matchesFilter(
          task2,
          const FilterCriteria(folderIds: ['f1']),
          byId: {'task2': task2},
          directChildren: [],
          projectsById: projectsById,
          taskTagIds: {},
          nowUtcMs: nowUtc,
        ),
        isFalse,
      );
    });

    test('project matching', () {
      expect(
        matchesFilter(
          task1,
          const FilterCriteria(projectIds: ['p1']),
          byId: {'task1': task1},
          directChildren: [],
          projectsById: projectsById,
          taskTagIds: {},
          nowUtcMs: nowUtc,
        ),
        isTrue,
      );
      expect(
        matchesFilter(
          task1,
          const FilterCriteria(projectIds: ['p2']),
          byId: {'task1': task1},
          directChildren: [],
          projectsById: projectsById,
          taskTagIds: {},
          nowUtcMs: nowUtc,
        ),
        isFalse,
      );
    });

    test('priority and status matching', () {
      expect(
        matchesFilter(
          task1,
          const FilterCriteria(priorities: [TaskPriority.high]),
          byId: {'task1': task1},
          directChildren: [],
          projectsById: projectsById,
          taskTagIds: {},
          nowUtcMs: nowUtc,
        ),
        isTrue,
      );
      expect(
        matchesFilter(
          task1,
          const FilterCriteria(statuses: [TaskStatus.inProgress]),
          byId: {'task1': task1},
          directChildren: [],
          projectsById: projectsById,
          taskTagIds: {},
          nowUtcMs: nowUtc,
        ),
        isFalse,
      );
    });

    test('tag matching (OR vs AND)', () {
      final taskTags = {'tag1', 'tag2'};
      // OR matching
      expect(
        matchesFilter(
          task1,
          const FilterCriteria(tagIds: ['tag1', 'tag3'], tagMatchAll: false),
          byId: {'task1': task1},
          directChildren: [],
          projectsById: projectsById,
          taskTagIds: taskTags,
          nowUtcMs: nowUtc,
        ),
        isTrue,
      );

      // AND matching - should fail since tag3 not in taskTags
      expect(
        matchesFilter(
          task1,
          const FilterCriteria(tagIds: ['tag1', 'tag3'], tagMatchAll: true),
          byId: {'task1': task1},
          directChildren: [],
          projectsById: projectsById,
          taskTagIds: taskTags,
          nowUtcMs: nowUtc,
        ),
        isFalse,
      );

      // AND matching - should pass
      expect(
        matchesFilter(
          task1,
          const FilterCriteria(tagIds: ['tag1', 'tag2'], tagMatchAll: true),
          byId: {'task1': task1},
          directChildren: [],
          projectsById: projectsById,
          taskTagIds: taskTags,
          nowUtcMs: nowUtc,
        ),
        isTrue,
      );
    });

    test('hierarchy scope matching', () {
      // task1 is root
      expect(
        matchesFilter(
          task1,
          const FilterCriteria(hierarchyScope: HierarchyScopeEnum.rootOnly),
          byId: {'task1': task1},
          directChildren: [],
          projectsById: projectsById,
          taskTagIds: {},
          nowUtcMs: nowUtc,
        ),
        isTrue,
      );
      expect(
        matchesFilter(
          task1,
          const FilterCriteria(hierarchyScope: HierarchyScopeEnum.subtasksOnly),
          byId: {'task1': task1},
          directChildren: [],
          projectsById: projectsById,
          taskTagIds: {},
          nowUtcMs: nowUtc,
        ),
        isFalse,
      );

      // task2 is subtask
      expect(
        matchesFilter(
          task2,
          const FilterCriteria(hierarchyScope: HierarchyScopeEnum.subtasksOnly),
          byId: {'task2': task2},
          directChildren: [],
          projectsById: projectsById,
          taskTagIds: {},
          nowUtcMs: nowUtc,
        ),
        isTrue,
      );
    });
  });

  group('sortPanelTasks', () {
    final t1 = Task(
      id: '1',
      projectId: 'p',
      parentId: null,
      title: 'B task',
      description: '',
      notes: '',
      startAt: null,
      endAt: 2000,
      status: TaskStatus.todo,
      priority: TaskPriority.low,
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 100,
      deleted: 0,
    );
    final t2 = Task(
      id: '2',
      projectId: 'p',
      parentId: null,
      title: 'A task',
      description: '',
      notes: '',
      startAt: null,
      endAt: 1000,
      status: TaskStatus.todo,
      priority: TaskPriority.high,
      sortOrder: 1,
      createdAt: 0,
      updatedAt: 200,
      deleted: 0,
    );

    test('sort by priority desc', () {
      final sorted = sortPanelTasks(
        [t1, t2],
        sortBy: 'priority',
        sortDirection: 'desc',
      );
      expect(sorted.map((t) => t.id).toList(), ['2', '1']);
    });

    test('sort by title asc', () {
      final sorted = sortPanelTasks(
        [t1, t2],
        sortBy: 'title',
        sortDirection: 'asc',
      );
      expect(sorted.map((t) => t.id).toList(), ['2', '1']);
    });

    test('sort by endAt asc', () {
      final sorted = sortPanelTasks(
        [t1, t2],
        sortBy: 'endAt',
        sortDirection: 'asc',
      );
      expect(sorted.map((t) => t.id).toList(), ['2', '1']);
    });
  });
}
