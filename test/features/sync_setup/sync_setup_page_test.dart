// 同步配置页 Widget 测试（M4 同步 UI 接线，docs/50-ui-ux.md §5.7）。
//
// 覆盖：默认 WebDAV 表单字段、切换到 S3 显示对应凭据字段、
// 保存（非敏感项 → settings 表；凭据 → secure storage 内存 Fake）。
//
// 注入：内存 DB（AppDatabase.forTesting）+ 内存 SecureKeyValueStore，
// 不依赖真实网络与平台存储（flutter_secure_storage 平台通道）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo/core/db/database.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/core/security/secure_store.dart';
import 'package:todo/core/sync/sync_engine.dart';
import 'package:todo/features/projects/project_providers.dart';
import 'package:todo/features/sync_setup/sync_setup_page.dart';
import 'package:todo/features/sync_setup/sync_setup_providers.dart';

import '../../helpers/db_test_setup.dart';

/// 内存安全存储后端（SecureKeyValueStore 可注入，对齐 secure_store_test 用法）。
class _MemorySecureBackend implements SecureKeyValueStore {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async => _store[key] = value;

  @override
  Future<void> delete(String key) async => _store.remove(key);
}

/// 固定错误态 Notifier（errorCode=network，验证 UI 按错误码映射 ARB 文案，
/// 而非展示引擎原始 message）。
class _ErrorSyncNotifier extends SyncStateNotifier {
  @override
  SyncState build() => const SyncState(
    status: SyncStateStatus.error,
    errorCode: SyncErrorCode.network,
  );
}

/// Pump 同步配置页（zh locale，与生产默认语言一致）。
Future<void> _pumpSyncPage(
  WidgetTester tester, {
  required TodoRepository repo,
  required SecureStore secureStore,
  SyncStateNotifier Function()? stateOverride,
}) async {
  // 高画布（400×1400）：窄屏全宽 + 全部卡片可见（保存按钮在列表底部，
  // 默认 600 高画布会落在 ListView 折叠区外）。
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        todoRepositoryProvider.overrideWithValue(repo),
        secureStoreProvider.overrideWithValue(secureStore),
        if (stateOverride != null)
          syncStateProvider.overrideWith(stateOverride),
      ],
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SyncSetupPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(configureTestSqlite3);

  testWidgets('默认 WebDAV 表单；切换到 S3 显示对应凭据字段', (tester) async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final repo = TodoRepository(database: db);
    final secureStore = SecureStore(backend: _MemorySecureBackend());
    await _pumpSyncPage(tester, repo: repo, secureStore: secureStore);

    // 默认 WebDAV：服务器地址 / 用户名 / 密码；无 S3 字段。
    expect(find.text('服务器地址'), findsOneWidget);
    expect(find.text('Bucket'), findsNothing);

    // 切换到 S3 兼容桶：Endpoint / Access Key / Bucket 等出现。
    await tester.tap(find.text('S3 兼容桶'));
    await tester.pumpAndSettle();
    expect(find.text('Endpoint'), findsOneWidget);
    expect(find.text('Access Key'), findsOneWidget);
    expect(find.text('Bucket'), findsOneWidget);
  });

  testWidgets('保存：非敏感项写入 settings 表，凭据写入 secure storage', (tester) async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final repo = TodoRepository(database: db);
    final backend = _MemorySecureBackend();
    final secureStore = SecureStore(backend: backend);
    await _pumpSyncPage(tester, repo: repo, secureStore: secureStore);

    // 填服务器地址并保存（未启用同步 → 不校验必填，§10.1）。
    await tester.enterText(
      find.byType(TextField).first,
      'https://dav.example.com/todo/',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('已保存'), findsOneWidget);

    // 非敏感项落 settings 表；凭据落 secure storage（内存 Fake）。
    final settings = await repo.settings.getAll();
    expect(settings['sync_type'], 'webdav');
    expect(settings['sync_enabled'], '0');
    expect(
      await backend.read('sync_webdav_serverUrl'),
      'https://dav.example.com/todo/',
    );

    // 走完 SnackBar 自动消失计时器，避免测试结束挂起 Timer。
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('错误状态卡：按 errorCode 展示 ARB 映射文案', (tester) async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final repo = TodoRepository(database: db);
    final secureStore = SecureStore(backend: _MemorySecureBackend());
    await _pumpSyncPage(
      tester,
      repo: repo,
      secureStore: secureStore,
      stateOverride: _ErrorSyncNotifier.new,
    );

    // 标题为通用「同步失败」，副标题为 ARB 网络错误文案（不展示原始 message）。
    expect(find.text('同步失败'), findsOneWidget);
    expect(find.text('网络连接失败或超时'), findsOneWidget);
  });
}
