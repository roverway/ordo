import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/repositories/todo_repository.dart';
import 'package:todo/core/db/tables.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/core/sync/sync_engine.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/features/calendar/calendar_providers.dart';
import 'package:todo/features/custom_views/providers/custom_view_providers.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/projects/widgets/create_list_folder_sheet.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/features/sync_setup/sync_setup_providers.dart';
import 'package:todo/features/tags/tag_providers.dart';
import 'package:todo/features/tasks/task_providers.dart';
import 'package:todo/features/today/today_providers.dart';
import 'package:todo/router.dart';
import 'package:todo/shared/widgets/app_drawer.dart';
import 'package:todo/shared/widgets/page_hero_header.dart';
import 'package:todo/shared/widgets/scope_switcher_sheet.dart';
import 'helpers/db_test_setup.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
}

/// Build and pump the app at a given logical size.
Future<TodoRepository?> pumpApp(
  WidgetTester tester,
  Size logicalSize, {
  String initialLocation = '/today',
  bool provideTestDatabase = true,
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
    todayViewProvider.overrideWithValue(
      const AsyncData(TodayViewData(today: [], overdue: [])),
    ),
    tagsStreamProvider.overrideWithValue(const AsyncData(<Tag>[])),
    calendarBucketsProvider.overrideWithValue(
      const AsyncData(<DateTime, List<Task>>{}),
    ),
    projectTasksProvider.overrideWith(
      (ref, projectId) => Stream<List<Task>>.value(projectTasks ?? const []),
    ),
    syncStateProvider.overrideWith(_TestSyncStateNotifier.new),
    folderExpandProvider.overrideWith(_TestFolderExpandNotifier.new),
  ];
  TodoRepository? repo;

  if (provideTestDatabase) {
    final db = openTestDatabase();
    addTearDown(db.close);
    repo = TodoRepository(database: db);
    repo.onDataChanged = null;
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
    overrides.addAll([
      todoRepositoryProvider.overrideWithValue(repo),
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
    ]);
  }

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: appRouter.configuration.routes,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: Consumer(
        builder: (context, ref, _) {
          final themeMode = ref.watch(themeModeProvider);
          final locale = ref.watch(localeProvider);
          final seedColor = ref.watch(themeSeedColorProvider);
          return MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.build(Brightness.light, seedColor: seedColor),
            darkTheme: AppTheme.build(Brightness.dark, seedColor: seedColor),
            themeMode: themeMode,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          );
        },
      ),
    ),
  );
  await _settle(tester);
  return repo;
}

Future<TodoRepository> pumpScopeSwitcherSheet(
  WidgetTester tester, {
  List<Project>? projects,
  List<Folder>? folders,
  List<CustomView>? customViews,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final cache = AppSettingsCache();
  final db = openTestDatabase();
  addTearDown(db.close);
  final repo = TodoRepository(database: db);

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

  final overrides = [
    appSettingsCacheProvider.overrideWithValue(cache),
    todoRepositoryProvider.overrideWithValue(repo),
    projectsStreamProvider.overrideWithValue(
      AsyncData(projects ?? const <Project>[]),
    ),
    foldersStreamProvider.overrideWithValue(
      AsyncData(folders ?? const <Folder>[]),
    ),
    customViewsStreamProvider.overrideWithValue(
      AsyncData(customViews ?? const <CustomView>[]),
    ),
    todayViewProvider.overrideWithValue(
      const AsyncData(TodayViewData(today: [], overdue: [])),
    ),
    syncStateProvider.overrideWith(_TestSyncStateNotifier.new),
    folderExpandProvider.overrideWith(_TestFolderExpandNotifier.new),
    projectTasksProvider.overrideWith(
      (ref, projectId) => Stream.value(const <Task>[]),
    ),
  ];

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, state) => const Scaffold(body: ScopeSwitcherSheet()),
      ),
      GoRoute(
        path: '/today',
        builder: (ctx, state) => const Scaffold(body: Text('TodayPage')),
      ),
      GoRoute(
        path: '/inbox',
        builder: (ctx, state) => const Scaffold(body: Text('InboxPage')),
      ),
      GoRoute(
        path: '/projects/:id',
        builder: (ctx, state) =>
            Scaffold(body: Text('Project:${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/settings',
        builder: (ctx, state) => const Scaffold(body: Text('SettingsPage')),
      ),
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
  await _settle(tester);
  return repo;
}

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

class _TestFolderExpandNotifier extends FolderExpandNotifier {
  @override
  Future<Map<String, bool>> build() async => const {};
}

class _TestSyncStateNotifier extends SyncStateNotifier {
  @override
  SyncState build() => SyncState.idle;
}

Folder _folder(String id, String name, {int sortOrder = 0}) => Folder(
  id: id,
  name: name,
  sortOrder: sortOrder,
  createdAt: 0,
  updatedAt: 0,
  deleted: 0,
);

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

void main() {
  setUp(() {
    // No locale set → defaults to zh (Chinese).
  });

  testWidgets(
    'Narrow (<600dp) smoke: modern-minimal hero header + no drawer/bottom bar',
    (tester) async {
      await pumpApp(tester, const Size(400, 800));

      // 启动默认页为 /today
      expect(find.text('今天还没有任务'), findsOneWidget);

      // 窄屏彻底移除 Drawer 与 BottomBar
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(AppSidebar), findsNothing);
      expect(find.byType(Drawer), findsNothing);
      expect(find.byIcon(Icons.menu), findsNothing);

      // 存在 PageHeroHeader
      expect(find.byType(PageHeroHeader), findsOneWidget);
    },
  );

  testWidgets(
    'Narrow mode: clicking hero title opens ScopeSwitcherSheet smoothly',
    (tester) async {
      await pumpApp(tester, const Size(400, 800));

      // 点击大标题
      await tester.tap(find.byType(PageHeroHeader));
      await tester.pumpAndSettle();

      // 底部弹层已显示
      expect(find.byType(ScopeSwitcherSheet), findsOneWidget);
      expect(find.text('今日'), findsOneWidget);
      expect(find.text('收件箱'), findsOneWidget);

      // 点击背景遮罩 → 弹层正常关闭
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.byType(ScopeSwitcherSheet), findsNothing);
    },
  );

  testWidgets('Wide (≥600dp) smoke: AppSidebar persistent sidebar', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1000, 800));

    // 宽屏固定常驻侧边栏
    expect(find.byType(AppSidebar), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byIcon(Icons.menu), findsNothing);
    expect(find.byType(Drawer), findsNothing);

    // 侧边栏包含系统组目的地
    expect(find.text('任务分组'), findsOneWidget);
    for (final label in ['收件箱', '今日', '日历']) {
      expect(
        find.descendant(
          of: find.byType(AppSidebar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets(
    'Adaptive layout: dynamically resizing window toggles sidebar & narrow mode',
    (tester) async {
      // 初始宽屏（1000dp）：固定显示 AppSidebar
      await pumpApp(tester, const Size(1000, 800));
      expect(find.byType(AppSidebar), findsOneWidget);

      // 动态调窄窗口（500dp）：自动隐藏 AppSidebar，切为现代极简单屏
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _settle(tester);

      expect(find.byType(AppSidebar), findsNothing);
      expect(find.byType(PageHeroHeader), findsOneWidget);

      // 再次动态调宽窗口（900dp）：自动恢复固定 AppSidebar
      tester.view.physicalSize = const Size(900, 800);
      await _settle(tester);

      expect(find.byType(AppSidebar), findsOneWidget);
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
      await _settle(tester);

      // 设置以右侧面板弹出
      expect(find.text('设置'), findsWidgets);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('主题模式'), findsOneWidget);

      // 点击关闭按钮 → 设置面板关闭
      await tester.tap(find.byIcon(Icons.close));
      await _settle(tester);

      expect(find.text('主题模式'), findsNothing);
    },
  );

  testWidgets('ScopeSwitcherSheet: system views switch (today & inbox)', (
    tester,
  ) async {
    await pumpScopeSwitcherSheet(tester);

    expect(find.byType(ScopeSwitcherSheet), findsOneWidget);
    expect(find.text('今日'), findsOneWidget);
    expect(find.text('收件箱'), findsOneWidget);
    expect(find.text('日历'), findsOneWidget);
    expect(find.text('概览'), findsOneWidget);

    await tester.tap(find.text('收件箱'));
    await _settle(tester);
    expect(find.text('InboxPage'), findsOneWidget);
  });

  testWidgets('ScopeSwitcherSheet: project list and navigation', (
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
    await pumpScopeSwitcherSheet(tester, projects: [project]);

    // 项目组：项目名
    expect(find.text('工作'), findsOneWidget);

    // 点击项目
    await tester.tap(find.text('工作'));
    await _settle(tester);
    expect(find.text('Project:p1'), findsOneWidget);
  });

  testWidgets('项目筛选：切换「进行中」/「全部」筛选任务', (tester) async {
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
      initialLocation: '/projects/p1',
      provideTestDatabase: false,
      projects: [project],
      projectTasks: [
        _seedTask('t-done', '已完成任务', TaskStatus.done),
        _seedTask('t-todo', '待办任务', TaskStatus.todo),
      ],
    );

    // 1. 初始：已完成 + 待办均显示
    expect(find.text('已完成任务'), findsOneWidget);
    expect(find.text('待办任务'), findsOneWidget);

    // 2. 切换到「进行中」
    await tester.tap(find.text('进行中'));
    await tester.pumpAndSettle();
    expect(find.text('已完成任务'), findsNothing);
    expect(find.text('待办任务'), findsOneWidget);

    // 3. 恢复「全部」
    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(find.text('已完成任务'), findsOneWidget);
    expect(find.text('待办任务'), findsOneWidget);
  });

  testWidgets('筛选进行中任务时行尾「未完成/总数」分母保持真实总数', (tester) async {
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
      initialLocation: '/projects/p1',
      provideTestDatabase: false,
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

    expect(find.text('父任务'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('子任务-完成'), findsOneWidget);
    expect(find.text('子任务-待办'), findsOneWidget);

    // 切换为「进行中」筛选
    await tester.tap(find.text('进行中'));
    await tester.pumpAndSettle();
    expect(find.text('子任务-完成'), findsNothing);
    expect(find.text('子任务-待办'), findsOneWidget);
    expect(find.text('父任务'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);

    // 切换回「全部」筛选
    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(find.text('子任务-完成'), findsOneWidget);
    expect(find.text('子任务-待办'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('项目仅含已完成任务且筛选「进行中」 → 显示「全部任务已完成」空态', (tester) async {
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
      initialLocation: '/projects/p1',
      provideTestDatabase: false,
      projects: [project],
      projectTasks: [_seedTask('t-done', '已完成任务', TaskStatus.done)],
    );

    expect(find.text('已完成任务'), findsOneWidget);

    await tester.tap(find.text('进行中'));
    await tester.pumpAndSettle();
    expect(find.text('已完成任务'), findsNothing);
    expect(find.text('全部任务已完成'), findsOneWidget);

    await tester.tap(find.text('全部'));
    await tester.pumpAndSettle();
    expect(find.text('已完成任务'), findsOneWidget);
    expect(find.text('全部任务已完成'), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('ScopeSwitcherSheet: add project opens the form dialog', (
    tester,
  ) async {
    await pumpScopeSwitcherSheet(tester);

    expect(find.byType(ScopeSwitcherSheet), findsOneWidget);

    // 底部「新建」
    await tester.tap(
      find.descendant(
        of: find.byType(ScopeSwitcherSheet),
        matching: find.text('新建'),
      ),
    );
    await _settle(tester);
    expect(find.byType(CreateListFolderSheet), findsOneWidget);

    await tester.tap(find.text('取消'));
    await _settle(tester);
    expect(find.byType(CreateListFolderSheet), findsNothing);
  });

  testWidgets(
    'ScopeSwitcherSheet: add folder via section header opens create sheet in folder mode',
    (tester) async {
      final repo = await pumpScopeSwitcherSheet(tester);

      expect(find.byType(ScopeSwitcherSheet), findsOneWidget);

      // 清单分组头的「+」按钮
      await tester.tap(find.byTooltip('新建文件夹'));
      await _settle(tester);
      expect(find.byType(CreateListFolderSheet), findsOneWidget);
      expect(find.text('文件夹名称'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byType(CreateListFolderSheet),
          matching: find.byType(TextField),
        ),
        '新文件夹',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('完成'));
      await _settle(tester);

      final folders = await repo.folders.getAll();
      expect(folders.length, 1);
      expect(folders.single.name, '新文件夹');
    },
  );

  testWidgets('ScopeSwitcherSheet: 文件夹分组显示 + 折叠/展开 + 未分组区', (tester) async {
    final folder = _folder('f1', '工作夹');
    final folderProject = _projectInFolder('p1', '项目A', 'f1');
    final ungroupedProject = _projectInFolder('p2', '项目B', null);
    await pumpScopeSwitcherSheet(
      tester,
      folders: [folder],
      projects: [folderProject, ungroupedProject],
    );

    expect(find.byType(ScopeSwitcherSheet), findsOneWidget);

    // 文件夹行 + 夹内项目行 + 未分组小标题 + 未分组项目行
    expect(
      find.descendant(
        of: find.byType(ScopeSwitcherSheet),
        matching: find.text('工作夹'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ScopeSwitcherSheet),
        matching: find.text('项目A'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ScopeSwitcherSheet),
        matching: find.text('未分组'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ScopeSwitcherSheet),
        matching: find.text('项目B'),
      ),
      findsOneWidget,
    );

    // 折叠文件夹
    await tester.tap(
      find.descendant(
        of: find.byType(ScopeSwitcherSheet),
        matching: find.text('工作夹'),
      ),
    );
    await _settle(tester);
    expect(
      find.descendant(
        of: find.byType(ScopeSwitcherSheet),
        matching: find.text('项目A'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(ScopeSwitcherSheet),
        matching: find.text('项目B'),
      ),
      findsOneWidget,
    );

    // 再次点击展开
    await tester.tap(
      find.descendant(
        of: find.byType(ScopeSwitcherSheet),
        matching: find.text('工作夹'),
      ),
    );
    await _settle(tester);
    expect(
      find.descendant(
        of: find.byType(ScopeSwitcherSheet),
        matching: find.text('项目A'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Settings: theme mode & language switch persist instantly', (
    tester,
  ) async {
    final cache = AppSettingsCache();
    await pumpApp(tester, const Size(1000, 800), settingsCache: cache);

    // 打开宽屏侧边栏设置
    await tester.tap(
      find.descendant(
        of: find.byType(AppSidebar),
        matching: find.byIcon(Icons.settings_outlined),
      ),
    );
    await _settle(tester);
    expect(find.text('设置'), findsWidgets);

    await tester.tap(find.text('深色'));
    await _settle(tester);

    expect(cache.get(themeModePrefKey), ThemeMode.dark.name);
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);

    await tester.tap(find.text('English'));
    await _settle(tester);

    expect(cache.get(localePrefKey), 'en');
    expect(find.text('Settings'), findsWidgets);
  });
}
