// M2 task tree & expand/collapse & derived status tests.
//
// Covers DoD: multi-level tree rendering, expand/collapse, empty state, derived status badge.
// Pure function tests: buildTreeNodes / TreeExpandNotifier / derivedStatus / progress.

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:drift/drift.dart' show Value;
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

/// 拖拽测试专用 pump：任务真实写入 DB（moveTask 会落库），
/// 返回 repo 供断言。
Future<TodoRepository> _pumpTreeWithDb(
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
  for (final task in tasks) {
    await db
        .into(db.tasks)
        .insertOnConflictUpdate(
          TasksCompanion.insert(
            id: task.id,
            projectId: task.projectId,
            parentId: Value(task.parentId),
            title: task.title,
            status: task.status,
            sortOrder: task.sortOrder,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
          ),
        );
  }
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
  return repo;
}

/// 长按任务行并拖到 [target] 行指定纵向位置（dy 为目标**行**高度的比例，0~1）。
Future<void> _dragToRow(
  WidgetTester tester,
  String draggedTitle,
  String targetTitle,
  double dyRatio,
) async {
  final dragStart = tester.getCenter(find.text(draggedTitle));
  final targetRow = find.ancestor(
    of: find.text(targetTitle),
    matching: find.byType(TaskRow),
  );
  final targetRect = tester.getRect(targetRow);
  final targetPoint = Offset(
    targetRect.center.dx,
    targetRect.top + targetRect.height * dyRatio,
  );
  final gesture = await tester.startGesture(dragStart);
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await gesture.moveTo(targetPoint);
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.up();
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

  group('拖拽调级/排序（Bug 3 回归）', () {
    testWidgets('拖到目标行下半 → 成为其子级', (tester) async {
      final repo = await _pumpTreeWithDb(tester, [
        _task('a', title: 'A', sortOrder: 0),
        _task('b', title: 'B', sortOrder: 1),
      ]);

      // A 拖到 B 的下半（成为子级）。
      await _dragToRow(tester, 'A', 'B', 0.8);

      final after = await repo.tasks.getByProject('p1');
      final a = after.firstWhere((t) => t.id == 'a');
      expect(a.parentId, 'b');
    });

    testWidgets('拖到目标行上半 → 同级排序（插到目标前）', (tester) async {
      final repo = await _pumpTreeWithDb(tester, [
        _task('a', title: 'A', sortOrder: 0),
        _task('b', title: 'B', sortOrder: 1),
        _task('c', title: 'C', sortOrder: 2),
      ]);

      // C 拖到 A 的上半（同级，插到 A 前）。
      await _dragToRow(tester, 'C', 'A', 0.2);

      final after = await repo.tasks.getByProject('p1');
      final a = after.firstWhere((t) => t.id == 'a');
      final c = after.firstWhere((t) => t.id == 'c');
      expect(c.parentId, isNull);
      expect(c.sortOrder, lessThan(a.sortOrder));
    });

    testWidgets('拖到列表末尾"回到 1 级"落点 → parentId=null', (tester) async {
      final repo = await _pumpTreeWithDb(tester, [
        _task('a', title: 'A', sortOrder: 0),
        _task('b', title: 'B', parentId: 'a', sortOrder: 0),
      ]);

      // 长按 B（子级）后拖到底部空白落点区。
      final dragStart = tester.getCenter(find.text('B'));
      final gesture = await tester.startGesture(dragStart);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      // 拖拽开始后列表末尾出现"回到 1 级"落点。
      await tester.pump(const Duration(milliseconds: 50));
      final dropZone = find.textContaining('回到 1 级');
      expect(dropZone, findsOneWidget);
      await gesture.moveTo(tester.getCenter(dropZone));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      final after = await repo.tasks.getByProject('p1');
      final b = after.firstWhere((t) => t.id == 'b');
      expect(b.parentId, isNull);
      expect(b.sortOrder, 1); // 追加到 1 级末尾。
    });

    testWidgets('拖到自身 → 不产生移动', (tester) async {
      final repo = await _pumpTreeWithDb(tester, [
        _task('a', title: 'A', sortOrder: 0),
        _task('b', title: 'B', sortOrder: 1),
      ]);

      await _dragToRow(tester, 'A', 'A', 0.5);

      final after = await repo.tasks.getByProject('p1');
      final a = after.firstWhere((t) => t.id == 'a');
      expect(a.parentId, isNull);
      expect(a.sortOrder, 0);
    });

    testWidgets('拖到自己的后代 → 防环拒绝，不产生移动', (tester) async {
      final repo = await _pumpTreeWithDb(tester, [
        _task('a', title: 'A', sortOrder: 0),
        _task('b', title: 'B', parentId: 'a', sortOrder: 0),
        _task('c', title: 'C', parentId: 'b', sortOrder: 0),
      ]);

      // A 拖到其孙级 C 上（下半=成为 C 的子级 → 环）。
      await _dragToRow(tester, 'A', 'C', 0.8);

      final after = await repo.tasks.getByProject('p1');
      final a = after.firstWhere((t) => t.id == 'a');
      expect(a.parentId, isNull);
      final c = after.firstWhere((t) => t.id == 'c');
      expect(c.parentId, 'b'); // 结构未变。
    });

    testWidgets('深度守卫：把 2 级子树拖到第 2 层目标下 → 拒绝', (tester) async {
      final repo = await _pumpTreeWithDb(tester, [
        _task('a', title: 'A', sortOrder: 0),
        _task('b', title: 'B', sortOrder: 1),
        _task('c', title: 'C', parentId: 'b', sortOrder: 0),
      ]);

      // A（带自身共 1 层）拖到 C 下半 → 成为 C 的子级：深度 2+1=3 合法。
      await _dragToRow(tester, 'A', 'C', 0.8);
      var after = await repo.tasks.getByProject('p1');
      expect(after.firstWhere((t) => t.id == 'a').parentId, 'c');

      // 现在结构：b(1级) → c(2级) → a(3级)。把根级 b 的子树
      // （b 已含 c+a，subtree 深度 3）拖到…… 同级/子级都会超限：
      // 拖 b 到 a 的下半（成为 a 的子级 → 深度 3+3=6 > 3）→ 拒绝。
      await _dragToRow(tester, 'B', 'A', 0.8);
      after = await repo.tasks.getByProject('p1');
      expect(after.firstWhere((t) => t.id == 'b').parentId, isNull);
      expect(after.firstWhere((t) => t.id == 'a').parentId, 'c'); // 未变。
    });
  });
}
