// Smoke tests: app launch, adaptive navigation, tab switch, settings.
// Updated for M5 batch-2 IA: narrow = hamburger drawer (system + projects)
// + compact 2-tab bottom bar (today/calendar, 57-task-page-polish §4.1);
// wide = 5-destination NavigationRail.
// Default locale is zh (Chinese); tests reflect this.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo/app.dart';
import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/repositories/todo_repository.dart';
import 'package:todo/core/db/tables.dart';
import 'package:todo/core/theme/app_tokens.dart';
import 'package:todo/features/calendar/calendar_providers.dart';
import 'package:todo/features/custom_views/providers/custom_view_providers.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/features/tags/tag_providers.dart';
import 'package:todo/features/tasks/task_providers.dart';
import 'package:todo/features/today/today_providers.dart';
import 'package:todo/router.dart';
import 'package:todo/shared/widgets/app_drawer.dart';
import 'helpers/db_test_setup.dart';

/// Build and pump the app at a given logical size.
///
/// [projects]：抽屉项目组渲染数据（窄屏导航测试用，默认空）。
/// [projectTasks]：项目任务树种子数据（默认空列表，测试树渲染用）。
/// [folders]：抽屉文件夹渲染数据（62-folder-nav 测试用，默认空）。
/// [provideTestDatabase] 为 true 时返回真实仓库（拖拽/增删改断言用）。
/// [settingsCache]：设备本地偏好内存缓存（默认新建；主题/语言持久化断言用）。
Future<TodoRepository?> pumpApp(
  WidgetTester tester,
  Size logicalSize, {
  bool provideTestDatabase = false,
  List<Project>? projects,
  List<Task>? projectTasks,
  List<Folder>? folders,
  AppSettingsCache? settingsCache,
}) async {
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final cache = settingsCache ?? AppSettingsCache();
  final overrides = [
    appSettingsCacheProvider.overrideWithValue(cache),
    projectsStreamProvider.overrideWithValue(
      AsyncData(projects ?? const <Project>[]),
    ),
    foldersStreamProvider.overrideWithValue(
      AsyncData(folders ?? const <Folder>[]),
    ),
    customViewsStreamProvider.overrideWithValue(
      const AsyncData(<CustomView>[]),
    ),
    // 立即 emit 指定任务列表（Stream.empty 永不 emit，会让任务树停在 loading）。
    projectTasksProvider.overrideWith(
      (ref, projectId) => Stream<List<Task>>.value(projectTasks ?? const []),
    ),
  ];
  TodoRepository? repo;

  if (provideTestDatabase) {
    final db = openTestDatabase();
    repo = TodoRepository(database: db);
    // 预置固定 id 文件夹（拖拽/菜单用例需要）。须先于项目插入
    //（projects.folderId 外键依赖 folders，62-folder-nav.md §4.2）。
    for (final f in folders ?? const <Folder>[]) {
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
    // 预置固定 id 项目（删除/编辑用例需要，跳过 UUID 生成）。
    for (final p in projects ?? const <Project>[]) {
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
    overrides.add(todoRepositoryProvider.overrideWithValue(repo));
    // 视图 provider 一律覆盖，避免真实 drift 流残留 Timer
    //（widget 测试只关心导航壳与项目 CRUD，不依赖真实视图计算）。
    overrides.addAll([
      todayViewProvider.overrideWithValue(
        const AsyncData(TodayViewData(overdue: [], today: [])),
      ),
      inboxProjectProvider.overrideWithValue(
        AsyncData(
          Project(
            id: inboxProjectId,
            name: '收件箱',
            color: inboxProjectColor,
            description: '',
            sortOrder: 0,
            createdAt: 0,
            updatedAt: 0,
            deleted: 0,
          ),
        ),
      ),
    ]);
  } else {
    // Without a real DB, mock inbox providers so the app doesn't crash.
    final dummyProject = Project(
      id: 'inbox',
      name: 'Inbox',
      color: 0xFF7C6FF7,
      description: '',
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
      deleted: 0,
    );
    overrides.addAll([
      inboxProjectProvider.overrideWithValue(AsyncData(dummyProject)),
      // 无真实 DB：文件夹展开状态不落库，静态空状态（默认全部展开）。
      folderExpandProvider.overrideWith(_TestFolderExpandNotifier.new),
      // M3 视图 provider：无真实 DB 时给空数据。否则落到真实仓库的流
      // 在测试里不结束（loading 转圈），pumpAndSettle 超时。
      todayViewProvider.overrideWithValue(
        const AsyncData(TodayViewData(overdue: [], today: [])),
      ),
      tagsStreamProvider.overrideWithValue(const AsyncData(<Tag>[])),
      calendarBucketsProvider.overrideWithValue(
        const AsyncData(<DateTime, List<Task>>{}),
      ),
    ]);
  }

  // appRouter 是进程级单例，测试之间会残留上次导航位置。
  // 每次 pump 前重置回首页 /today（D3，与 initialLocation 一致）。
  appRouter.go('/today');

  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const TodoApp()),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// 测试用任务种子（项目任务树渲染/计数断言用）。
Task _seedTask(
  String id,
  String title,
  TaskStatus status, {
  String? parentId,
  int sortOrder = 0,
}) => Task(
  id: id,
  projectId: 'p1',
  parentId: parentId,
  title: title,
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

/// 测试用 FolderExpandNotifier：build() 直接返回空状态（无真实 DB 时用，
/// 避免落到真实仓库读取 settings 表）。
class _TestFolderExpandNotifier extends FolderExpandNotifier {
  @override
  Future<Map<String, bool>> build() async => const {};
}

/// 测试用文件夹种子。
Folder _folder(String id, String name, {int sortOrder = 0}) => Folder(
  id: id,
  name: name,
  sortOrder: sortOrder,
  createdAt: 0,
  updatedAt: 0,
  deleted: 0,
);

/// 测试用项目种子（可指定所属文件夹与组内 sortOrder，62-folder-nav 用）。
Project _projectInFolder(
  String id,
  String name,
  String? folderId, {
  int sortOrder = 0,
  int color = 0xFF4A6CF7,
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

/// 在抽屉内长按 [draggedText] 所在行并拖到 [targetText] 所在行中心
/// （62-folder-nav 拖拽测试；复用 task_tree 的 startGesture 手势序列）。
Future<void> _dragInDrawer(
  WidgetTester tester,
  String draggedText,
  String targetText,
) async {
  final inDrawer = find.byType(Drawer);
  final dragStart = tester.getCenter(
    find.descendant(of: inDrawer, matching: find.text(draggedText)),
  );
  final targetPoint = tester.getCenter(
    find.descendant(of: inDrawer, matching: find.text(targetText)),
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
    // No locale set → defaults to zh (Chinese).
  });

  testWidgets('Narrow (<600dp) smoke: today home + hamburger, no bottom bar', (
    tester,
  ) async {
    await pumpApp(tester, const Size(400, 800));

    // 启动默认页为 /today（D3，56-task-scope-page.md §1.2）；中文文案。
    expect(find.text('今天还没有任务'), findsOneWidget);

    // 窄屏无底栏（由抽屉侧边栏统一承载系统入口与清单）
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byType(AppSidebar), findsNothing);

    // 窄屏 AppBar 有汉堡入口；抽屉未打开时不渲染。
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets(
    'Wide (≥600dp) smoke: AppSidebar persistent sidebar, no hamburger, no drawer',
    (tester) async {
      await pumpApp(tester, const Size(1000, 800));

      // 宽屏固定常驻侧边栏（全桌面端一致）
      expect(find.byType(AppSidebar), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
      // 宽屏无汉堡（侧边栏已常驻），无模态抽屉
      expect(find.byIcon(Icons.menu), findsNothing);
      expect(find.byType(Drawer), findsNothing);
      // 侧边栏包含系统组目的地（今日/收件箱/日历/标签）与任务分组标题
      expect(find.text('任务分组'), findsOneWidget);
      for (final label in ['收件箱', '今日', '日历', '标签']) {
        expect(
          find.descendant(
            of: find.byType(AppSidebar),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
      // 宽屏设置入口在侧边栏底部（AppBar 无设置图标）
      expect(
        find.descendant(
          of: find.byType(AppSidebar),
          matching: find.byIcon(Icons.settings_outlined),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.settings_outlined),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Adaptive layout: dynamically resizing window toggles sidebar & drawer',
    (tester) async {
      // 初始宽屏（1000dp）：固定显示 AppSidebar，无汉堡
      await pumpApp(tester, const Size(1000, 800));
      expect(find.byType(AppSidebar), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsNothing);

      // 动态调窄窗口（500dp）：自动切为抽屉模式与汉堡按钮
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle();

      expect(find.byType(AppSidebar), findsNothing);
      expect(find.byIcon(Icons.menu), findsOneWidget);

      // 再次动态调宽窗口（900dp）：自动恢复固定 AppSidebar
      tester.view.physicalSize = const Size(900, 800);
      await tester.pumpAndSettle();

      expect(find.byType(AppSidebar), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsNothing);
    },
  );

  testWidgets(
    'Wide (≥600dp): settings opens as right-side panel with close button',
    (tester) async {
      await pumpApp(tester, const Size(1000, 800));

      // 点击侧边栏设置图标
      await tester.tap(
        find.descendant(
          of: find.byType(AppSidebar),
          matching: find.byIcon(Icons.settings_outlined),
        ),
      );
      await tester.pumpAndSettle();

      // 设置以右侧面板弹出，包含关闭按钮和设置内容
      expect(find.text('设置'), findsWidgets);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('主题模式'), findsOneWidget);

      // 点击关闭按钮 → 设置面板关闭，恢复主页面
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('主题模式'), findsNothing);
    },
  );

  testWidgets('Drawer navigation: today/calendar switch via drawer', (
    tester,
  ) async {
    await pumpApp(tester, const Size(400, 800));

    // Start on today (D3 default home; zh locale).
    expect(find.text('今天还没有任务'), findsOneWidget);

    // Open drawer and switch to Calendar.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('日历')),
    );
    await tester.pumpAndSettle();
    expect(find.text('日历暂无安排'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);

    // Switch back to Today via drawer.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('今日')),
    );
    await tester.pumpAndSettle();
    expect(find.text('今天还没有任务'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('Drawer: hamburger opens, system items navigate, scrim closes', (
    tester,
  ) async {
    await pumpApp(tester, const Size(400, 800));

    // 汉堡打开抽屉。
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    // 抽屉宽度接线：屏宽 × drawerWidthRatio（评审问题 5）。
    expect(
      tester.widget<Drawer>(find.byType(Drawer)).width,
      400 * AppTokens.drawerWidthRatio,
    );

    // 系统组：今日 → 今日页（抽屉内点击）。
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('今日')),
    );
    await tester.pumpAndSettle();
    expect(find.text('今天还没有任务'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing); // 点击后抽屉自动关闭。

    // 系统组：收件箱 → 收件箱作用域（AppShell 壳内）。
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('收件箱')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.byIcon(Icons.menu), findsOneWidget); // 壳内汉堡常驻

    // 再次打开，点遮罩（屏宽 400，抽屉宽 312，x>312 为 scrim）关闭。
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    await tester.tapAt(const Offset(360, 400));
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('Drawer: project list shows uncompleted count, navigates', (
    tester,
  ) async {
    final project = Project(
      id: 'p1',
      name: '工作',
      color: 0xFF4A6CF7,
      description: '',
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
      deleted: 0,
    );
    await pumpApp(tester, const Size(400, 800), projects: [project]);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // 项目组：颜色圆点 + 项目名 + 未完成数（无任务 → 0）。
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('工作')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('0')),
      findsOneWidget,
    );

    // 点击项目 → /projects/:id。
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('工作')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('工作'), findsOneWidget); // AppBar 标题 = 项目名

    // 需求 2 修复验收：项目作用域渲染在 AppShell 壳内，
    // 汉堡常驻（此前 ProjectDetailPage 自带 Scaffold 导致消失）。
    expect(find.byIcon(Icons.menu), findsOneWidget);
    // 项目作用域 AppBar：默认搜索/设置 + 三点菜单（编辑/删除收纳在菜单内，D2）。
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outlined), findsOneWidget);
  });

  testWidgets('项目菜单：切换「显示已完成任务」隐藏/恢复已完成任务', (tester) async {
    final project = Project(
      id: 'p1',
      name: '工作',
      color: 0xFF4A6CF7,
      description: '',
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
      deleted: 0,
    );
    await pumpApp(
      tester,
      const Size(400, 800),
      projects: [project],
      projectTasks: [
        _seedTask('t-done', '已完成任务', TaskStatus.done),
        _seedTask('t-todo', '待办任务', TaskStatus.todo),
      ],
    );

    // 进入项目页（抽屉 → 项目名）。
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('工作')),
    );
    await tester.pumpAndSettle();

    // 1. 初始（hideCompleted=false）：已完成 + 待办均显示。
    expect(find.text('已完成任务'), findsOneWidget);
    expect(find.text('待办任务'), findsOneWidget);

    // 2. 三点菜单：首项名称 = 可执行动作（显示中 →「隐藏已完成任务」），
    //    眼睛睁眼（visibility_outlined，无闭眼图标）。
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('隐藏已完成任务'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);

    // 3. 点击「隐藏已完成任务」→ 已完成任务行消失，待办仍在，树保持有效。
    await tester.tap(find.text('隐藏已完成任务'));
    await tester.pumpAndSettle();
    expect(find.text('已完成任务'), findsNothing);
    expect(find.text('待办任务'), findsOneWidget);

    // 4. 再次打开菜单：名称变为「显示已完成任务」、眼睛闭眼（隐藏中）；
    //    点击 → 已完成任务恢复。
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('显示已完成任务'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    await tester.tap(find.text('显示已完成任务'));
    await tester.pumpAndSettle();
    expect(find.text('已完成任务'), findsOneWidget);
    expect(find.text('待办任务'), findsOneWidget);
  });

  testWidgets('隐藏已完成任务时行尾「未完成/总数」分母保持真实总数', (tester) async {
    final project = Project(
      id: 'p1',
      name: '工作',
      color: 0xFF4A6CF7,
      description: '',
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
      deleted: 0,
    );
    await pumpApp(
      tester,
      const Size(400, 800),
      projects: [project],
      projectTasks: [
        _seedTask('t-parent', '父任务', TaskStatus.todo),
        _seedTask(
          't-child-done',
          '子任务-完成',
          TaskStatus.done,
          parentId: 't-parent',
          sortOrder: 1,
        ),
        _seedTask(
          't-child-todo',
          '子任务-待办',
          TaskStatus.todo,
          parentId: 't-parent',
          sortOrder: 2,
        ),
      ],
    );

    // 进入项目页（抽屉 → 项目名）。
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('工作')),
    );
    await tester.pumpAndSettle();

    // 1. 初始（默认展开）：父任务行「未完成/总数」= 1/2（1 未完成 / 2 总数），
    //    完成 + 待办两个子行均可见。
    expect(find.text('父任务'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('子任务-完成'), findsOneWidget);
    expect(find.text('子任务-待办'), findsOneWidget);

    // 2. 隐藏已完成（菜单当前为显示中 → 名称「隐藏已完成任务」）→ 完成子行
    //    消失，父任务仍在，计数**仍为 1/2**（非 1/1）。
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('隐藏已完成任务'));
    await tester.pumpAndSettle();
    expect(find.text('子任务-完成'), findsNothing);
    expect(find.text('子任务-待办'), findsOneWidget);
    expect(find.text('父任务'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('1/1'), findsNothing);

    // 3. 恢复显示（菜单当前为隐藏中 → 名称「显示已完成任务」）→ 完成子行
    //    返回，计数仍为 1/2。
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示已完成任务'));
    await tester.pumpAndSettle();
    expect(find.text('子任务-完成'), findsOneWidget);
    expect(find.text('子任务-待办'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('项目仅含已完成任务且隐藏开启 → 显示「全部任务已完成」空态（F4）', (tester) async {
    final project = Project(
      id: 'p1',
      name: '工作',
      color: 0xFF4A6CF7,
      description: '',
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
      deleted: 0,
    );
    await pumpApp(
      tester,
      const Size(400, 800),
      projects: [project],
      projectTasks: [_seedTask('t-done', '已完成任务', TaskStatus.done)],
    );

    // 进入项目页（抽屉 → 项目名）。
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('工作')),
    );
    await tester.pumpAndSettle();
    expect(find.text('已完成任务'), findsOneWidget);

    // 隐藏已完成 → 全部被隐藏 → 专用空态「全部任务已完成」（区别于
    // 「还没有任务」的普通空态）。
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('隐藏已完成任务'));
    await tester.pumpAndSettle();
    expect(find.text('已完成任务'), findsNothing);
    expect(find.text('全部任务已完成'), findsOneWidget);

    // 恢复显示 → 任务返回、空态消失。
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('显示已完成任务'));
    await tester.pumpAndSettle();
    expect(find.text('已完成任务'), findsOneWidget);
    expect(find.text('全部任务已完成'), findsNothing);
  });

  testWidgets('Project scope: delete project navigates to /today (D5)', (
    tester,
  ) async {
    final project = Project(
      id: 'p1',
      name: '工作',
      color: 0xFF4A6CF7,
      description: '',
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
      deleted: 0,
    );
    // 真实 DB：删除需落库（pumpApp 会把 projects 预置进内存库）。
    await pumpApp(
      tester,
      const Size(400, 800),
      provideTestDatabase: true,
      projects: [project],
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('工作')),
    );
    await tester.pumpAndSettle();

    // AppBar 三点菜单 → 删除 → 确认对话框 → 确认后跳转 /today（新首页）。
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('今天还没有任务'), findsOneWidget);
  });

  testWidgets('Drawer: add project opens the form dialog', (tester) async {
    await pumpApp(tester, const Size(400, 800));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // 底部「新建项目」→ 复用 project_form_dialog（居中对话框）。
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('新建项目')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);

    // 取消关闭，不落库。
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('Settings: theme mode & language switch persist instantly', (
    tester,
  ) async {
    final cache = AppSettingsCache();
    await pumpApp(tester, const Size(400, 800), settingsCache: cache);

    // 用户打磨要求 4：设置入口移出 AppBar，窄屏入口在抽屉底部
    //（新建项目行右侧）。
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byIcon(Icons.settings_outlined),
      ),
    );
    await tester.pumpAndSettle();
    // 抽屉点击后自动关闭并进入设置页。
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('设置'), findsOneWidget);

    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    expect(cache.get(themeModePrefKey), ThemeMode.dark.name);
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(cache.get(localePrefKey), 'en');
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Settings: sync entry navigates to /settings/sync and back', (
    tester,
  ) async {
    await pumpApp(tester, const Size(400, 800));

    // 窄屏设置入口：抽屉底部（用户打磨要求 4）。
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byIcon(Icons.settings_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);

    // 同步分组入口存在（push 跳转；/settings/sync 为 /settings 子路由，
    // 栈为 任务页→settings→sync，AppBar 自动出现返回箭头）。
    await tester.tap(find.text('同步设置'));
    await tester.pumpAndSettle();

    // 同步配置页打开：AppBar 标题 + 启用开关 + 返回箭头（Bug 1 回归）。
    expect(find.text('同步设置'), findsOneWidget);
    expect(find.text('启用同步'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    // 点返回箭头回到设置页（AppBar 标题「设置」）。
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);

    // 设置页仍有返回箭头，点它回到正常任务页（Bug 2 回归：
    // go 会丢弃栈底的 /today，push 必须一路可返）。
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    // /today 空态唯一文案，证明已回到今日页（标题「今日」与底栏重复，
    // 不宜用标题断言）。
    expect(find.text('今天还没有任务'), findsOneWidget);
  });

  // ────────────────────────────────────────
  // 抽屉文件夹（62-folder-nav.md §6，车道 D）
  // ────────────────────────────────────────

  testWidgets('Drawer: 文件夹分组显示 + 折叠/展开 + 未分组区', (tester) async {
    final folder = _folder('f1', '工作夹');
    final folderProject = _projectInFolder('p1', '项目A', 'f1');
    final ungroupedProject = _projectInFolder('p2', '项目B', null);
    await pumpApp(
      tester,
      const Size(400, 800),
      provideTestDatabase: true,
      folders: [folder],
      projects: [folderProject, ungroupedProject],
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // 文件夹行（名称）+ 夹内项目行 + 未分组区小标题 + 未分组项目行。
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('工作夹')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('项目A')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('未分组')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('项目B')),
      findsOneWidget,
    );

    // 展开态：箭头朝下（expand_more），行尾三点菜单可见（des-1 需求 1/2）。
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byIcon(Icons.expand_more),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byIcon(Icons.chevron_left),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byIcon(Icons.more_vert),
      ),
      findsOneWidget,
    );

    // 点击文件夹行 → 折叠：夹内项目行隐藏，未分组区不受影响。
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('工作夹')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('项目A')),
      findsNothing,
    );
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('项目B')),
      findsOneWidget,
    );
    // 折叠态：箭头朝左（chevron_left），三点菜单隐藏（des-1 需求 1/2）。
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byIcon(Icons.chevron_left),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byIcon(Icons.expand_more),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byIcon(Icons.more_vert),
      ),
      findsNothing,
    );

    // 再点 → 展开恢复。
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('工作夹')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('项目A')),
      findsOneWidget,
    );
    // 展开恢复：菜单与向下箭头回到可见。
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byIcon(Icons.more_vert),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byIcon(Icons.expand_more),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Drawer: 文件夹行与系统组左对齐 + 展开/折叠高度与位置不变（des-2）', (tester) async {
    final folder = _folder('f1', '工作夹');
    final p1 = _projectInFolder('p1', '项目A', 'f1');
    await pumpApp(
      tester,
      const Size(400, 800),
      provideTestDatabase: true,
      folders: [folder],
      projects: [p1],
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    final inDrawer = find.byType(Drawer);

    // 需求 1：文件夹行 leading（文件夹图标）与系统组行（收件箱）leading 左对齐。
    final folderIconLeft = tester.getTopLeft(
      find.descendant(
        of: inDrawer,
        matching: find.byIcon(Icons.folder_outlined),
      ),
    );
    final inboxIconLeft = tester.getTopLeft(
      find.descendant(
        of: inDrawer,
        matching: find.byIcon(Icons.inbox_outlined),
      ),
    );
    expect(folderIconLeft.dx, inboxIconLeft.dx);

    // 需求 2a：展开/折叠切换时文件夹行自身高度与顶部位置不变。
    final folderRow = find
        .ancestor(of: find.text('工作夹'), matching: find.byType(Material))
        .first;
    final expandedHeight = tester.getSize(folderRow).height;
    final expandedTop = tester.getTopLeft(folderRow).dy;

    await tester.tap(find.descendant(of: inDrawer, matching: find.text('工作夹')));
    await tester.pumpAndSettle();

    expect(tester.getSize(folderRow).height, expandedHeight);
    expect(tester.getTopLeft(folderRow).dy, expandedTop);
  });

  testWidgets('Drawer: 文件夹行汇总未完成数为夹内项目之和（真实值）', (tester) async {
    final folder = _folder('f1', '工作夹');
    final p1 = _projectInFolder('p1', '项目A', 'f1');
    final p2 = _projectInFolder('p2', '项目B', 'f1');
    await pumpApp(
      tester,
      const Size(400, 800),
      provideTestDatabase: true,
      folders: [folder],
      projects: [p1, p2],
    );

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // 两个项目都无任务 → 文件夹汇总 0（与项目行同样真实值口径）。
    expect(
      find.descendant(of: find.byType(Drawer), matching: find.text('0')),
      findsNWidgets(3), // 文件夹汇总 + 两个项目行
    );
  });

  testWidgets('Drawer: 拖拽项目入夹（未分组项目 → 文件夹行）', (tester) async {
    final folder = _folder('f1', '工作夹');
    final p1 = _projectInFolder('p1', '项目A', null);
    final p2 = _projectInFolder('p2', '项目B', 'f1');
    final repo = (await pumpApp(
      tester,
      const Size(400, 800),
      provideTestDatabase: true,
      folders: [folder],
      projects: [p1, p2],
    ))!;

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // 长按「项目A」（未分组）拖到文件夹行「工作夹」→ 入夹。
    await _dragInDrawer(tester, '项目A', '工作夹');

    final after = (await repo.projects.getById('p1'))!;
    expect(after.folderId, 'f1');
  });

  testWidgets('Drawer: 拖拽项目出夹（夹内项目 → 未分组区）', (tester) async {
    final folder = _folder('f1', '工作夹');
    final p1 = _projectInFolder('p1', '项目A', 'f1');
    final repo = (await pumpApp(
      tester,
      const Size(400, 800),
      provideTestDatabase: true,
      folders: [folder],
      projects: [p1],
    ))!;

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // 长按「项目A」（夹内）拖到未分组区小标题 → 出夹。
    await _dragInDrawer(tester, '项目A', '未分组');

    final after = (await repo.projects.getById('p1'))!;
    expect(after.folderId, isNull);
  });

  testWidgets('Drawer: 拖拽项目到同组项目行 → 组内重排', (tester) async {
    final folder = _folder('f1', '工作夹');
    final pA = _projectInFolder('pa', '项目A', 'f1', sortOrder: 0);
    final pB = _projectInFolder('pb', '项目B', 'f1', sortOrder: 1);
    final repo = (await pumpApp(
      tester,
      const Size(400, 800),
      provideTestDatabase: true,
      folders: [folder],
      projects: [pA, pB],
    ))!;

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // 长按「项目A」拖到「项目B」行 → 插到 B 前（A 的 sortOrder > B）。
    await _dragInDrawer(tester, '项目A', '项目B');

    final a = (await repo.projects.getById('pa'))!;
    final b = (await repo.projects.getById('pb'))!;
    expect(a.folderId, 'f1');
    expect(a.sortOrder, greaterThan(b.sortOrder));
  });
  testWidgets('Drawer: 新建文件夹入口弹出名称弹窗并落库', (tester) async {
    final repo = (await pumpApp(
      tester,
      const Size(400, 800),
      provideTestDatabase: true,
    ))!;

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // 「任务分组」分组头三点菜单 → 「新建文件夹」→ 名称弹窗（Dialog）。
    await tester.tap(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.byIcon(Icons.more_horiz),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建文件夹'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '新文件夹');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final folders = await repo.folders.getAll();
    expect(folders.length, 1);
    expect(folders.single.name, '新文件夹');
  });

  testWidgets('Drawer: 文件夹菜单重命名', (tester) async {
    final folder = _folder('f1', '工作夹');
    final repo = (await pumpApp(
      tester,
      const Size(400, 800),
      provideTestDatabase: true,
      folders: [folder],
    ))!;

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // 文件夹行尾菜单 → 重命名 → 名称弹窗预填 → 保存。
    await tester.tap(
      find
          .descendant(
            of: find.byType(Drawer),
            matching: find.byIcon(Icons.more_vert),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名文件夹'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '生活夹');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect((await repo.folders.getById('f1'))!.name, '生活夹');
  });

  testWidgets('Drawer: 删除文件夹确认（明示项目回未分组）后项目回未分组', (tester) async {
    final folder = _folder('f1', '工作夹');
    final p1 = _projectInFolder('p1', '项目A', 'f1');
    final repo = (await pumpApp(
      tester,
      const Size(400, 800),
      provideTestDatabase: true,
      folders: [folder],
      projects: [p1],
    ))!;

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    await tester.tap(
      find
          .descendant(
            of: find.byType(Drawer),
            matching: find.byIcon(Icons.more_vert),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除文件夹'));
    await tester.pumpAndSettle();

    // 确认框：标题 + 明示「项目将回到未分组」。
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('删除文件夹'), findsOneWidget);
    expect(find.textContaining('回到未分组'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    // 删除文件夹 → 项目回未分组，文件夹硬删。
    final after = (await repo.projects.getById('p1'))!;
    expect(after.folderId, isNull);
    expect(await repo.folders.getById('f1'), isNull);
  });
}
