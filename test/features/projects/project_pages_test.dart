// M2 项目列表 & 项目详情页测试。
//
// 覆盖 DoD：卡片列表、新建对话框验证、删除确认、项目详情空态。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:todo/core/db/database.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/projects/projects_page.dart';
import 'package:todo/features/projects/project_detail_page.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/features/tasks/task_providers.dart';
import '../../helpers/db_test_setup.dart';

/// 构造测试用 Project。
Project _project(String id, String name, {int color = 0xFF3482FF}) => Project(
  id: id,
  name: name,
  color: color,
  sortOrder: 0,
  createdAt: 0,
  updatedAt: 0,
  deleted: 0,
);

/// 统一 pump：带 GoRouter + 本地化 + Provider mocks。
Future<void> _pump(
  WidgetTester tester, {
  required String initialLocation,
  required List<GoRoute> routes,
  List<Project> projects = const [],
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final prefs = await SharedPreferences.getInstance();
  final db = openTestDatabase();
  final repo = TodoRepository(database: db);

  // 预插入项目（满足 FK 约束）。
  for (final p in projects) {
    await db
        .into(db.projects)
        .insertOnConflictUpdate(
          ProjectsCompanion.insert(
            id: p.id,
            name: p.name,
            color: p.color,
            sortOrder: p.sortOrder,
            createdAt: p.createdAt,
            updatedAt: p.updatedAt,
          ),
        );
  }

  final overrides = [
    sharedPreferencesProvider.overrideWithValue(prefs),
    todoRepositoryProvider.overrideWithValue(repo),
    projectsStreamProvider.overrideWithValue(AsyncData(projects)),
    projectTasksProvider.overrideWith(
      (ref, projectId) => Stream.value(const <Task>[]),
    ),
  ];

  final router = GoRouter(initialLocation: initialLocation, routes: routes);

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
  await tester.pump(); // 不用 pumpAndSettle，避免 Drift 定时器导致超时。
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ────────────────────────────────────────
  // 1. 项目列表页（ProjectsPage）
  // ────────────────────────────────────────
  group('ProjectsPage', () {
    testWidgets('空列表显示空态 + 新建按钮', (tester) async {
      await _pump(
        tester,
        initialLocation: '/projects',
        routes: [
          GoRoute(path: '/projects', builder: (_, _) => const ProjectsPage()),
          GoRoute(path: '/projects/:id', builder: (_, _) => const Scaffold()),
          GoRoute(path: '/task/new', builder: (_, _) => const Scaffold()),
        ],
      );

      expect(find.text('还没有项目'), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    });

    testWidgets('有项目时显示卡片列表 + FAB', (tester) async {
      final projects = [_project('p1', '工作'), _project('p2', '个人')];

      await _pump(
        tester,
        initialLocation: '/projects',
        routes: [
          GoRoute(path: '/projects', builder: (_, _) => const ProjectsPage()),
          GoRoute(path: '/projects/:id', builder: (_, _) => const Scaffold()),
        ],
        projects: projects,
      );

      expect(find.text('工作'), findsOneWidget);
      expect(find.text('个人'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('还没有项目'), findsNothing);
    });

    testWidgets('FAB 点击弹出新建项目对话框', (tester) async {
      await _pump(
        tester,
        initialLocation: '/projects',
        routes: [
          GoRoute(path: '/projects', builder: (_, _) => const ProjectsPage()),
          GoRoute(path: '/projects/:id', builder: (_, _) => const Scaffold()),
          GoRoute(path: '/task/new', builder: (_, _) => const Scaffold()),
        ],
        projects: [_project('p1', '工作')],
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('新建对话框：空名称验证失败', (tester) async {
      await _pump(
        tester,
        initialLocation: '/projects',
        routes: [
          GoRoute(path: '/projects', builder: (_, _) => const ProjectsPage()),
          GoRoute(path: '/projects/:id', builder: (_, _) => const Scaffold()),
        ],
        projects: [_project('p1', '工作')],
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // 不输入名称，直接点保存。
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('标题不能为空'), findsOneWidget);
    });

    testWidgets('新建对话框：空格名称验证失败', (tester) async {
      await _pump(
        tester,
        initialLocation: '/projects',
        routes: [
          GoRoute(path: '/projects', builder: (_, _) => const ProjectsPage()),
          GoRoute(path: '/projects/:id', builder: (_, _) => const Scaffold()),
        ],
        projects: [_project('p1', '工作')],
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('标题不能为空'), findsOneWidget);
    });

    testWidgets('新建对话框：有效名称保存后关闭', (tester) async {
      await _pump(
        tester,
        initialLocation: '/projects',
        routes: [
          GoRoute(path: '/projects', builder: (_, _) => const ProjectsPage()),
          GoRoute(path: '/projects/:id', builder: (_, _) => const Scaffold()),
        ],
        projects: [_project('p1', '工作')],
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '新项目');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 对话框已关闭（pop 返回数据）。
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('新建对话框：取消关闭不返回数据', (tester) async {
      await _pump(
        tester,
        initialLocation: '/projects',
        routes: [
          GoRoute(path: '/projects', builder: (_, _) => const ProjectsPage()),
          GoRoute(path: '/projects/:id', builder: (_, _) => const Scaffold()),
        ],
        projects: [_project('p1', '工作')],
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  // ────────────────────────────────────────
  // 2. 项目详情页（ProjectDetailPage）
  // ────────────────────────────────────────
  group('ProjectDetailPage', () {
    testWidgets('项目不存在时显示空态', (tester) async {
      await _pump(
        tester,
        initialLocation: '/projects/nonexistent',
        routes: [
          GoRoute(
            path: '/projects/:id',
            builder: (_, state) =>
                ProjectDetailPage(projectId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/projects', builder: (_, _) => const Scaffold()),
        ],
      );

      expect(find.text('还没有项目'), findsOneWidget);
    });

    testWidgets('项目存在时显示 AppBar + FAB', (tester) async {
      final projects = [_project('p1', '工作')];

      await _pump(
        tester,
        initialLocation: '/projects/p1',
        routes: [
          GoRoute(
            path: '/projects/:id',
            builder: (_, state) =>
                ProjectDetailPage(projectId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/projects', builder: (_, _) => const Scaffold()),
          GoRoute(path: '/task/new', builder: (_, _) => const Scaffold()),
          GoRoute(path: '/task/:id', builder: (_, _) => const Scaffold()),
        ],
        projects: projects,
      );

      expect(find.text('工作'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('空项目任务列表显示空态', (tester) async {
      final projects = [_project('p1', '工作')];

      await _pump(
        tester,
        initialLocation: '/projects/p1',
        routes: [
          GoRoute(
            path: '/projects/:id',
            builder: (_, state) =>
                ProjectDetailPage(projectId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/projects', builder: (_, _) => const Scaffold()),
        ],
        projects: projects,
      );

      expect(find.textContaining('还没有任务'), findsOneWidget);
    });

    testWidgets('AppBar 有编辑和删除按钮', (tester) async {
      final projects = [_project('p1', '工作')];

      await _pump(
        tester,
        initialLocation: '/projects/p1',
        routes: [
          GoRoute(
            path: '/projects/:id',
            builder: (_, state) =>
                ProjectDetailPage(projectId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/projects', builder: (_, _) => const Scaffold()),
        ],
        projects: projects,
      );

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outlined), findsOneWidget);
    });

    testWidgets('删除按钮弹出确认对话框', (tester) async {
      final projects = [_project('p1', '工作')];

      await _pump(
        tester,
        initialLocation: '/projects/p1',
        routes: [
          GoRoute(
            path: '/projects/:id',
            builder: (_, state) =>
                ProjectDetailPage(projectId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/projects', builder: (_, _) => const Scaffold()),
        ],
        projects: projects,
      );

      await tester.tap(find.byIcon(Icons.delete_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('工作'), findsWidgets);
    });

    testWidgets('删除确认对话框：取消关闭', (tester) async {
      final projects = [_project('p1', '工作')];

      await _pump(
        tester,
        initialLocation: '/projects/p1',
        routes: [
          GoRoute(
            path: '/projects/:id',
            builder: (_, state) =>
                ProjectDetailPage(projectId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/projects', builder: (_, _) => const Scaffold()),
        ],
        projects: projects,
      );

      await tester.tap(find.byIcon(Icons.delete_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 对话框关闭，仍在项目详情页。
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('工作'), findsOneWidget);
    });
  });
}
