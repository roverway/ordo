import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/shared/widgets/spotlight_pull_scope.dart';

void main() {
  Widget buildTestApp({required VoidCallback onTrigger}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: SpotlightPullScope(
            onTrigger: onTrigger,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              itemCount: 30,
              itemBuilder: (context, index) =>
                  ListTile(title: Text('Item $index')),
            ),
          ),
        ),
      ),
    );
  }

  group('SpotlightPullScope 下拉搜索测试', () {
    testWidgets('初始状态下不展示弹性搜索提示，列表正常渲染', (tester) async {
      await tester.pumpWidget(buildTestApp(onTrigger: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsNothing);
    });

    testWidgets('微幅下拉（超过阈值前）展示弹性提示及继续下拉文案，不触发搜索', (tester) async {
      var triggered = false;
      await tester.pumpWidget(buildTestApp(onTrigger: () => triggered = true));
      await tester.pumpAndSettle();

      // 下拉 80 像素（低于 600 * 0.25 = 150 阈值）
      final gesture = await tester.startGesture(const Offset(200, 100));
      await gesture.moveBy(const Offset(0, 80));
      await tester.pump();

      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.text('继续下拉搜索'), findsOneWidget);
      expect(triggered, isFalse);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.search_rounded), findsNothing);
    });

    testWidgets('下拉超过屏幕高度 25% 阈值，提示进入释放文案并触发回调', (tester) async {
      var triggerCount = 0;
      await tester.pumpWidget(buildTestApp(onTrigger: () => triggerCount++));
      await tester.pumpAndSettle();

      // 下拉 180 像素（超过 600 * 0.25 = 150 阈值）
      final gesture = await tester.startGesture(const Offset(200, 100));
      await gesture.moveBy(const Offset(0, 180));
      await tester.pump();

      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.text('松手进入搜索'), findsOneWidget);
      expect(triggerCount, 1);

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  testWidgets('英文环境下展示英文弹性搜索提示文案', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: SpotlightPullScope(
              onTrigger: () {},
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                itemCount: 30,
                itemBuilder: (context, index) =>
                    ListTile(title: Text('Item $index')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(const Offset(200, 100));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();

    expect(find.text('Pull down to search'), findsOneWidget);

    await gesture.moveBy(const Offset(0, 220));
    await tester.pump();
    expect(find.text('Release to search'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
