// M2 task tree & expand/collapse & derived status tests.
//
// Covers DoD: multi-level tree rendering, expand/collapse, empty state, derived status badge.
// Pure function tests: buildTreeNodes / TreeExpandNotifier / derivedStatus / progress.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/tables.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/core/utils/derived.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/features/tasks/task_providers.dart';
import 'package:todo/features/tasks/widgets/task_row.dart';
import 'package:todo/features/tasks/widgets/task_tree.dart';
import '../../helpers/db_test_setup.dart';

Task _task(
  String id, {
  String projectId = 'p1',
  String? parentId,
  String? title,
  TaskStatus status = TaskStatus.todo,
  int sortOrder = 0,
}) => Task(
  id: id,
  projectId: projectId,
  parentId: parentId,
  title: title ?? id,
  description: '',
  notes: '',
  status: status,
  sortOrder: sortOrder,
  createdAt: 0,
  updatedAt: 0,
  deleted: 0,
);

/// 测试用 TreeExpandNotifier，build() 返回预设展开状态。
class _TestTreeExpandNotifier extends TreeExpandNotifier {
  _TestTreeExpandNotifier(this._initial);
  final Map<String, bool> _initial;
  @override
  Map<String, bool> build() => _initial;
}

Future<void> _pumpTree(
  WidgetTester tester,
  List<Task> tasks, {
  Map<String, bool> expandState = const {},
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final prefs = await SharedPreferences.getInstance();
  final db = openTestDatabase();
  final repo = TodoRepository(database: db);
  // 预插入项目（满足 FK 约束）。
  await db
      .into(db.projects)
      .insertOnConflictUpdate(
        ProjectsCompanion.insert(
          id: 'p1',
          name: 'P1',
          color: 0,
          sortOrder: 0,
          createdAt: 0,
          updatedAt: 0,
        ),
      );
  final overrides = [
    sharedPreferencesProvider.overrideWithValue(prefs),
    todoRepositoryProvider.overrideWithValue(repo),
    projectsStreamProvider.overrideWithValue(
      AsyncData([
        Project(
          id: 'p1',
          name: 'P1',
          color: 0,
          sortOrder: 0,
          createdAt: 0,
          updatedAt: 0,
          deleted: 0,
        ),
      ]),
    ),
    projectTasksProvider.overrideWith((ref, projectId) => Stream.value(tasks)),
    treeExpandProvider.overrideWith2(
      (arg) => _TestTreeExpandNotifier(expandState),
    ),
  ];
  final router = GoRouter(
    initialLocation: '/projects/p1',
    routes: [
      GoRoute(
        path: '/projects/:id',
        builder: (_, state) =>
            Scaffold(body: TaskTree(projectId: state.pathParameters['id']!)),
      ),
      GoRoute(path: '/task/new', builder: (_, _) => const Scaffold()),
      GoRoute(path: '/task/:id', builder: (_, _) => const Scaffold()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('buildTreeNodes', () {
    test('empty list', () {
      expect(buildTreeNodes(tasks: [], expandState: {}), isEmpty);
    });
    test('single root', () {
      final n = buildTreeNodes(tasks: [_task('t1')], expandState: {});
      expect(n.length, 1);
      expect(n[0].depth, 0);
      expect(n[0].hasChildren, isFalse);
    });
    test('parent-child', () {
      final n = buildTreeNodes(
        tasks: [
          _task('r'),
          _task('c', parentId: 'r', sortOrder: 1),
        ],
        expandState: {},
      );
      expect(n.length, 2);
      expect(n[0].hasChildren, isTrue);
      expect(n[1].depth, 1);
    });
    test('collapse hides children', () {
      final n = buildTreeNodes(
        tasks: [
          _task('r'),
          _task('c', parentId: 'r', sortOrder: 1),
        ],
        expandState: {'r': false},
      );
      expect(n.length, 1);
      expect(n[0].isExpanded, isFalse);
    });
    test('3-level tree', () {
      final n = buildTreeNodes(
        tasks: [
          _task('a'),
          _task('b', parentId: 'a', sortOrder: 0),
          _task('c', parentId: 'b', sortOrder: 0),
        ],
        expandState: {},
      );
      expect(n.length, 3);
      expect(n[0].depth, 0);
      expect(n[1].depth, 1);
      expect(n[2].depth, 2);
    });
    test('sort by sortOrder', () {
      final n = buildTreeNodes(
        tasks: [
          _task('a', sortOrder: 2),
          _task('b', parentId: 'a', sortOrder: 1),
          _task('c', parentId: 'a', sortOrder: 0),
        ],
        expandState: {},
      );
      expect(n[1].task.id, 'c');
      expect(n[2].task.id, 'b');
    });
  });

  group('TreeExpandNotifier', () {
    test('default all expanded', () {
      final container = ProviderContainer(
        overrides: [
          treeExpandProvider.overrideWith2((_) => _TestTreeExpandNotifier({})),
        ],
      );
      addTearDown(container.dispose);
      final n = container.read(treeExpandProvider('p1').notifier);
      expect(n.isExpanded('x'), isTrue);
    });
    test('toggle', () {
      final container = ProviderContainer(
        overrides: [
          treeExpandProvider.overrideWith2((_) => _TestTreeExpandNotifier({})),
        ],
      );
      addTearDown(container.dispose);
      final n = container.read(treeExpandProvider('p1').notifier);
      n.toggle('t1');
      expect(n.isExpanded('t1'), isFalse);
      n.toggle('t1');
      expect(n.isExpanded('t1'), isTrue);
    });
    test('expandAll', () {
      final container = ProviderContainer(
        overrides: [
          treeExpandProvider.overrideWith2(
            (_) => _TestTreeExpandNotifier({'t1': false}),
          ),
        ],
      );
      addTearDown(container.dispose);
      final n = container.read(treeExpandProvider('p1').notifier);
      n.expandAll(['t1', 't2']);
      expect(n.isExpanded('t1'), isTrue);
    });
    test('collapseAll clears', () {
      final container = ProviderContainer(
        overrides: [
          treeExpandProvider.overrideWith2(
            (_) => _TestTreeExpandNotifier({'t1': true}),
          ),
        ],
      );
      addTearDown(container.dispose);
      final n = container.read(treeExpandProvider('p1').notifier);
      n.collapseAll();
      expect(n.state, isEmpty);
    });
  });

  group('TaskTree widget', () {
    testWidgets('empty state', (tester) async {
      await _pumpTree(tester, []);
      expect(find.textContaining('还没有任务'), findsOneWidget);
      expect(find.byIcon(Icons.checklist_outlined), findsOneWidget);
    });
    testWidgets('single root renders TaskRow', (tester) async {
      await _pumpTree(tester, [_task('t1', title: 'Task1')]);
      expect(find.text('Task1'), findsOneWidget);
      expect(find.byType(TaskRow), findsOneWidget);
    });
    testWidgets('parent+child renders 2 TaskRows', (tester) async {
      await _pumpTree(tester, [
        _task('r', title: 'Root'),
        _task('c', parentId: 'r', title: 'Child', sortOrder: 1),
      ]);
      expect(find.byType(TaskRow), findsNWidgets(2));
    });
    testWidgets('3-level tree renders 3 TaskRows', (tester) async {
      await _pumpTree(tester, [
        _task('a', title: 'A'),
        _task('b', parentId: 'a', title: 'B', sortOrder: 1),
        _task('c', parentId: 'b', title: 'C', sortOrder: 1),
      ]);
      expect(find.byType(TaskRow), findsNWidgets(3));
    });
    testWidgets('collapse hides children', (tester) async {
      await _pumpTree(
        tester,
        [
          _task('r', title: 'Root'),
          _task('c', parentId: 'r', title: 'Child', sortOrder: 1),
        ],
        expandState: {'r': false},
      );
      expect(find.text('Root'), findsOneWidget);
      expect(find.text('Child'), findsNothing);
      expect(find.byType(TaskRow), findsOneWidget);
    });
  });

  group('derived status badge', () {
    testWidgets('all done children show check_circle', (tester) async {
      await _pumpTree(tester, [
        _task('r', title: 'P'),
        _task(
          'c1',
          parentId: 'r',
          title: 'C1',
          status: TaskStatus.done,
          sortOrder: 1,
        ),
        _task(
          'c2',
          parentId: 'r',
          title: 'C2',
          status: TaskStatus.done,
          sortOrder: 2,
        ),
      ]);
      expect(find.byIcon(Icons.check_circle), findsWidgets);
    });
    testWidgets('inProgress child shows radio_button_checked', (tester) async {
      await _pumpTree(tester, [
        _task('r', title: 'P'),
        _task(
          'c1',
          parentId: 'r',
          title: 'C1',
          status: TaskStatus.done,
          sortOrder: 1,
        ),
        _task(
          'c2',
          parentId: 'r',
          title: 'C2',
          status: TaskStatus.inProgress,
          sortOrder: 2,
        ),
      ]);
      expect(find.byIcon(Icons.radio_button_checked), findsWidgets);
    });
    testWidgets('leaf node has null derivedStatus', (tester) async {
      await _pumpTree(tester, [
        _task('r', title: 'P'),
        _task('c', parentId: 'r', title: 'C', sortOrder: 1),
      ]);
      final rows = tester.widgetList<TaskRow>(find.byType(TaskRow));
      final childRow = rows.firstWhere((r) => r.task.id == 'c');
      expect(childRow.derivedStatus, isNull);
    });
  });

  group('expand/collapse interaction', () {
    testWidgets('tap arrow collapses children', (tester) async {
      await _pumpTree(tester, [
        _task('r', title: 'Root'),
        _task('c', parentId: 'r', title: 'Child', sortOrder: 1),
      ]);
      expect(find.text('Child'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_right).first);
      await tester.pumpAndSettle();
      expect(find.text('Child'), findsNothing);
    });
    testWidgets('tap again expands', (tester) async {
      await _pumpTree(tester, [
        _task('r', title: 'Root'),
        _task('c', parentId: 'r', title: 'Child', sortOrder: 1),
      ]);
      await tester.tap(find.byIcon(Icons.arrow_right).first);
      await tester.pumpAndSettle();
      expect(find.text('Child'), findsNothing);
      await tester.tap(find.byIcon(Icons.arrow_right).first);
      await tester.pumpAndSettle();
      expect(find.text('Child'), findsOneWidget);
    });
  });

  group('derivedStatus integration', () {
    test('no children returns parent status', () {
      expect(
        derivedStatus(_task('r', status: TaskStatus.inProgress), []),
        TaskStatus.inProgress,
      );
    });
    test('all done children -> done', () {
      expect(
        derivedStatus(_task('r', status: TaskStatus.todo), [
          _task('c1', status: TaskStatus.done),
        ]),
        TaskStatus.done,
      );
    });
    test('inProgress child takes priority', () {
      expect(
        derivedStatus(_task('r'), [
          _task('c1', status: TaskStatus.done),
          _task('c2', status: TaskStatus.inProgress),
        ]),
        TaskStatus.inProgress,
      );
    });
    test('progress calculation', () {
      final r = _task('r', status: TaskStatus.todo);
      expect(
        progress(r, [
          r,
          _task('c1', status: TaskStatus.done),
          _task('c2', status: TaskStatus.todo),
        ]),
        closeTo(1 / 3, 1e-9),
      );
    });
  });
}
