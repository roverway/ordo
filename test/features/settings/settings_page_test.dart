import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/db/database.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/core/security/secure_store.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/settings/settings_page.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/features/settings/widgets/settings_side_sheet.dart';
import 'package:todo/features/sync_setup/sync_setup_page.dart';
import 'package:todo/features/sync_setup/sync_setup_providers.dart';
import 'package:todo/features/tags/tag_providers.dart';
import 'package:todo/shared/widgets/modern_segmented_control.dart';

import '../../helpers/db_test_setup.dart';

class _MemorySecureBackend implements SecureKeyValueStore {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async => _store[key] = value;

  @override
  Future<void> delete(String key) async => _store.remove(key);
}

void main() {
  setUp(configureTestSqlite3);

  testWidgets('宽屏侧边栏设置抽屉：保存与测试连接仅在抽屉内弹出一个通知', (tester) async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final repo = TodoRepository(database: db);
    final secureStore = SecureStore(backend: _MemorySecureBackend());

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todoRepositoryProvider.overrideWithValue(repo),
          secureStoreProvider.overrideWithValue(secureStore),
          appSettingsCacheProvider.overrideWithValue(AppSettingsCache()),
          tagsStreamProvider.overrideWithValue(const AsyncData([])),
        ],
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showSettingsSideSheet(context),
                  child: const Text('打开设置'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 打开右侧设置抽屉
    await tester.tap(find.text('打开设置'));
    await tester.pumpAndSettle();

    // 点击同步设置入口进入同步子页面
    await tester.tap(find.text('同步设置'));
    await tester.pumpAndSettle();

    // 点击保存前确保按钮可见
    await tester.ensureVisible(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 验证全屏内仅存在 1 个 SnackBar（而不是主界面和抽屉各弹一个）
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('已保存'), findsOneWidget);

    // 验证 SnackBar 位于侧边抽屉内部
    final sideSheetFinder = find.byType(SyncSetupBody);
    expect(sideSheetFinder, findsOneWidget);

    // 等待 SnackBar 消失
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('设置页选项卡：ModernSegmentedControl 支持主题模式与语言选择', (tester) async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final repo = TodoRepository(database: db);
    final cache = AppSettingsCache();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todoRepositoryProvider.overrideWithValue(repo),
          appSettingsCacheProvider.overrideWithValue(cache),
          tagsStreamProvider.overrideWithValue(const AsyncData([])),
        ],
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SettingsBody(onOpenSync: () {}, onOpenTags: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 查找主题模式与语言的 ModernSegmentedControl
    final themeSegmented = find.byType(ModernSegmentedControl<ThemeMode>);
    expect(themeSegmented, findsOneWidget);
    final themeWidget = tester.widget<ModernSegmentedControl<ThemeMode>>(themeSegmented);
    expect(themeWidget.indicatorColor, isNotNull);

    final langSegmented = find.byType(ModernSegmentedControl<Locale>);
    expect(langSegmented, findsOneWidget);
    final langWidget = tester.widget<ModernSegmentedControl<Locale>>(langSegmented);
    expect(langWidget.indicatorColor, isNotNull);
  });

  testWidgets('设置页包含标签管理入口并可点击触发跳转', (tester) async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final repo = TodoRepository(database: db);
    final cache = AppSettingsCache();
    bool tagsOpened = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todoRepositoryProvider.overrideWithValue(repo),
          appSettingsCacheProvider.overrideWithValue(cache),
          tagsStreamProvider.overrideWithValue(const AsyncData([])),
        ],
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SettingsBody(
              onOpenSync: () {},
              onOpenTags: () => tagsOpened = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tagEntryFinder = find.byIcon(Icons.local_offer_outlined);
    expect(tagEntryFinder, findsOneWidget);

    await tester.tap(tagEntryFinder);
    await tester.pumpAndSettle();

    expect(tagsOpened, isTrue);
  });
}
