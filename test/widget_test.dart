// M0 骨架冒烟测试：应用启动、自适应导航、设置页主题/语言切换持久化。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:todo/app.dart';
import 'package:todo/features/settings/settings_providers.dart';

/// 以指定逻辑尺寸（dp）构建应用。
Future<void> pumpApp(WidgetTester tester, Size logicalSize) async {
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const TodoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('窄屏（<600dp）冒烟：默认今日页 + 底部 NavigationBar', (tester) async {
    await pumpApp(tester, const Size(400, 800));

    // 默认目的地为今日，AppBar 标题与导航标签均显示「今日」。
    expect(find.text('今日'), findsWidgets);
    expect(find.text('今天还没有任务'), findsOneWidget);

    // 窄屏使用底部 NavigationBar，无 NavigationRail。
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('宽屏（≥600dp）冒烟：NavigationRail 替代底部导航', (tester) async {
    await pumpApp(tester, const Size(1000, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('底部导航 4 tab 切换正常', (tester) async {
    await pumpApp(tester, const Size(400, 800));

    // 依次切换到日历/项目/标签，验证对应空态文案。
    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    expect(find.text('日历暂无安排'), findsOneWidget);

    await tester.tap(find.text('项目'));
    await tester.pumpAndSettle();
    expect(find.text('还没有项目'), findsOneWidget);

    await tester.tap(find.text('标签'));
    await tester.pumpAndSettle();
    expect(find.text('还没有标签'), findsOneWidget);
  });

  testWidgets('设置页：主题模式与语言切换即时生效并持久化', (tester) async {
    await pumpApp(tester, const Size(400, 800));

    // 进入设置页。
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('设置'), findsOneWidget);

    // 切换深色主题。
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(themeModePrefKey), ThemeMode.dark.name);
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);

    // 切换英文语言。
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(prefs.getString(localePrefKey), 'en');
    // 设置页标题即时变为英文。
    expect(find.text('Settings'), findsOneWidget);
  });
}
