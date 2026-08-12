// 收件箱页测试。
//
// 覆盖：有直接子任务的任务复选框禁用（状态由子任务派生，AGENTS.md §3-2）
// 并显示派生状态 Tooltip；无子任务的任务复选框保持可用。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/repositories/todo_repository.dart';
import 'package:todo/core/db/tables.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/features/tasks/task_list_page.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/features/tags/tag_providers.dart';
import 'package:todo/features/tasks/task_providers.dart';
import 'package:todo/features/tasks/widgets/task_create_sheet.dart';
import '../../helpers/db_test_setup.dart';

/// 构造测试用 Task。
Task _task(
  String id, {
  String? parentId,
  String? title,
  TaskStatus status = TaskStatus.todo,
  int sortOrder = 0,
}) => Task(
  id: id,
  projectId: inboxProjectId,
  parentId: parentId,
  title: title ?? id,
  description: '',
  notes: '',
  status: status,
  sortOrder: sortOrder,
  startAt: null,
  endAt: null,
  priority: TaskPriority.none,
  createdAt: 0,
  updatedAt: 0,
  deleted: 0,
);

/// 封装收件箱页的 ProviderScope + GoRouter。
Future<void> _pumpInbox(
  WidgetTester tester, {
  required List<Task> tasks,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final prefs = await SharedPreferences.getInstance();
  final db = openTestDatabase();
  final repo = TodoRepository(database: db);

  final inboxProject = Project(
    id: inboxProjectId,
    name: '收件箱',
    color: inboxProjectColor,
    description: '',
    sortOrder: 0,
    createdAt: 0,
    updatedAt: 0,
    deleted: 0,
  );

  final router = GoRouter(
    initialLocation: '/inbox',
    routes: [
      GoRoute(
        path: '/inbox',
        builder: (_, _) => const TaskListPage(scope: InboxTaskScope()),
      ),
      GoRoute(
        path: '/task/new',
        builder: (_, state) => Scaffold(
          body: Text('new:${state.uri.queryParameters['projectId']}'),
        ),
      ),
      GoRoute(
        path: '/task/:id',
        builder: (_, state) =>
            Scaffold(body: Text('detail:${state.pathParameters['id']}')),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        todoRepositoryProvider.overrideWithValue(repo),
        inboxProjectProvider.overrideWithValue(AsyncData(inboxProject)),
        inboxTasksProvider.overrideWithValue(AsyncData(tasks)),
        // 新建弹窗 watch 的 drift 流也须覆盖（fake_async 下避免残留 Timer）。
        projectsStreamProvider.overrideWithValue(AsyncData([inboxProject])),
        tagsStreamProvider.overrideWithValue(const AsyncData(<Tag>[])),
      ],
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

/// 定位某任务所在行内嵌的 Checkbox。
Finder _checkboxOf(WidgetTester tester, String title) {
  final inkWell = find
      .ancestor(of: find.text(title), matching: find.byType(InkWell))
      .first;
  return find.descendant(of: inkWell, matching: find.byType(Checkbox));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('收件箱复选框 — 有子任务时禁用', () {
    testWidgets('有直接子任务的任务复选框禁用并显示派生提示', (tester) async {
      final tasks = [
        _task('root', title: '父任务'),
        _task('child', parentId: 'root', title: '子任务', sortOrder: 1),
        _task('leaf', title: '叶子任务', sortOrder: 2),
      ];

      await _pumpInbox(tester, tasks: tasks);

      // 父任务（有直接子任务）复选框禁用。
      final parentCb = _checkboxOf(tester, '父任务');
      expect(parentCb, findsOneWidget);
      expect(tester.widget<Checkbox>(parentCb).onChanged, isNull);

      // 无子任务的叶子任务复选框可用。
      final leafCb = _checkboxOf(tester, '叶子任务');
      expect(leafCb, findsOneWidget);
      expect(tester.widget<Checkbox>(leafCb).onChanged, isNotNull);

      // 派生状态提示 Tooltip 存在（ARB：statusDerivedFromChildren）。
      expect(find.byTooltip('状态由子任务派生'), findsOneWidget);
    });

    testWidgets('无子任务时禁用复选框不存在（仅 1 级任务渲染）', (tester) async {
      await _pumpInbox(tester, tasks: [_task('leaf', title: '叶子任务')]);

      expect(find.byTooltip('状态由子任务派生'), findsNothing);
      final leafCb = _checkboxOf(tester, '叶子任务');
      expect(tester.widget<Checkbox>(leafCb).onChanged, isNotNull);
    });
  });

  group('FAB — 新建任务底部弹窗（D2 定稿）', () {
    testWidgets('点击 FAB 打开 TaskCreateSheet', (tester) async {
      await _pumpInbox(tester, tasks: [_task('leaf', title: '叶子任务')]);

      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // 弹窗打开（不再是全屏 /task/new 路由）。
      expect(find.byType(TaskCreateSheet), findsOneWidget);
      expect(find.text('new:inbox'), findsNothing);
    });

    testWidgets('空态「添加任务」按钮同样打开弹窗', (tester) async {
      await _pumpInbox(tester, tasks: []);

      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.tap(find.text('添加任务'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskCreateSheet), findsOneWidget);
    });
  });
}
