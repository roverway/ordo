import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ordo/core/backup/snapshot_pool_service.dart';
import 'package:ordo/core/l10n/app_localizations.dart';
import 'package:ordo/core/theme/background_config.dart';
import 'package:ordo/features/custom_views/presentation/custom_view_editor_page.dart';
import 'package:ordo/features/projects/widgets/create_list_folder_sheet.dart';
import 'package:ordo/features/quadrant/models/quadrant_models.dart';
import 'package:ordo/features/quadrant/providers/quadrant_providers.dart';
import 'package:ordo/features/quadrant/widgets/quadrant_focus_sheet.dart';
import 'package:ordo/features/quadrant/widgets/quadrant_scope_filter_sheet.dart';
import 'package:ordo/features/settings/settings_page.dart';
import 'package:ordo/features/settings/settings_providers.dart';
import 'package:ordo/features/settings/widgets/snapshot_history_sheet.dart';
import 'package:ordo/features/settings/widgets/wallpaper_picker_sheet.dart';
import 'package:ordo/shared/widgets/scope_nav_content.dart';
import '../../widget_test.dart';

class _MockLocalSnapshotsNotifier extends LocalSnapshotsNotifier {
  @override
  Future<List<LocalSnapshotInfo>> build() async => const [];
}

void main() {
  const wideDesktopSize = Size(1280, 800);
  const mobileNarrowSize = Size(390, 844);

  group('桌面端二级弹窗与交互容器适配测试', () {
    testWidgets(
      '桌面宽屏 (>=600dp): 点击侧边栏设置按钮展示 SettingsSideSheet (右侧抽屉) 而非全屏路由跳转',
      (tester) async {
        await pumpApp(tester, wideDesktopSize, initialLocation: '/today');
        await tester.pumpAndSettle();

        // 桌面宽屏下，侧边栏常驻
        final settingsBtn = find.byTooltip('设置');
        expect(settingsBtn, findsOneWidget);

        // 点击设置按钮
        await tester.tap(settingsBtn);
        await tester.pumpAndSettle();

        // 验证 SettingsBody 被挂载于抽屉中
        expect(find.byType(SettingsBody), findsOneWidget);
        // 验证存在抽屉关闭按钮
        expect(find.byIcon(Icons.close), findsOneWidget);

        // 点击关闭按钮可关闭抽屉
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(find.byType(SettingsBody), findsNothing);
      },
    );

    testWidgets(
      '桌面宽屏 (>=600dp): 点击侧边栏新建自定义视图打开 CustomViewEditorSideSheet (右侧抽屉)',
      (tester) async {
        await pumpApp(tester, wideDesktopSize, initialLocation: '/today');
        await tester.pumpAndSettle();

        // 找到自定义视图区域的添加按钮
        final addCustomViewBtn = find.byTooltip('新建视图');
        expect(addCustomViewBtn, findsOneWidget);

        await tester.tap(addCustomViewBtn);
        await tester.pumpAndSettle();

        // 验证打开了 CustomViewEditorPage 作为抽屉
        expect(find.byType(CustomViewEditorPage), findsOneWidget);

        // 点击返回按钮关闭
        final backBtn = find.byIcon(Icons.arrow_back);
        expect(backBtn, findsOneWidget);
        await tester.tap(backBtn);
        await tester.pumpAndSettle();

        expect(find.byType(CustomViewEditorPage), findsNothing);
      },
    );

    testWidgets('桌面宽屏 (>=600dp): showCreateListFolderSheet 显示居中模态 Dialog', (
      tester,
    ) async {
      await pumpApp(tester, wideDesktopSize, initialLocation: '/today');
      await tester.pumpAndSettle();

      // 触发 showCreateListFolderSheet
      final navContext = tester.element(find.byType(ScopeNavContent));
      showCreateListFolderSheet(context: navContext);
      await tester.pumpAndSettle();

      // 验证展示为 Dialog
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(CreateListFolderSheet), findsOneWidget);

      // 点击取消按钮关闭 Dialog
      final cancelBtn = find.text('取消');
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('移动窄屏 (<600dp): showCreateListFolderSheet 显示底抽屉 BottomSheet', (
      tester,
    ) async {
      await pumpApp(tester, mobileNarrowSize, initialLocation: '/today');
      await tester.pumpAndSettle();

      // 获取上下文并调用 showCreateListFolderSheet
      final ctx = tester.element(find.byType(Scaffold).first);
      showCreateListFolderSheet(context: ctx);
      await tester.pumpAndSettle();

      // 窄屏下显示为 ModalBottomSheet，非 Dialog
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(CreateListFolderSheet), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);

      // 关闭
      final cancelBtn = find.text('取消');
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CreateListFolderSheet), findsNothing);
    });

    testWidgets(
      '桌面宽屏 (>=600dp): QuadrantScopeFilterSheet.show 显示居中模态 Dialog 且无抓手条',
      (tester) async {
        await pumpApp(tester, wideDesktopSize, initialLocation: '/quadrant');
        await tester.pumpAndSettle();

        final ctx = tester.element(find.byType(Scaffold).first);
        QuadrantScopeFilterSheet.show(ctx);
        await tester.pumpAndSettle();

        // 验证为 Dialog
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.byType(QuadrantScopeFilterSheet), findsOneWidget);

        // 验证点击「完成」按钮能正常关闭
        final doneBtn = find.text('完成');
        expect(doneBtn, findsOneWidget);
        await tester.tap(doneBtn);
        await tester.pumpAndSettle();

        expect(find.byType(Dialog), findsNothing);
      },
    );

    testWidgets(
      '移动窄屏 (<600dp): QuadrantScopeFilterSheet.show 显示底部抽屉 BottomSheet',
      (tester) async {
        await pumpApp(tester, mobileNarrowSize, initialLocation: '/quadrant');
        await tester.pumpAndSettle();

        final ctx = tester.element(find.byType(Scaffold).first);
        QuadrantScopeFilterSheet.show(ctx);
        await tester.pumpAndSettle();

        expect(find.byType(Dialog), findsNothing);
        expect(find.byType(QuadrantScopeFilterSheet), findsOneWidget);
        expect(find.byType(BottomSheet), findsOneWidget);

        // 点击完成关闭
        final doneBtn = find.text('完成');
        expect(doneBtn, findsOneWidget);
        await tester.tap(doneBtn);
        await tester.pumpAndSettle();

        expect(find.byType(QuadrantScopeFilterSheet), findsNothing);
      },
    );

    testWidgets('桌面宽屏 (>=600dp): showWallpaperPickerSheet 显示居中模态 Dialog', (
      tester,
    ) async {
      await pumpApp(tester, wideDesktopSize, initialLocation: '/today');
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(ScopeNavContent));
      showWallpaperPickerSheet(
        context: ctx,
        initialConfig: BackgroundConfig.none,
      );
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(WallpaperPickerSheet), findsOneWidget);

      // 点击外部蒙层关闭 Dialog
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('桌面宽屏 (>=600dp): SnapshotHistorySheet.show 显示居中模态 Dialog', (
      tester,
    ) async {
      tester.view.physicalSize = wideDesktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localSnapshotsProvider.overrideWith(
              _MockLocalSnapshotsNotifier.new,
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SizedBox.expand()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(Scaffold));
      SnapshotHistorySheet.show(ctx);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(SnapshotHistorySheet), findsOneWidget);

      // 点击蒙层区域关闭 Dialog
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('桌面宽屏 (>=600dp): QuadrantFocusSheet.show 显示居中模态 Dialog', (
      tester,
    ) async {
      const emptyQuadrantData = QuadrantData(
        q1UrgentImportant: [],
        q2NotUrgentImportant: [],
        q3UrgentUnimportant: [],
        q4NotUrgentUnimportant: [],
      );

      tester.view.physicalSize = wideDesktopSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quadrantDataProvider.overrideWith(
              (ref) => Stream.value(emptyQuadrantData),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SizedBox.expand()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(Scaffold));
      QuadrantFocusSheet.show(ctx, QuadrantType.urgentImportant);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(QuadrantFocusSheet), findsOneWidget);

      // 点击关闭按钮
      final closeBtn = find.byIcon(Icons.close);
      expect(closeBtn, findsOneWidget);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    });
  });
}
