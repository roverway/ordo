// 收件箱页测试。
//
// Bug 3 修复后 /inbox 渲染 `TaskTree(projectId: inboxProjectId)`（与项目页一致，
// 不再有旧版扁平列表）。任务树行为由 task_tree_test.dart 覆盖，本文件只验证：
// /inbox 接入树形渲染、FAB 打开 TaskCreateSheet、空收件箱保留 FAB（空态文案
// 「还没有任务，点击下方按钮新建」依赖底部新建入口）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

/// 构造测试用 Task（一律落在内置收件箱项目下）。
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
///
/// 任务数据走 `projectTasksProvider(inboxProjectId)`（TaskTree 消费的 family）。
Future<void> _pumpInbox(
  WidgetTester tester, {
  required List<Task> tasks,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final cache = AppSettingsCache();
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
        appSettingsCacheProvider.overrideWithValue(cache),
        todoRepositoryProvider.overrideWithValue(repo),
        inboxProjectProvider.overrideWithValue(AsyncData(inboxProject)),
        projectTasksProvider(
          inboxProjectId,
        ).overrideWithValue(AsyncData(tasks)),
        // 新建弹窗 watch 的 drift 流也须覆盖（fake_async 下避免残留 Timer）。
        projectsStreamProvider.overrideWithValue(AsyncData([inboxProject])),
        tagsStreamProvider.overrideWithValue(const AsyncData(<Tag>[])),
        // 任务行标签流也须覆盖：taskTagsProvider 是真实 drift watch 流，
        // fake_async 下残留 Timer（与 task_tree_test 的 _pumpTreeWithDb 一致）。
        taskTagsProvider.overrideWith(
          (ref, taskId) => Stream.value(const <Tag>[]),
        ),
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

void main() {
  setUp(() {
    // No locale set → defaults to zh (Chinese).
  });

  group('收件箱任务树 — 与项目页一致的树形渲染（Bug 3）', () {
    testWidgets('父任务+子任务数据渲染为任务树', (tester) async {
      final tasks = [
        _task('root', title: '父任务'),
        _task('child', parentId: 'root', title: '子任务', sortOrder: 1),
      ];

      await _pumpInbox(tester, tasks: tasks);

      // 一级卡片（父任务）与默认展开的子任务标题均可见（树行为细节见
      // task_tree_test.dart，这里只验证 /inbox 确实接入了 TaskTree）。
      expect(find.text('父任务'), findsOneWidget);
      expect(find.text('子任务'), findsOneWidget);
    });
  });

  group('FAB — 新建任务底部弹窗（D2 定稿）', () {
    testWidgets('点击 FAB 打开 TaskCreateSheet（恒显示）', (tester) async {
      await _pumpInbox(tester, tasks: [_task('leaf', title: '叶子任务')]);

      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // 弹窗打开（不再是全屏 /task/new 路由）。
      expect(find.byType(TaskCreateSheet), findsOneWidget);
      expect(find.text('new:inbox'), findsNothing);
    });

    testWidgets('空收件箱：FAB 依然显示，空态文案依赖 FAB 新建', (tester) async {
      await _pumpInbox(tester, tasks: []);

      // TaskTree 空态（ARB：emptyProjectDetail）。
      expect(find.text('还没有任务，点击下方按钮新建'), findsOneWidget);
      // FAB 恒显示（收件箱项目恒存在）；旧版空态「添加任务」按钮已移除。
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('添加任务'), findsNothing);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(TaskCreateSheet), findsOneWidget);
    });
  });
}
