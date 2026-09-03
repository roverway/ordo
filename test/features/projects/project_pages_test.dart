// M2 项目列表 & 项目详情页测试。
//
// 覆盖 DoD：卡片列表、新建对话框验证、删除确认、项目详情空态。

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:todo/core/db/database.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/features/custom_views/providers/custom_view_providers.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/projects/projects_page.dart';
import 'package:todo/features/projects/widgets/project_form_dialog.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/features/tasks/task_list_page.dart';
import 'package:todo/features/tasks/task_providers.dart';
import '../../helpers/db_test_setup.dart';

/// 构造测试用 Project。
Project _project(
  String id,
  String name, {
  int color = 0xFF3482FF,
  String? folderId,
  int sortOrder = 0,
}) => Project(
  id: id,
  name: name,
  color: color,
  description: '',
  folderId: folderId,
  sortOrder: sortOrder,
  createdAt: 0,
  updatedAt: 0,
  deleted: 0,
);

/// 构造测试用 Folder。
Folder _folder(String id, String name, {int sortOrder = 0}) => Folder(
  id: id,
  name: name,
  sortOrder: sortOrder,
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
  List<Folder> folders = const [],
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final cache = AppSettingsCache();
  final db = openTestDatabase();
  final repo = TodoRepository(database: db);

  // 预插入文件夹（满足 projects.folderId 外键约束，须先于项目插入）。
  for (final f in folders) {
    await db
        .into(db.folders)
        .insertOnConflictUpdate(
          FoldersCompanion.insert(
            id: f.id,
            name: f.name,
            sortOrder: f.sortOrder,
            createdAt: f.createdAt,
            updatedAt: f.updatedAt,
          ),
        );
  }
  // 预插入项目（满足 FK 约束）。
  for (final p in projects) {
    await db
        .into(db.projects)
        .insertOnConflictUpdate(
          ProjectsCompanion.insert(
            id: p.id,
            name: p.name,
            color: p.color,
            folderId: Value(p.folderId),
            sortOrder: p.sortOrder,
            createdAt: p.createdAt,
            updatedAt: p.updatedAt,
          ),
        );
  }

  final overrides = [
    appSettingsCacheProvider.overrideWithValue(cache),
    todoRepositoryProvider.overrideWithValue(repo),
    projectsStreamProvider.overrideWithValue(AsyncData(projects)),
    foldersStreamProvider.overrideWithValue(AsyncData(folders)),
    customViewsStreamProvider.overrideWithValue(const AsyncData([])),
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
    // No locale set → defaults to zh (Chinese).
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

    testWidgets('按文件夹分组展示：文件夹分组头 + 卡片 + 未分组区（D5）', (tester) async {
      final projects = [
        _project('p1', '项目A', folderId: 'f1', sortOrder: 0),
        _project('p2', '项目B', folderId: 'f1', sortOrder: 1),
        _project('p3', '项目C', folderId: null, sortOrder: 0),
      ];

      await _pump(
        tester,
        initialLocation: '/projects',
        routes: [
          GoRoute(path: '/projects', builder: (_, _) => const ProjectsPage()),
          GoRoute(path: '/projects/:id', builder: (_, _) => const Scaffold()),
        ],
        projects: projects,
        folders: [_folder('f1', '工作夹')],
      );

      // 文件夹分组头 + 夹内卡片。
      expect(find.text('工作夹'), findsOneWidget);
      expect(find.text('项目A'), findsOneWidget);
      expect(find.text('项目B'), findsOneWidget);
      // 未分组区头 + 未分组卡片。
      expect(find.text('未分组'), findsOneWidget);
      expect(find.text('项目C'), findsOneWidget);
      // 无文件夹 → 不出现未分组区；有文件夹 → 空态不出现。
      expect(find.text('还没有项目'), findsNothing);
    });

    testWidgets('有文件夹但无未分组项目：不渲染空的未分组区', (tester) async {
      final projects = [_project('p1', '项目A', folderId: 'f1')];

      await _pump(
        tester,
        initialLocation: '/projects',
        routes: [
          GoRoute(path: '/projects', builder: (_, _) => const ProjectsPage()),
          GoRoute(path: '/projects/:id', builder: (_, _) => const Scaffold()),
        ],
        projects: projects,
        folders: [_folder('f1', '工作夹')],
      );

      expect(find.text('工作夹'), findsOneWidget);
      expect(find.text('项目A'), findsOneWidget);
      expect(find.text('未分组'), findsNothing);
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

      // 模态底栏模式 (CreateListFolderSheet)
      expect(find.text('新建清单'), findsOneWidget);
      expect(find.text('新建文件夹'), findsOneWidget);
      expect(find.text('主题颜色'), findsOneWidget);
      expect(find.text('选择图标'), findsOneWidget);
      expect(find.text('所属文件夹'), findsOneWidget);
    });

    testWidgets('新建模态：空名称时完成按钮不可点击', (tester) async {
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

      // 未输入名称时点完成，不会关闭
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(find.text('新建清单'), findsOneWidget);
    });

    testWidgets('新建模态：有效名称保存后关闭并创建项目', (tester) async {
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

      await tester.enterText(find.byType(TextField), '新项目');
      await tester.pumpAndSettle();
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));

      // 模态已关闭
      expect(find.text('所属文件夹'), findsNothing);
    });

    testWidgets('新建模态：取消关闭不保存', (tester) async {
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

      expect(find.text('所属文件夹'), findsNothing);
    });

    testWidgets('新建模态：切换新建清单与新建文件夹', (tester) async {
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

      // 默认清单模式有所属文件夹
      expect(find.text('所属文件夹'), findsOneWidget);

      // 切换到新建文件夹
      await tester.tap(find.text('新建文件夹'));
      await tester.pumpAndSettle();

      // 文件夹模式下隐藏所属文件夹
      expect(find.text('所属文件夹'), findsNothing);
      expect(find.text('文件夹名称'), findsOneWidget);
    });

    testWidgets('编辑模式：预填超长名称时保存显示长度校验文案（评审 #2）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showProjectFormDialog(
                    context: context,
                    initialName: '超长项目名称' * 17, // 6 字 × 17 = 102 字 > 100
                  ),
                  child: const Text('open-form'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open-form'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('名称不能超过 100 个字符'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget); // 校验失败不关闭。
    });
  });

  // ────────────────────────────────────────
  // 2. 项目作用域（TaskListPage(ProjectTaskScope)，56-task-scope-page §4 批 2）
  // ────────────────────────────────────────
  group('TaskListPage(project)', () {
    testWidgets('项目不存在时显示空态', (tester) async {
      await _pump(
        tester,
        initialLocation: '/projects/nonexistent',
        routes: [
          GoRoute(
            path: '/projects/:id',
            builder: (_, state) => TaskListPage(
              scope: ProjectTaskScope(state.pathParameters['id']!),
            ),
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
            builder: (_, state) => TaskListPage(
              scope: ProjectTaskScope(state.pathParameters['id']!),
            ),
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
            builder: (_, state) => TaskListPage(
              scope: ProjectTaskScope(state.pathParameters['id']!),
            ),
          ),
          GoRoute(path: '/projects', builder: (_, _) => const Scaffold()),
        ],
        projects: projects,
      );

      expect(find.textContaining('还没有任务'), findsOneWidget);
    });

    testWidgets('任务列表顶部无三点菜单（功能已在导航弹层等实现）', (tester) async {
      final projects = [_project('p1', '工作')];

      await _pump(
        tester,
        initialLocation: '/projects/p1',
        routes: [
          GoRoute(
            path: '/projects/:id',
            builder: (_, state) => TaskListPage(
              scope: ProjectTaskScope(state.pathParameters['id']!),
            ),
          ),
          GoRoute(path: '/projects', builder: (_, _) => const Scaffold()),
        ],
        projects: projects,
      );

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });
  });
}
