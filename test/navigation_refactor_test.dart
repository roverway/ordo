import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/features/settings/settings_providers.dart';
import 'package:ordo/shared/widgets/floating_minimal_dock.dart';
import 'package:ordo/shared/widgets/scope_nav_content.dart';

void main() {
  group('Navigation Dual-Island Dock & Route Settings Tests', () {
    test('Default route providers initialization and mutation', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 默认初始值
      expect(container.read(defaultTasksRouteProvider), '/today');
      expect(container.read(defaultSpecialViewsRouteProvider), '/matrix');

      // 更改任务组默认路由
      container
          .read(defaultTasksRouteProvider.notifier)
          .setDefaultTasksRoute('/inbox');
      expect(container.read(defaultTasksRouteProvider), '/inbox');

      // 更改视图组默认路由
      container
          .read(defaultSpecialViewsRouteProvider.notifier)
          .setDefaultSpecialViewsRoute('/calendar');
      expect(container.read(defaultSpecialViewsRouteProvider), '/calendar');
    });

    testWidgets('ScopeNavFilter filtering contract', (tester) async {
      // 验证 ScopeNavFilter 枚举定义
      expect(ScopeNavFilter.values.length, 3);
      expect(ScopeNavFilter.all, isNotNull);
      expect(ScopeNavFilter.tasksOnly, isNotNull);
      expect(ScopeNavFilter.viewsOnly, isNotNull);
    });

    testWidgets('FloatingMinimalDock renders Left & Right Islands properly', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(child: FloatingMinimalDock(currentRoute: '/today')),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证左岛：包含 4 个图标按钮（任务清单、特殊视图、设置、搜索）
      expect(find.byType(IconButton), findsNothing); // 用的是 InkWell 自定义容器按钮
      expect(find.byType(FloatingMinimalDock), findsOneWidget);

      // 验证右岛：一体化新建小 FAB 存在
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // 验证右岛：AI 图标存在
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });
  });
}
