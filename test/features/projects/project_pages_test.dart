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

      // 移动端（<600dp）为可上拉底部弹窗（D1），不再用 AlertDialog。
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      // 描述字段（可选，D2）+ 颜色选项行。
      expect(find.text('项目描述'), findsOneWidget);
      expect(find.text('项目颜色'), findsOneWidget);
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

      // 弹窗已关闭（pop 返回数据）。
      expect(find.byType(BottomSheet), findsNothing);
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

      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('新建弹窗：颜色选项行弹出底部颜色选择器并选中', (tester) async {
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

      // 点击颜色选项行 → 弹出颜色选择器（D3）。
      await tester.tap(find.text('项目颜色'));
      await tester.pumpAndSettle();

      // 选择器顶栏标题 + 8 个预设色点；弹窗仍保留在下层。
      expect(find.byType(BottomSheet), findsNWidgets(2));
      expect(find.text('项目颜色'), findsNWidgets(2));

      // 点击某个色点 → 选择器关闭，表单弹窗仍在。
      await tester.tap(find.byIcon(Icons.check).first);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('桌面端（≥600dp）新建项目为居中对话框（D5）', (tester) async {
      await _pump(
        tester,
        initialLocation: '/projects',
        routes: [
          GoRoute(path: '/projects', builder: (_, _) => const ProjectsPage()),
          GoRoute(path: '/projects/:id', builder: (_, _) => const Scaffold()),
        ],
        projects: [_project('p1', '工作')],
        size: const Size(800, 900),
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // 宽屏走居中 Dialog（非 BottomSheet），选项行结构一致。
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('项目名称'), findsOneWidget);
      expect(find.text('项目颜色'), findsOneWidget);
      expect(find.text('项目描述'), findsOneWidget);

      // 有效名称 → 保存关闭。
      await tester.enterText(find.byType(TextFormField), '桌面项目');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('键盘收起：已手动拖离的弹窗不回弹（评审 #4 场景1）', (tester) async {
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

      // 模拟键盘弹出 → 弹窗自动扩展至全屏。
      tester.view.viewInsets = FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();

      // 用户把弹窗拖到最小高度 0.4（从 ListView 顶部非输入区起拖）。
      final sheetList = find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(ListView),
      );
      final listTop = tester.getTopLeft(sheetList);
      await tester.dragFrom(
        listTop + const Offset(100, 10),
        const Offset(0, 400),
      );
      await tester.pumpAndSettle();

      // 键盘收起 → 弹窗应停留在用户拖到的位置，不再回弹到 0.6。
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      final height = tester.getSize(sheetList).height;
      // 0.4×800=320 弹窗（List 更矮）；若错误回弹 0.6×800=480 则明显更高。
      expect(height, lessThan(320));
    });

    testWidgets('键盘收起：点过「收起」后弹窗不被拉回 0.6（评审 #4 场景2）', (tester) async {
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

      // 键盘弹出 → 全屏态出现收起按钮。
      tester.view.viewInsets = FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();

      // 点击收起（用户主动接管）→ 再拖回全屏。
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();
      final sheetList = find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(ListView),
      );
      final listTop = tester.getTopLeft(sheetList);
      await tester.dragFrom(
        listTop + const Offset(100, 10),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();

      // 键盘收起 → 用户拖到的全屏位置应保持，不被拉回 0.6。
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      final height = tester.getSize(sheetList).height;
      // 全屏 800 弹窗；若被错误拉回 0.6×800=480 则明显更矮。
      expect(height, greaterThan(500));
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

    testWidgets('AppBar 有编辑和删除按钮', (tester) async {
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

      // 编辑/删除收纳在 AppBar 三点菜单内。
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
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
            builder: (_, state) => TaskListPage(
              scope: ProjectTaskScope(state.pathParameters['id']!),
            ),
          ),
          GoRoute(path: '/projects', builder: (_, _) => const Scaffold()),
        ],
        projects: projects,
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
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
            builder: (_, state) => TaskListPage(
              scope: ProjectTaskScope(state.pathParameters['id']!),
            ),
          ),
          GoRoute(path: '/projects', builder: (_, _) => const Scaffold()),
        ],
        projects: projects,
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 对话框关闭，仍在项目详情页。
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('工作'), findsOneWidget);
    });

    testWidgets('删除确认后跳转 /today（D5）', (tester) async {
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
          // 新默认首页（D3：initialLocation 改 /today）。
          GoRoute(
            path: '/today',
            builder: (_, _) => const Scaffold(body: Text('今日页')),
          ),
          GoRoute(path: '/projects', builder: (_, _) => const Scaffold()),
        ],
        projects: projects,
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // 删除成功后跳转 /today（D5，而非旧 /projects）。
      expect(find.text('今日页'), findsOneWidget);
    });
  });
}
