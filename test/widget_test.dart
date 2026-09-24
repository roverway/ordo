import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:todo/core/db/database.dart';
import 'package:todo/core/db/repositories/todo_repository.dart';
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
import 'package:todo/shared/widgets/page_hero_header.dart';
import 'package:todo/shared/widgets/scope_switcher_sheet.dart';
import 'package:todo/shared/widgets/app_drawer.dart';
import 'package:todo/shared/widgets/scope_nav_content.dart';
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

      // 彻底移除 Drawer、BottomBar 与旧侧边栏
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(Drawer), findsNothing);
      expect(find.byIcon(Icons.menu), findsNothing);

      // 存在 PageHeroHeader
      expect(find.byType(PageHeroHeader), findsOneWidget);
    },
  );

  testWidgets(
    'Unified navigation: clicking hero title opens ScopeSwitcherSheet on wide & narrow screens',
    (tester) async {
      await pumpApp(tester, const Size(1000, 800));

      // 点击大标题打开 ScopeSwitcherSheet
      await tester.tap(
        find.descendant(
          of: find.byType(PageHeroHeader),
          matching: find.byType(InkWell),
        ),
      );
      await tester.pumpAndSettle();

      // 弹层已显示
      expect(find.byType(ScopeSwitcherSheet), findsOneWidget);
      expect(find.descendant(of: find.byType(ScopeSwitcherSheet), matching: find.text('今日')), findsOneWidget);
      expect(find.descendant(of: find.byType(ScopeSwitcherSheet), matching: find.text('收件箱')), findsOneWidget);

      // 点击背景遮罩 → 弹层正常关闭
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.byType(ScopeSwitcherSheet), findsNothing);
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
    final p1 = _projectInFolder('p1', '工作清单', null);
    final p2 = _projectInFolder('p2', '生活清单', null);
    await pumpScopeSwitcherSheet(tester, projects: [p1, p2]);

    expect(find.text('工作清单'), findsOneWidget);
    expect(find.text('生活清单'), findsOneWidget);

    await tester.tap(find.text('工作清单'));
    await _settle(tester);
    expect(find.text('Project:p1'), findsOneWidget);
  });

  testWidgets('ScopeSwitcherSheet: add project opens the form dialog', (
    tester,
  ) async {
    await pumpScopeSwitcherSheet(tester);

    // 点击底部“新建”
    await tester.tap(find.text('新建'));
    await _settle(tester);

    // 弹出创建弹窗
    expect(find.byType(CreateListFolderSheet), findsOneWidget);
    expect(find.text('新建清单'), findsOneWidget);
  });

  testWidgets(
    'ScopeSwitcherSheet: add folder via section header opens create sheet in folder mode',
    (tester) async {
      await pumpScopeSwitcherSheet(tester);

      // 点击“清单”区域右上角加号
      await tester.tap(find.byTooltip('新建文件夹'));
      await _settle(tester);

      expect(find.byType(CreateListFolderSheet), findsOneWidget);
      expect(find.text('新建文件夹'), findsOneWidget);
    },
  );

  testWidgets('ScopeSwitcherSheet: 文件夹分组显示 + 折叠/展开 + 未分组区', (tester) async {
    final folder1 = _folder('f1', '工作夹', sortOrder: 0);
    final p1 = _projectInFolder('p1', '项目A', 'f1');
    final p2 = _projectInFolder('p2', '项目B', null);

    await pumpScopeSwitcherSheet(
      tester,
      folders: [folder1],
      projects: [p1, p2],
    );

    expect(find.text('工作夹'), findsOneWidget);
    expect(find.text('未分组'), findsOneWidget);
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
        matching: find.text('项目B'),
      ),
      findsOneWidget,
    );

    // 点击折叠工作夹
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
    await pumpApp(
      tester,
      const Size(1000, 800),
      initialLocation: '/settings',
      settingsCache: cache,
    );

    expect(find.text('设置'), findsWidgets);

    // 切换为深色模式
    await tester.tap(find.text('深色'));
    await _settle(tester);

    expect(cache.get(themeModePrefKey), ThemeMode.dark.name);
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);

    // 切换语言为英文
    await tester.tap(find.text('English'));
    await _settle(tester);

    expect(cache.get(localePrefKey), 'en');
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets(
    'Desktop responsive: Wide screen (>=600dp) mounts AppSidebar with ScopeNavContent and FlowTodo header',
    (tester) async {
      await pumpApp(tester, const Size(1200, 800));

      // 宽屏常驻侧边栏已挂载
      expect(find.byType(AppSidebar), findsOneWidget);
      expect(find.byType(ScopeNavContent), findsOneWidget);
      expect(find.text('知序 Ordo'), findsOneWidget);

      // 侧边栏包含系统视图
      expect(
        find.descendant(of: find.byType(AppSidebar), matching: find.text('今日')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(AppSidebar), matching: find.text('收件箱')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Desktop responsive: Wide screen sidebar clicks switch routes directly',
    (tester) async {
      await pumpApp(tester, const Size(1200, 800));

      final inboxTile = find.descendant(
        of: find.byType(AppSidebar),
        matching: find.text('收件箱'),
      );
      expect(inboxTile, findsOneWidget);

      await tester.tap(inboxTile);
      await _settle(tester);

      // 直接切换路由至收件箱，无需底部弹窗
      expect(find.byType(ScopeSwitcherSheet), findsNothing);
      expect(find.text('收件箱'), findsWidgets);
    },
  );

  testWidgets(
    'Mobile responsive: Narrow screen (<600dp) has zero sidebar and zero drawer',
    (tester) async {
      await pumpApp(tester, const Size(400, 800));

      expect(find.byType(AppSidebar), findsNothing);
      expect(find.byType(Drawer), findsNothing);
    },
  );
}
