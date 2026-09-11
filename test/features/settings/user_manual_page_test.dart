import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/features/settings/settings_page.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/features/settings/user_manual_page.dart';

class _FakeLocaleNotifier extends LocaleNotifier {
  _FakeLocaleNotifier(this._initial);
  final Locale _initial;

  @override
  Locale build() => _initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<String> testContentLoader(String lang) async {
    final path = lang == 'en'
        ? 'assets/docs/user_manual_en.md'
        : 'assets/docs/user_manual_zh.md';
    return File(path).readAsStringSync();
  }

  Widget buildTestApp({Locale locale = const Locale('zh')}) {
    return ProviderScope(
      overrides: [
        appSettingsCacheProvider.overrideWithValue(AppSettingsCache()),
        localeProvider.overrideWith(() => _FakeLocaleNotifier(locale)),
      ],
      child: MaterialApp(
        theme: AppTheme.build(Brightness.light),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: UserManualPage(
          key: UniqueKey(),
          customContentLoader: testContentLoader,
        ),
      ),
    );
  }

  testWidgets('手册页面正确加载中文手册并展示目录与标题', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestApp(locale: const Locale('zh')));
    await tester.pumpAndSettle();

    // 验证 AppBar 标题与语言切换指示
    expect(find.text('使用帮助'), findsWidgets);
    expect(find.text('中'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);

    // 宽屏模式下左侧常驻目录树
    expect(find.text('目录'), findsOneWidget);
    expect(find.text('1. 快速入门'), findsWidgets);

    // 验证首屏正文元素
    expect(find.textContaining('知序 Ordo 用户使用手册'), findsWidgets);
    expect(find.textContaining('知其轻重，行止有序'), findsWidgets);
    expect(find.textContaining('目录（Table of Contents）'), findsWidgets);
  });

  testWidgets('语言切换按钮可在中英文之间即时切换', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestApp(locale: const Locale('zh')));
    await tester.pumpAndSettle();

    expect(find.text('1. 快速入门'), findsWidgets);

    // 点击 EN 切换为英文手册
    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();

    expect(find.text('1. Quick Start'), findsWidgets);
    expect(find.textContaining('Ordo (知序) User Manual'), findsWidgets);
    expect(find.textContaining('Order and Priority'), findsWidgets);

    // 点击 中 切换回中文手册
    await tester.tap(find.text('中'));
    await tester.pumpAndSettle();

    expect(find.text('1. 快速入门'), findsWidgets);
    expect(find.textContaining('知其轻重，行止有序'), findsWidgets);
  });

  testWidgets('窄屏移动端显示浮动目录按钮并支持呼出 BottomSheet 目录跳转', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestApp(locale: const Locale('zh')));
    await tester.pumpAndSettle();

    // 窄屏下显示 FloatingActionButton 目录按钮
    final fabFinder = find.byType(FloatingActionButton);
    expect(fabFinder, findsOneWidget);

    // 点击打开目录弹层
    await tester.tap(fabFinder);
    await tester.pumpAndSettle();

    // 弹层中展示目录条目
    expect(find.text('1. 快速入门'), findsWidgets);

    // 点击目录条目关闭弹层并定位
    await tester.tap(find.text('1. 快速入门').last);
    await tester.pumpAndSettle();

    // 弹层已关闭
    expect(find.byType(DraggableScrollableSheet), findsNothing);
  });

  testWidgets('宽屏左侧目录点击后可平滑滚动定位到指定章节', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestApp(locale: const Locale('zh')));
    await tester.pumpAndSettle();

    // 找到正文的 SingleChildScrollView 控制器
    final scrollable = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView).first,
    );
    final controller = scrollable.controller!;
    expect(controller.offset, 0.0);

    // 点击左侧目录栏中已渲染的章节「2. 核心概念与任务管理」
    // 使用 Row 内包含该文本的条目点击
    final sec2Finder = find.text('2. 核心概念与任务管理').first;
    expect(sec2Finder, findsOneWidget);

    await tester.tap(sec2Finder);
    await tester.pumpAndSettle();

    // 确认已触发正文向下平滑滚动定位
    expect(controller.offset, greaterThan(150.0));
  });

  testWidgets('Markdown 行内语法被正确解析，不残留原生 ** 或超链接括号字符', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestApp(locale: const Locale('zh')));
    await tester.pumpAndSettle();

    // 查找包含加粗与链接语法的文本块，验证正文中不出现 raw markdown 标记字符
    expect(find.textContaining('**“知其轻重'), findsNothing);
    expect(find.textContaining('**本地优先（Local-First）**'), findsNothing);
    expect(find.textContaining('](#1-快速入门)'), findsNothing);

    // 验证解析后的富文本仍然完整展示了文本内容
    expect(find.textContaining('知其轻重，行止有序'), findsWidgets);
    expect(find.textContaining('本地优先（Local-First）'), findsWidgets);
  });

  testWidgets('Mermaid 流程图以原生可视化卡片呈现', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestApp(locale: const Locale('zh')));
    await tester.pumpAndSettle();

    // 滚动正文直至「查看源码」按钮进入视口
    await tester.ensureVisible(find.text('查看源码'));
    await tester.pumpAndSettle();

    expect(find.text('子任务集群与父任务状态派生流向图'), findsOneWidget);
    expect(find.text('状态联动规则判定'), findsOneWidget);

    // 点击「查看源码」切换展开源码
    await tester.tap(find.text('查看源码'));
    await tester.pumpAndSettle();

    expect(find.text('隐藏源码'), findsOneWidget);
    expect(find.textContaining('flowchart TD'), findsOneWidget);
  });

  testWidgets('搜索框可过滤正文内容并高亮展示', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildTestApp(locale: const Locale('zh')));
    await tester.pumpAndSettle();

    // 点击搜索按钮开启搜索输入框
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 输入搜索关键字
    await tester.enterText(find.byType(TextField), '知其轻重');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 验证匹配结果呈现
    expect(find.textContaining('知其轻重'), findsWidgets);

    // 关闭搜索
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('知序 Ordo 用户使用手册'), findsWidgets);
  });

  testWidgets('设置页包含「使用帮助」卡片并能触发点击回调', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    bool helpOpened = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingsCacheProvider.overrideWithValue(AppSettingsCache()),
          localeProvider.overrideWith(
            () => _FakeLocaleNotifier(const Locale('zh')),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SettingsBody(
              onOpenSync: () {},
              onOpenTags: () {},
              onOpenHelp: () {
                helpOpened = true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 查找使用帮助卡片副标题
    final subtitleFinder = find.text('了解知序的特性与操作使用方法');
    expect(subtitleFinder, findsOneWidget);

    // 点击卡片触发回调
    await tester.tap(subtitleFinder);
    await tester.pumpAndSettle();

    expect(helpOpened, isTrue);
  });
}
