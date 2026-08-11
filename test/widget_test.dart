// Smoke tests: app launch, adaptive navigation, tab switch, settings.
// Updated for M5 visual redesign: 5-tab navigation, inbox as home.
// Default locale is zh (Chinese); tests reflect this.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:todo/app.dart';
import 'package:todo/core/db/database.dart';
import 'package:todo/features/calendar/calendar_providers.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/features/tags/tag_providers.dart';
import 'package:todo/features/tasks/task_providers.dart';
import 'package:todo/features/today/today_providers.dart';
import 'helpers/db_test_setup.dart';

/// Build and pump the app at a given logical size.
Future<void> pumpApp(
  WidgetTester tester,
  Size logicalSize, {
  bool provideTestDatabase = false,
}) async {
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final prefs = await SharedPreferences.getInstance();
  final overrides = [
    sharedPreferencesProvider.overrideWithValue(prefs),
    projectsStreamProvider.overrideWithValue(const AsyncData([])),
    projectTasksProvider.overrideWith(
      (ref, projectId) => const Stream<List<Task>>.empty(),
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

  testWidgets('Narrow (<600dp) smoke: inbox home + bottom NavigationBar', (
    tester,
  ) async {
    await pumpApp(tester, const Size(400, 800));

    // Inbox is the home; text in Chinese (default locale).
    // The nav bar shows navInbox ("收件箱") and the page shows emptyInbox.
    expect(find.text('收件箱'), findsWidgets);
    expect(find.text('收件箱是空的，去添加任务吧'), findsOneWidget);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('Wide (≥600dp) smoke: NavigationRail replaces bottom nav', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1000, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('Bottom nav 5-tab switch works correctly', (tester) async {
    await pumpApp(tester, const Size(400, 800));

    // Start on inbox (default locale: zh).
    expect(find.text('收件箱是空的，去添加任务吧'), findsOneWidget);

    // Switch to Today.
    await tester.tap(find.text('今日'));
    await tester.pumpAndSettle();
    expect(find.text('今天还没有任务'), findsOneWidget);

    // Switch to Calendar.
    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    expect(find.text('日历暂无安排'), findsOneWidget);

    // Switch to Projects.
    await tester.tap(find.text('项目'));
    await tester.pumpAndSettle();
    expect(find.text('还没有项目'), findsOneWidget);

    // Switch to Tags.
    await tester.tap(find.text('标签'));
    await tester.pumpAndSettle();
    expect(find.text('还没有标签'), findsOneWidget);
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
