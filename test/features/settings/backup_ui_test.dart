import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/backup/backup_restore_service.dart';
import 'package:todo/core/backup/snapshot_pool_service.dart';
import 'package:todo/core/db/database.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/core/security/secure_store.dart';
import 'package:todo/core/sync/snapshot.dart';
import 'package:todo/core/theme/app_theme.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/settings/settings_page.dart';
import 'package:todo/features/settings/settings_providers.dart';
import 'package:todo/features/settings/widgets/backup_section.dart';
import 'package:todo/features/settings/widgets/import_confirm_dialog.dart';
import 'package:todo/features/settings/widgets/snapshot_history_sheet.dart';
import 'package:todo/features/sync_setup/sync_setup_providers.dart';
import 'package:todo/features/tags/tag_providers.dart';

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

  group('Backup UI & Dialogs Tests', () {
    testWidgets('SettingsPage renders BackupSection with all items', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = AppDatabase.forTesting();
      addTearDown(db.close);
      final repo = TodoRepository(database: db);
      final secureStore = SecureStore(backend: _MemorySecureBackend());
      final cache = AppSettingsCache();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todoRepositoryProvider.overrideWithValue(repo),
            secureStoreProvider.overrideWithValue(secureStore),
            appSettingsCacheProvider.overrideWithValue(cache),
            tagsStreamProvider.overrideWithValue(const AsyncData([])),
          ],
          child: MaterialApp(
            theme: AppTheme.build(Brightness.light),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackupSection), findsOneWidget);
      expect(find.text('数据与安全备份'), findsOneWidget);
      expect(find.text('导出备份数据'), findsOneWidget);
      expect(find.text('导入备份文件'), findsOneWidget);
      expect(find.text('本地安全快照'), findsOneWidget);
      expect(find.text('快照保留时间'), findsOneWidget);
      expect(find.text('7 天'), findsOneWidget);

      // 验证备份区域全部 4 个图标均遵守主题主色（Theme.colorScheme.primary）
      final primaryColor = AppTheme.build(Brightness.light).colorScheme.primary;
      expect(tester.widget<Icon>(find.byIcon(Icons.file_upload_outlined)).color, equals(primaryColor));
      expect(tester.widget<Icon>(find.byIcon(Icons.file_download_outlined)).color, equals(primaryColor));
      expect(tester.widget<Icon>(find.byIcon(Icons.shield_outlined)).color, equals(primaryColor));
      expect(tester.widget<Icon>(find.byIcon(Icons.auto_delete_outlined)).color, equals(primaryColor));
    });

    testWidgets('Retention days dropdown updates provider and cache', (
      tester,
    ) async {
      final db = AppDatabase.forTesting();
      addTearDown(db.close);
      final repo = TodoRepository(database: db);
      final secureStore = SecureStore(backend: _MemorySecureBackend());
      final cache = AppSettingsCache();

      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todoRepositoryProvider.overrideWithValue(repo),
            secureStoreProvider.overrideWithValue(secureStore),
            appSettingsCacheProvider.overrideWithValue(cache),
            tagsStreamProvider.overrideWithValue(const AsyncData([])),
          ],
          child: MaterialApp(
            theme: AppTheme.build(Brightness.light),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  capturedRef = ref;
                  return const SingleChildScrollView(child: BackupSection());
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(capturedRef.read(backupRetentionDaysProvider), 7);

      // 打开下拉列表
      await tester.tap(find.text('7 天'));
      await tester.pumpAndSettle();

      // 选择 30 天
      await tester.tap(find.text('30 天').last);
      await tester.pumpAndSettle();

      expect(capturedRef.read(backupRetentionDaysProvider), 30);
      expect(cache.get(backupRetentionDaysPrefKey), '30');
    });

    testWidgets('ImportConfirmDialog displays summary and toggles mode', (
      tester,
    ) async {
      const summary = BackupSummary(
        exportedAt: 1773000000000,
        taskCount: 42,
        projectCount: 5,
        tagCount: 8,
        folderCount: 2,
        customViewCount: 3,
        snapshot: SnapshotData(
          schemaVersion: 3,
          deviceId: 'dev-1',
          exportedAt: 1773000000000,
        ),
      );

      ImportMode? confirmedMode;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(Brightness.light),
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    ImportConfirmDialog.show(
                      context,
                      summary: summary,
                      sourceTitle: 'test_backup.ordobak',
                      onConfirm: (mode) async {
                        confirmedMode = mode;
                      },
                    );
                  },
                  child: const Text('打开导入弹窗'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开导入弹窗'));
      await tester.pumpAndSettle();

      expect(find.text('确认导入备份'), findsOneWidget);
      expect(find.text('test_backup.ordobak'), findsOneWidget);
      expect(
        find.textContaining('包含：5 个清单 · 42 项任务 · 8 个标签 · 2 个文件夹 · 3 个视图'),
        findsOneWidget,
      );

      // 默认选中增量合并
      expect(find.text('增量合并（推荐）'), findsOneWidget);
      expect(find.text('全新覆盖'), findsOneWidget);

      // 切换为全新覆盖
      await tester.tap(find.text('全新覆盖'));
      await tester.pumpAndSettle();

      // 点击开始导入
      await tester.tap(find.text('开始导入'));
      await tester.pumpAndSettle();

      expect(confirmedMode, ImportMode.replace);
    });

    testWidgets(
      'SnapshotHistorySheet displays snapshot list and triggers restore',
      (tester) async {
        final tempDir = Directory.systemTemp.createTempSync(
          'ui_test_snapshots_',
        );
        addTearDown(() => tempDir.deleteSync(recursive: true));

        final db = AppDatabase.forTesting();
        addTearDown(db.close);
        final repo = TodoRepository(database: db);
        final backupService = BackupRestoreService(repo);
        final pool = SnapshotPoolService(
          backupService: backupService,
          settings: repo.settings,
          getDirectory: () async => tempDir,
        );

        // 预先写入 1 个清单并生成快照（通过 runAsync 允许底层真实文件 I/O 运行）
        late LocalSnapshotInfo snap;
        await tester.runAsync(() async {
          await repo.createProject(name: '测试项目', color: 0xFF123456);
          snap = await pool.createSnapshot(
            trigger: SnapshotTriggerType.dailyAuto,
          );
        });

        final snapshots = [snap];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              todoRepositoryProvider.overrideWithValue(repo),
              backupRestoreServiceProvider.overrideWithValue(backupService),
              snapshotPoolServiceProvider.overrideWithValue(pool),
              localSnapshotsProvider.overrideWith(
                () => _MockLocalSnapshotsNotifier(snapshots),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.build(Brightness.light),
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: SnapshotHistorySheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('本地安全快照历史'), findsOneWidget);
        expect(find.text(SnapshotTriggerType.dailyAuto.label), findsOneWidget);
        // 还原按钮已去掉文本以节省空间，通过 tooltip/icon 查验，确认无裸文字
        expect(find.byTooltip('还原'), findsOneWidget);
        expect(find.byIcon(Icons.settings_backup_restore_rounded), findsOneWidget);
        expect(find.widgetWithText(TextButton, '还原'), findsNothing);

        // 点击还原并在 runAsync 中等待异步读盘与弹窗打开
        await tester.runAsync(() async {
          await tester.tap(find.byTooltip('还原'));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        });
        await tester.pumpAndSettle();

        expect(find.text('确认导入备份'), findsOneWidget);
        expect(find.textContaining('快照点：'), findsOneWidget);

        // 点击取消关闭弹窗
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'SnapshotHistorySheet displays localized trigger labels in English (Pre-sync, etc.) and restore has no text',
      (tester) async {
        final db = AppDatabase.forTesting();
        addTearDown(db.close);
        final repo = TodoRepository(database: db);
        final backupService = BackupRestoreService(repo);

        final testSnapshots = <LocalSnapshotInfo>[
          LocalSnapshotInfo(
            filePath: '/tmp/ordo_daily.ordobak',
            fileName: '20260910_120000_daily.ordobak',
            sizeBytes: 1024,
            createdAt: DateTime(2026, 9, 10, 12, 0),
            taskCount: 5,
            projectCount: 2,
            tagCount: 1,
            folderCount: 0,
            customViewCount: 0,
            triggerType: SnapshotTriggerType.dailyAuto,
          ),
          LocalSnapshotInfo(
            filePath: '/tmp/ordo_presync.ordobak',
            fileName: '20260910_130000_presync.ordobak',
            sizeBytes: 2048,
            createdAt: DateTime(2026, 9, 10, 13, 0),
            taskCount: 6,
            projectCount: 2,
            tagCount: 1,
            folderCount: 0,
            customViewCount: 0,
            triggerType: SnapshotTriggerType.preSync,
          ),
          LocalSnapshotInfo(
            filePath: '/tmp/ordo_prerestore.ordobak',
            fileName: '20260910_140000_prerestore.ordobak',
            sizeBytes: 3072,
            createdAt: DateTime(2026, 9, 10, 14, 0),
            taskCount: 7,
            projectCount: 2,
            tagCount: 1,
            folderCount: 0,
            customViewCount: 0,
            triggerType: SnapshotTriggerType.preRestore,
          ),
          LocalSnapshotInfo(
            filePath: '/tmp/ordo_manual.ordobak',
            fileName: '20260910_150000_manual.ordobak',
            sizeBytes: 4096,
            createdAt: DateTime(2026, 9, 10, 15, 0),
            taskCount: 8,
            projectCount: 2,
            tagCount: 1,
            folderCount: 0,
            customViewCount: 0,
            triggerType: SnapshotTriggerType.manual,
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              todoRepositoryProvider.overrideWithValue(repo),
              backupRestoreServiceProvider.overrideWithValue(backupService),
              localSnapshotsProvider.overrideWith(
                () => _MockLocalSnapshotsNotifier(testSnapshots),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.build(Brightness.light),
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: SnapshotHistorySheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 验证英文属性标签
        expect(find.text('Daily Auto'), findsOneWidget);
        expect(find.text('Pre-sync'), findsOneWidget);
        expect(find.text('Pre-restore'), findsOneWidget);
        expect(find.text('Manual'), findsOneWidget);

        // 验证 4 个还原按钮无文本（无 Text('Restore')），均带 tooltip
        expect(find.text('Restore'), findsNothing);
        expect(find.byTooltip('Restore'), findsNWidgets(4));
        expect(find.byIcon(Icons.settings_backup_restore_rounded), findsNWidgets(4));
      },
    );

    testWidgets('SettingsPage About section adheres to new title and brand requirements', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = AppDatabase.forTesting();
      addTearDown(db.close);
      final repo = TodoRepository(database: db);
      final secureStore = SecureStore(backend: _MemorySecureBackend());
      final cache = AppSettingsCache();

      // 1. 中文语言测试
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todoRepositoryProvider.overrideWithValue(repo),
            secureStoreProvider.overrideWithValue(secureStore),
            appSettingsCacheProvider.overrideWithValue(cache),
            tagsStreamProvider.overrideWithValue(const AsyncData([])),
          ],
          child: MaterialApp(
            theme: AppTheme.build(Brightness.light),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 中文下应用名为「知序 Ordo」
      expect(find.text('ordo'), findsOneWidget);
      // 关于部分仅保留「知序（Zhī Xù）」，去掉了「Ordo（拉丁语）」的解释（_BrandMeaningItem 采用 RichText 渲染）
      // 关于部分仅保留「知序（Zhī Xù）」，去掉了「Ordo（拉丁语）」的解释（_BrandMeaningItem 采用 RichText 渲染）
      expect(find.textContaining('知序（Zhī Xù）', findRichText: true), findsOneWidget);
      expect(find.textContaining('Ordo（拉丁语）', findRichText: true), findsNothing);

      // 2. 英文语言测试
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todoRepositoryProvider.overrideWithValue(repo),
            secureStoreProvider.overrideWithValue(secureStore),
            appSettingsCacheProvider.overrideWithValue(cache),
            tagsStreamProvider.overrideWithValue(const AsyncData([])),
          ],
          child: MaterialApp(
            theme: AppTheme.build(Brightness.light),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 英文下应用名为「Ordo」
      expect(find.text('ordo'), findsAtLeastNWidgets(1));
      // 英文下也仅保留「知序 (Zhī Xù)」，无「Ordo (Latin)」
      expect(find.textContaining('知序 (Zhī Xù)', findRichText: true), findsOneWidget);
      expect(find.textContaining('Ordo (Latin)', findRichText: true), findsNothing);
    });
  });
}

class _MockLocalSnapshotsNotifier extends LocalSnapshotsNotifier {
  _MockLocalSnapshotsNotifier(this._initial);
  final List<LocalSnapshotInfo> _initial;

  @override
  Future<List<LocalSnapshotInfo>> build() async {
    return _initial;
  }
}
