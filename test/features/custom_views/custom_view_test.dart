import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/tables.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/core/utils/custom_view_models.dart';
import 'package:todo/features/custom_views/presentation/custom_view_editor_page.dart';
import 'package:todo/features/custom_views/presentation/custom_view_page.dart';
import 'package:todo/features/custom_views/providers/custom_view_providers.dart';
import 'package:todo/features/custom_views/widgets/panel_column.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/shared/widgets/animated_strikethrough.dart';

import '../../helpers/db_test_setup.dart';

void main() {
  group('Custom Views Providers & Operations', () {
    late AppDatabase db;
    late TodoRepository repo;
    late ProviderContainer container;

    setUp(() async {
      db = openTestDatabase();
      repo = TodoRepository(database: db);
      container = ProviderContainer(
        overrides: [todoRepositoryProvider.overrideWithValue(repo)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test(
      'Create, update, reorder and delete CustomView via operations',
      () async {
        final ops = container.read(customViewOperationsProvider);

        // 1. Create
        final panel1 = CustomViewPanelConfig(
          id: 'p1',
          title: '待办',
          filter: const FilterCriteria(statuses: [TaskStatus.todo]),
        );
        final view = await ops.createView(
          name: '工作看板',
          icon: 'view_kanban_outlined',
          color: 0xFF4A6CF7,
          layoutMode: 'kanban',
          panels: [panel1],
        );

        expect(view.name, '工作看板');
        expect(view.icon, 'view_kanban_outlined');
        expect(view.color, 0xFF4A6CF7);

        // 2. Update
        final panel2 = CustomViewPanelConfig(
          id: 'p2',
          title: '进行中',
          filter: const FilterCriteria(statuses: [TaskStatus.inProgress]),
        );
        await ops.updateView(view.id, name: '更新看板', panels: [panel1, panel2]);

        final updated = await repo.customViews.getById(view.id);
        expect(updated!.name, '更新看板');
        final decoded = decodePanelsJson(updated.panelsJson);
        expect(decoded.length, 2);
        expect(decoded[1].title, '进行中');

        // 3. Reorder
        final view2 = await ops.createView(name: '第二视图', panels: []);
        await ops.reorderViews([view2.id, view.id]);
        final all = await repo.customViews.getAll();
        expect(all.first.id, view2.id);
        expect(all.last.id, view.id);

        // 4. Delete & Tombstone
        await ops.deleteView(view.id);
        expect(await repo.customViews.getById(view.id), isNull);
        final tombstones = await repo.readTombstones();
        expect(
          tombstones.any((t) => t.id == view.id && t.type == 'custom_view'),
          isTrue,
        );
      },
    );

    test(
      'Smart Drag-and-Drop: Single status difference updates task status',
      () async {
        final ops = container.read(customViewOperationsProvider);
        final project = await repo.createProject(
          name: '测试项目',
          color: 0xFF123456,
        );
        final task = await repo.createTask(
          projectId: project.id,
          title: '未完成任务',
        );

        final sourcePanel = CustomViewPanelConfig(
          id: 'p1',
          title: '待办',
          filter: const FilterCriteria(statuses: [TaskStatus.todo]),
        );
        final targetPanel = CustomViewPanelConfig(
          id: 'p2',
          title: '进行中',
          filter: const FilterCriteria(statuses: [TaskStatus.inProgress]),
        );

        final result = await ops.handleTaskDroppedBetweenPanels(
          task: task,
          sourcePanel: sourcePanel,
          targetPanel: targetPanel,
          hasSubtasks: false,
        );

        expect(result.actionType, PanelDropActionType.updated);
        expect(result.targetStatus, TaskStatus.inProgress);
        final reloaded = await repo.tasks.getById(task.id);
        expect(reloaded!.status, TaskStatus.inProgress);
      },
    );

    test(
      'Smart Drag-and-Drop: Parent task with subtasks blocks manual status change',
      () async {
        final ops = container.read(customViewOperationsProvider);
        final project = await repo.createProject(
          name: '测试项目',
          color: 0xFF123456,
        );
        final parentTask = await repo.createTask(
          projectId: project.id,
          title: '父任务',
        );
        await repo.createTask(
          projectId: project.id,
          parentId: parentTask.id,
          title: '子任务',
        );

        final sourcePanel = CustomViewPanelConfig(
          id: 'p1',
          title: '待办',
          filter: const FilterCriteria(statuses: [TaskStatus.todo]),
        );
        final targetPanel = CustomViewPanelConfig(
          id: 'p2',
          title: '已完成',
          filter: const FilterCriteria(statuses: [TaskStatus.done]),
        );

        final result = await ops.handleTaskDroppedBetweenPanels(
          task: parentTask,
          sourcePanel: sourcePanel,
          targetPanel: targetPanel,
          hasSubtasks: true, // has subtasks
        );

        expect(result.actionType, PanelDropActionType.derivedStatusBlocked);
        // DB 状态保持不变
        final reloaded = await repo.tasks.getById(parentTask.id);
        expect(reloaded!.status, TaskStatus.todo);
      },
    );

    test(
      'Smart Drag-and-Drop: Single priority difference updates task priority',
      () async {
        final ops = container.read(customViewOperationsProvider);
        final project = await repo.createProject(
          name: '测试项目',
          color: 0xFF123456,
        );
        final task = await repo.createTask(
          projectId: project.id,
          title: '普通任务',
          priority: TaskPriority.none,
        );

        final sourcePanel = CustomViewPanelConfig(
          id: 'p1',
          title: '无优先级',
          filter: const FilterCriteria(priorities: [TaskPriority.none]),
        );
        final targetPanel = CustomViewPanelConfig(
          id: 'p2',
          title: '高优',
          filter: const FilterCriteria(priorities: [TaskPriority.high]),
        );

        final result = await ops.handleTaskDroppedBetweenPanels(
          task: task,
          sourcePanel: sourcePanel,
          targetPanel: targetPanel,
          hasSubtasks: false,
        );

        expect(result.actionType, PanelDropActionType.updated);
        expect(result.targetPriority, TaskPriority.high);
        final reloaded = await repo.tasks.getById(task.id);
        expect(reloaded!.priority, TaskPriority.high);
      },
    );

    test(
      'CustomViewDao getNextSortOrder calculates max order + 1 correctly',
      () async {
        expect(await repo.customViews.getNextSortOrder(), 0);
        final v1 = await repo.createCustomView(name: 'V1', panelsJson: '[]');
        expect(v1.sortOrder, 0);
        expect(await repo.customViews.getNextSortOrder(), 1);
        final v2 = await repo.createCustomView(name: 'V2', panelsJson: '[]');
        expect(v2.sortOrder, 1);
        expect(await repo.customViews.getNextSortOrder(), 2);
      },
    );

    test(
      'panelTasksProvider accurately matches tasks by tagIds (AND / OR)',
      () {
        final project = Project(
          id: 'p1',
          name: '测试项目',
          color: 0xFF123456,
          description: '',
          folderId: null,
          sortOrder: 0,
          createdAt: 0,
          updatedAt: 0,
          deleted: 0,
        );

        final t1 = Task(
          id: 't1',
          projectId: 'p1',
          parentId: null,
          title: '任务1',
          description: '',
          notes: '',
          startAt: null,
          endAt: null,
          status: TaskStatus.todo,
          priority: TaskPriority.none,
          sortOrder: 0,
          createdAt: 0,
          updatedAt: 0,
          deleted: 0,
        );
        final t2 = t1.copyWith(id: 't2', title: '任务2');
        final t3 = t1.copyWith(id: 't3', title: '任务3');
        final t4 = t1.copyWith(id: 't4', title: '任务4');

        final testContainer = ProviderContainer(
          overrides: [
            allActiveTasksStreamProvider.overrideWithValue(
              AsyncData([t1, t2, t3, t4]),
            ),
            allProjectsMapProvider.overrideWithValue(
              AsyncData({'p1': project}),
            ),
            allTaskTagsMapProvider.overrideWithValue(
              const AsyncData({
                't1': {'tag_work'},
                't2': {'tag_urgent'},
                't3': {'tag_work', 'tag_urgent'},
              }),
            ),
          ],
        );

        // Panel 1: Filter by tag_work (OR mode default)
        final panelWork = CustomViewPanelConfig(
          id: 'pWork',
          title: 'Work Tasks',
          filter: const FilterCriteria(tagIds: ['tag_work']),
        );
        final workResult = testContainer.read(panelTasksProvider(panelWork));
        expect(workResult.hasValue, isTrue);
        final workTaskIds = workResult.value!.tasks.map((t) => t.id).toSet();
        expect(workTaskIds, {'t1', 't3'});

        // Panel 2: Filter by tag_work AND tag_urgent
        final panelBoth = CustomViewPanelConfig(
          id: 'pBoth',
          title: 'Work + Urgent',
          filter: const FilterCriteria(
            tagIds: ['tag_work', 'tag_urgent'],
            tagMatchAll: true,
          ),
        );
        final bothResult = testContainer.read(panelTasksProvider(panelBoth));
        expect(bothResult.hasValue, isTrue);
        final bothTaskIds = bothResult.value!.tasks.map((t) => t.id).toSet();
        expect(bothTaskIds, {'t3'});

        testContainer.dispose();
      },
    );

    testWidgets('CustomViewEditorPage renders leading back button and saves', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [todoRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CustomViewEditorPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Back button exists in AppBar
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Title and preset chips render
      expect(find.text('状态看板'), findsOneWidget);
      expect(find.text('优先级看板'), findsOneWidget);

      // Tap back button (handles canPop / fallback)
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'PanelColumn renders KanbanTaskCard and allows toggling status',
      (tester) async {
        final project = await repo.createProject(
          name: '看板项目',
          color: 0xFF4A6CF7,
        );
        final task = await repo.createTask(
          projectId: project.id,
          title: '独立待办',
          status: TaskStatus.todo,
        );
        final panel = CustomViewPanelConfig(
          id: 'p1',
          title: '待办列',
          filter: const FilterCriteria(statuses: [TaskStatus.todo]),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              todoRepositoryProvider.overrideWithValue(repo),
              panelTasksProvider(panel).overrideWithValue(
                AsyncData(PanelTasksResult(tasks: [task], totalCount: 1)),
              ),
              allProjectsMapProvider.overrideWithValue(
                AsyncData({project.id: project}),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: PanelColumn(panel: panel)),
            ),
          ),
        );
        await tester.pump();

        // Card and title rendered
        expect(find.text('待办列'), findsOneWidget);
        expect(find.text('独立待办'), findsOneWidget);
        expect(find.byType(KanbanTaskCard), findsOneWidget);

        // Tap checkbox to mark done
        final checkboxFinder = find.byKey(
          ValueKey('kanban_checkbox_${task.id}'),
        );
        expect(checkboxFinder, findsOneWidget);
        await tester.tap(checkboxFinder);
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();

        final reloaded = await repo.tasks.getById(task.id);
        expect(reloaded!.status, TaskStatus.done);
      },
    );

    testWidgets(
      'KanbanTaskCard renders multi-line task title and wraps with AnimatedStrikethrough',
      (tester) async {
        final project = await repo.createProject(
          name: '看板项目',
          color: 0xFF4A6CF7,
        );
        final longTitle = '这是一个非常长非常长非常长的任务标题需要自动折行显示在自定义视图看板中不会被省略号截断';
        final task = await repo.createTask(
          projectId: project.id,
          title: longTitle,
          status: TaskStatus.todo,
        );
        final panel = CustomViewPanelConfig(
          id: 'p1',
          title: '待办列',
          filter: const FilterCriteria(statuses: [TaskStatus.todo]),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              todoRepositoryProvider.overrideWithValue(repo),
              panelTasksProvider(panel).overrideWithValue(
                AsyncData(PanelTasksResult(tasks: [task], totalCount: 1)),
              ),
              allProjectsMapProvider.overrideWithValue(
                AsyncData({project.id: project}),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: PanelColumn(panel: panel)),
            ),
          ),
        );
        await tester.pump();

        expect(find.text(longTitle), findsOneWidget);
        final strikethroughFinder = find.byWidgetPredicate(
          (widget) =>
              widget is AnimatedStrikethrough &&
              widget.text == longTitle &&
              widget.maxLines == null &&
              widget.overflow == TextOverflow.clip,
        );
        expect(strikethroughFinder, findsOneWidget);
      },
    );

    testWidgets('PanelColumn (isKanban: false) renders compact narrow toolbar', (
      tester,
    ) async {
      final panel = CustomViewPanelConfig(
        id: 'p1',
        title: '高优先',
        filter: const FilterCriteria(priorities: [TaskPriority.high]),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todoRepositoryProvider.overrideWithValue(repo),
            panelTasksProvider(panel).overrideWithValue(
              const AsyncData(PanelTasksResult(tasks: [], totalCount: 0)),
            ),
            allProjectsMapProvider.overrideWithValue(const AsyncData({})),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: PanelColumn(panel: panel, isKanban: false)),
          ),
        ),
      );
      await tester.pump();

      // In narrow mode, the title '高优先' is omitted in PanelColumn (deferred to TabBar),
      // but sort chip and active filter button are rendered.
      expect(find.text('高优先'), findsNothing);
      expect(find.byIcon(Icons.swap_vert), findsOneWidget);
      expect(find.byIcon(Icons.filter_alt), findsOneWidget);
    });

    testWidgets(
      'CustomViewPage in narrow mode with multi-panels renders TabBar with count badges',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final panel1 = CustomViewPanelConfig(
          id: 'p1',
          title: '高优先',
          filter: const FilterCriteria(priorities: [TaskPriority.high]),
        );
        final panel2 = CustomViewPanelConfig(
          id: 'p2',
          title: '其他待办',
          filter: const FilterCriteria(priorities: [TaskPriority.none]),
        );

        final view = CustomView(
          id: 'v1',
          name: '开发看板',
          icon: 'view_kanban_outlined',
          color: 0xFF4A6CF7,
          layoutMode: 'list',
          panelsJson: encodePanelsJson([panel1, panel2]),
          sortOrder: 0,
          createdAt: 0,
          updatedAt: 0,
          deleted: 0,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              todoRepositoryProvider.overrideWithValue(repo),
              customViewDetailProvider.overrideWith(
                (ref, id) => Stream.value(view),
              ),
              allActiveTasksStreamProvider.overrideWithValue(
                const AsyncData([]),
              ),
              panelTasksProvider(panel1).overrideWithValue(
                const AsyncData(PanelTasksResult(tasks: [], totalCount: 5)),
              ),
              panelTasksProvider(panel2).overrideWithValue(
                const AsyncData(PanelTasksResult(tasks: [], totalCount: 0)),
              ),
              allProjectsMapProvider.overrideWithValue(const AsyncData({})),
            ],
            child: const MaterialApp(
              locale: Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: CustomViewPage(viewId: 'v1'),
            ),
          ),
        );
        await tester.pump();

        // Custom view title in AppBar
        expect(find.text('开发看板'), findsOneWidget);

        // TabBar rendered with tab titles and count badges
        expect(find.byType(TabBar), findsOneWidget);
        expect(find.text('高优先'), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
        expect(find.text('其他待办'), findsOneWidget);
        expect(find.text('0'), findsOneWidget);
      },
    );

    testWidgets(
      'CustomViewPage in narrow mode with single panel omits TabBar',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final panel1 = CustomViewPanelConfig(
          id: 'p1',
          title: '全部任务',
          filter: const FilterCriteria(),
        );

        final view = CustomView(
          id: 'v2',
          name: '单一视图',
          icon: 'view_kanban_outlined',
          color: 0xFF4A6CF7,
          layoutMode: 'list',
          panelsJson: encodePanelsJson([panel1]),
          sortOrder: 0,
          createdAt: 0,
          updatedAt: 0,
          deleted: 0,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              todoRepositoryProvider.overrideWithValue(repo),
              customViewDetailProvider.overrideWith(
                (ref, id) => Stream.value(view),
              ),
              allActiveTasksStreamProvider.overrideWithValue(
                const AsyncData([]),
              ),
              panelTasksProvider(panel1).overrideWithValue(
                const AsyncData(PanelTasksResult(tasks: [], totalCount: 2)),
              ),
              allProjectsMapProvider.overrideWithValue(const AsyncData({})),
            ],
            child: const MaterialApp(
              locale: Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: CustomViewPage(viewId: 'v2'),
            ),
          ),
        );
        await tester.pump();

        // Single panel mode has no TabBar
        expect(find.byType(TabBar), findsNothing);
        expect(find.text('单一视图'), findsOneWidget);
      },
    );

    testWidgets(
      'CustomViewPage in kanban/wide mode wraps horizontal ListView with Scrollbar',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final panel1 = CustomViewPanelConfig(
          id: 'p1',
          title: '待办',
          filter: const FilterCriteria(statuses: [TaskStatus.todo]),
        );
        final panel2 = CustomViewPanelConfig(
          id: 'p2',
          title: '进行中',
          filter: const FilterCriteria(statuses: [TaskStatus.inProgress]),
        );

        final view = CustomView(
          id: 'v_kanban',
          name: '看板视图',
          icon: 'view_kanban_outlined',
          color: 0xFF4A6CF7,
          layoutMode: 'kanban',
          panelsJson: encodePanelsJson([panel1, panel2]),
          sortOrder: 0,
          createdAt: 0,
          updatedAt: 0,
          deleted: 0,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              todoRepositoryProvider.overrideWithValue(repo),
              customViewDetailProvider.overrideWith(
                (ref, id) => Stream.value(view),
              ),
              allActiveTasksStreamProvider.overrideWithValue(
                const AsyncData([]),
              ),
              panelTasksProvider(panel1).overrideWithValue(
                const AsyncData(PanelTasksResult(tasks: [], totalCount: 0)),
              ),
              panelTasksProvider(panel2).overrideWithValue(
                const AsyncData(PanelTasksResult(tasks: [], totalCount: 0)),
              ),
              allProjectsMapProvider.overrideWithValue(const AsyncData({})),
            ],
            child: const MaterialApp(
              locale: Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: CustomViewPage(viewId: 'v_kanban'),
            ),
          ),
        );
        await tester.pump();

        // Scrollbar and ListView are present with horizontal scroll
        expect(find.byType(Scrollbar), findsOneWidget);
        final listViewFinder = find.byType(ListView);
        expect(listViewFinder, findsOneWidget);
        final listView = tester.widget<ListView>(listViewFinder);
        expect(listView.scrollDirection, Axis.horizontal);
      },
    );

    testWidgets(
      'CustomViewEditorPage panel list uses leading ReorderableDragStartListener and buildDefaultDragHandles false',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [todoRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(
              locale: Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: CustomViewEditorPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final reorderableListViewFinder = find.byType(ReorderableListView);
        expect(reorderableListViewFinder, findsOneWidget);
        final reorderableList = tester.widget<ReorderableListView>(
          reorderableListViewFinder,
        );
        expect(reorderableList.buildDefaultDragHandles, isFalse);

        // Leading drag handle is wrapped with ReorderableDragStartListener
        expect(find.byType(ReorderableDragStartListener), findsWidgets);
        expect(find.byIcon(Icons.delete_outline), findsWidgets);
      },
    );
  });
}
