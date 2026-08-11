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
import 'package:todo/features/inbox/inbox_page.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/features/tasks/task_providers.dart';
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
    sortOrder: 0,
    createdAt: 0,
    updatedAt: 0,
    deleted: 0,
  );

  final router = GoRouter(
    initialLocation: '/inbox',
    routes: [
      GoRoute(path: '/inbox', builder: (_, _) => const InboxPage()),
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
}
