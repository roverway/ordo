// Smoke tests: app launch, adaptive navigation, tab switch, settings.
// Updated for M5 batch-2 IA: narrow = hamburger drawer (system + projects)
// + 3-tab bottom bar; wide = 5-destination NavigationRail.
// Default locale is zh (Chinese); tests reflect this.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:todo/app.dart';
import 'package:todo/core/db/database.dart';
import 'package:todo/core/theme/app_tokens.dart';
import 'package:todo/features/calendar/calendar_providers.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/features/tags/tag_providers.dart';
import 'package:todo/features/tasks/task_providers.dart';
import 'package:todo/features/today/today_providers.dart';
import 'package:todo/router.dart';
import 'helpers/db_test_setup.dart';

/// Build and pump the app at a given logical size.
///
/// [projects]：抽屉项目组渲染数据（窄屏导航测试用，默认空）。
Future<void> pumpApp(
  WidgetTester tester,
  Size logicalSize, {
  bool provideTestDatabase = false,
  List<Project>? projects,
}) async {
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final prefs = await SharedPreferences.getInstance();
  final overrides = [
    sharedPreferencesProvider.overrideWithValue(prefs),
    projectsStreamProvider.overrideWithValue(
      AsyncData(projects ?? const <Project>[]),
    ),
    // 立即 emit 空列表（Stream.empty 永不 emit，会让任务树停在 loading）。
    projectTasksProvider.overrideWith(
      (ref, projectId) => Stream<List<Task>>.value(const []),
    ),
  ];

  if (provideTestDatabase) {
    final db = openTestDatabase();
    final repo = TodoRepository(database: db);
    overrides.add(todoRepositoryProvider.overrideWithValue(repo));
  } else {
    // Without a real DB, mock inbox providers so the app doesn't crash.
    final dummyProject = Project(
      id: 'inbox',
      name: 'Inbox',
      color: 0xFF7C6FF7,
      sortOrder: 0,
      createdAt: 0,
      updatedAt: 0,
      deleted: 0,
    );
    overrides.addAll([
      inboxProjectProvider.overrideWithValue(AsyncData(dummyProject)),
      inboxTasksProvider.overrideWithValue(const AsyncData([])),
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

  // appRouter 是进程级单例，测试之间会残留上次导航位置
  //（如上一测试跳到 /projects/:id 的独立页，无 AppShell 汉堡/设置图标）。
  // 每次 pump 前重置回首页，与 initialLocation 一致。
  appRouter.go('/inbox');

  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: const TodoApp()),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // No locale set → defaults to zh (Chinese).
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Narrow (<600dp) smoke: inbox home + hamburger + 3-tab bar', (
    tester,
  ) async {
    await pumpApp(tester, const Size(400, 800));

    // Inbox is the home; text in Chinese (default locale).
    expect(find.text('收件箱是空的，去添加任务吧'), findsOneWidget);

    // 底部 NavigationBar 精简为 3 个系统入口（今日/日历/标签），
    // 收集箱与项目移入抽屉（55-ui-redesign §3.1）。
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    for (final label in ['今日', '日历', '标签']) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('项目'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('收件箱'),
      ),
      findsNothing,
    );

    // 窄屏 AppBar 有汉堡入口；抽屉未打开时不渲染。
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);

    // 评审回归断言：inbox（默认首页）不在底栏 3 入口中，底栏必须「无选中」——
    // 局部 Theme 将 indicator 置透明（不允许误亮「今日」，Flutter 断言
    // selectedIndex 必须合法，故无法用非法 index 表达无选中）。
    final navTheme = Theme.of(
      tester.element(find.byType(NavigationBar)),
    ).navigationBarTheme;
    expect(navTheme.indicatorColor, Colors.transparent);
  });

  testWidgets(
    'Wide (≥600dp) smoke: NavigationRail 5 destinations, no hamburger',
    (tester) async {
      await pumpApp(tester, const Size(1000, 800));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      // 宽屏无汉堡（Rail 已含导航），无抽屉。
      expect(find.byIcon(Icons.menu), findsNothing);
      expect(find.byType(Drawer), findsNothing);
      // Rail 5 目的地保持不变（收集箱/今日/日历/项目/标签）。
      for (final label in ['收件箱', '今日', '日历', '项目', '标签']) {
        expect(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('Bottom nav 3-tab switch works correctly', (tester) async {
    await pumpApp(tester, const Size(400, 800));

    // Start on inbox (default locale: zh).
    expect(find.text('收件箱是空的，去添加任务吧'), findsOneWidget);

    // Switch to Today.
    await tester.tap(find.text('今日'));
    await tester.pumpAndSettle();
    expect(find.text('今天还没有任务'), findsOneWidget);
    // 命中底栏路由后「无选中」Theme 覆盖解除（indicator 恢复非透明）。
    final todayNavTheme = Theme.of(
      tester.element(find.byType(NavigationBar)),
    ).navigationBarTheme;
    expect(todayNavTheme.indicatorColor, isNot(Colors.transparent));

    // Switch to Calendar.
    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    expect(find.text('日历暂无安排'), findsOneWidget);

    // Switch to Tags.
    await tester.tap(find.text('标签'));
    await tester.pumpAndSettle();
    expect(find.text('还没有标签'), findsOneWidget);
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

    // 系统组：今日 → 今日页（抽屉内点击，避免匹配到底部 tab）。
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('今日')),
    );
    await tester.pumpAndSettle();
    expect(find.text('今天还没有任务'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing); // 点击后抽屉自动关闭。

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

    // 点击项目 → /projects/:id（AppBar 标题 = 项目名）。
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('工作')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsNothing);
    expect(find.text('工作'), findsOneWidget);
  });

  testWidgets('Drawer: add project opens the form dialog', (tester) async {
    await pumpApp(tester, const Size(400, 800));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // 底部「新建项目」→ 复用 project_form_dialog。
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('新建项目')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    // 取消关闭，不落库。
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Settings: theme mode & language switch persist instantly', (
    tester,
  ) async {
    await pumpApp(tester, const Size(400, 800));

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    // Default locale is zh.
    expect(find.text('设置'), findsOneWidget);

    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(themeModePrefKey), ThemeMode.dark.name);
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(prefs.getString(localePrefKey), 'en');
    expect(find.text('Settings'), findsOneWidget);
  });
}
