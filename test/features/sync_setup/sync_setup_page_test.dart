// 同步配置页 Widget 测试（M4 同步 UI 接线，docs/50-ui-ux.md §5.7）。
//
// 覆盖：默认 WebDAV 表单字段、切换到 S3 显示对应凭据字段、
// 保存（非敏感项 → settings 表；凭据 → secure storage 内存 Fake）。
//
// 注入：内存 DB（AppDatabase.forTesting）+ 内存 SecureKeyValueStore，
// 不依赖真实网络与平台存储（flutter_secure_storage 平台通道）。

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todo/core/db/database.dart';
import 'package:todo/core/l10n/app_localizations.dart';
import 'package:todo/core/security/secure_store.dart';
import 'package:todo/core/sync/remote_store.dart';
import 'package:todo/core/sync/remote_store_factory.dart';
import 'package:todo/core/sync/sync_config.dart';
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

/// 内存 Fake RemoteStore（供测试连接 / 立即同步测试）。
class _FakeRemoteStore implements RemoteStore {
  Uint8List? remoteBytes;

  @override
  Future<bool> exists() async => remoteBytes != null;

  @override
  Future<Uint8List?> download() async => remoteBytes;

  @override
  Future<void> upload(Uint8List bytes) async {
    remoteBytes = bytes;
  }

  @override
  Future<DateTime?> lastModified() async => DateTime.now().toUtc();

  @override
  Future<DateTime?> serverNow() async => DateTime.now().toUtc();
}

class _FakeRemoteStoreFactory implements RemoteStoreFactory {
  const _FakeRemoteStoreFactory(this.store);

  final _FakeRemoteStore store;

  @override
  RemoteStore create(SyncConfig config) => store;
}

/// 写操作抛 [SecureStoreException] 的后端（模拟安全存储故障，验证保存顺序）。
class _FailingWriteBackend implements SecureKeyValueStore {
  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async =>
      throw SecureStoreException('模拟安全存储写入故障');

  @override
  Future<void> delete(String key) async {}
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
  RemoteStoreFactory? remoteStoreFactory,
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
        if (remoteStoreFactory != null)
          remoteStoreFactoryProvider.overrideWithValue(remoteStoreFactory),
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

  testWidgets('切换类型清空另一类型字段（WebDAV 参数不残留到 S3）', (tester) async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final repo = TodoRepository(database: db);
    final secureStore = SecureStore(backend: _MemorySecureBackend());
    await _pumpSyncPage(tester, repo: repo, secureStore: secureStore);

    // Bug 2 场景：先在 WebDAV 填服务器地址，再切到 S3。
    await tester.enterText(
      find.byType(TextField).first,
      'https://dav.example.com/todo/',
    );
    await tester.tap(find.text('S3 兼容桶'));
    await tester.pumpAndSettle();

    // S3 表单出现，且 WebDAV 的服务器地址被清空（不残留）。
    expect(find.text('Endpoint'), findsOneWidget);
    expect(find.text('Bucket'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'https://dav.example.com/todo/'),
      findsNothing,
      reason: '切到 S3 后 WebDAV 服务器地址不得残留到 Endpoint 输入框',
    );
  });

  testWidgets('切换类型重载该类型已存凭据（S3 ↔ WebDAV 各自独立）', (tester) async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final repo = TodoRepository(database: db);
    final backend = _MemorySecureBackend();
    // WebDAV 已存凭据。
    await backend.write(
      'sync_webdav_serverUrl',
      'https://dav.example.com/todo/',
    );
    await backend.write('sync_webdav_username', 'dav-user');
    await backend.write('sync_webdav_secret', 'dav-pass');
    // S3 已存凭据。
    await backend.write('sync_s3_serverUrl', 'https://s3.example.com');
    await backend.write('sync_s3_accessKey', 's3-access');
    await backend.write('sync_s3_secretKey', 's3-secret');
    await backend.write('sync_s3_bucket', 'my-bucket');
    final secureStore = SecureStore(backend: backend);
    await _pumpSyncPage(tester, repo: repo, secureStore: secureStore);

    // 默认 WebDAV：预填该类型已存凭据。
    expect(
      find.widgetWithText(TextField, 'https://dav.example.com/todo/'),
      findsOneWidget,
    );

    // 切到 S3：清空 WebDAV 字段，重载 S3 已存凭据。
    await tester.tap(find.text('S3 兼容桶'));
    await tester.pumpAndSettle();
    expect(find.text('Endpoint'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'https://s3.example.com'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, 'my-bucket'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'https://dav.example.com/todo/'),
      findsNothing,
      reason: 'S3 表单不得残留 WebDAV 服务器地址',
    );

    // 切回坚果云（WebDAV）：清空 S3 字段，重载已存凭据。
    await tester.tap(find.text('坚果云'));
    await tester.pumpAndSettle();
    expect(find.text('Bucket'), findsNothing);
    expect(
      find.widgetWithText(TextField, 'https://dav.example.com/todo/'),
      findsOneWidget,
      reason: '切回坚果云（WebDAV）应重载其已存凭据',
    );
  });

  testWidgets('首次预填仅按当前类型填充（type=s3 时不预填 WebDAV 字段）', (tester) async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final repo = TodoRepository(database: db);
    // 配置类型为 S3（settings 表）；两种类型的凭据都预置。
    await repo.settings.set('sync_type', 's3');
    final backend = _MemorySecureBackend();
    await backend.write(
      'sync_webdav_serverUrl',
      'https://dav.example.com/todo/',
    );
    await backend.write('sync_s3_serverUrl', 'https://s3.example.com');
    await backend.write('sync_s3_accessKey', 's3-access');
    await backend.write('sync_s3_secretKey', 's3-secret');
    await backend.write('sync_s3_bucket', 'my-bucket');
    final secureStore = SecureStore(backend: backend);
    await _pumpSyncPage(tester, repo: repo, secureStore: secureStore);

    // 首屏即 S3：Endpoint/Bucket 预填 S3 值，WebDAV 值不出现。
    expect(find.text('Endpoint'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'https://s3.example.com'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, 'my-bucket'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'https://dav.example.com/todo/'),
      findsNothing,
      reason: 'type=s3 时不得预填 WebDAV 凭据',
    );
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

  testWidgets('凭据写入失败 → enabled 开关不落盘（无半应用状态）', (tester) async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final repo = TodoRepository(database: db);
    final failingStore = SecureStore(backend: _FailingWriteBackend());
    await _pumpSyncPage(tester, repo: repo, secureStore: failingStore);

    // 启用同步 + 填服务器地址 → 保存（凭据写失败 → 整次保存报错）。
    await tester.tap(find.text('启用同步'));
    await tester.pump();
    await tester.enterText(
      find.byType(TextField).first,
      'https://dav.example.com/todo/',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('保存失败'), findsOneWidget);

    // 非启用类 settings 已落盘（type），但 enabled 保持旧值（未被置 1）。
    final settings = await repo.settings.getAll();
    expect(settings['sync_type'], 'webdav');
    expect(
      settings['sync_enabled'],
      isNot('1'),
      reason: '凭据失败时 enabled 不得被置 1（防半应用状态）',
    );
    // 凭据未写入。
    expect(await failingStore.readCreds(RemoteType.webdav), isNull);

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

  testWidgets('测试连接：配置不完整提示「请填写完整的连接信息」', (tester) async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final repo = TodoRepository(database: db);
    final secureStore = SecureStore(backend: _MemorySecureBackend());
    await _pumpSyncPage(tester, repo: repo, secureStore: secureStore);

    // 地址为空时点击测试连接
    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();
    expect(find.text('请填写完整的连接信息'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('测试连接：配置完整提示「连接成功」', (tester) async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final repo = TodoRepository(database: db);
    final secureStore = SecureStore(backend: _MemorySecureBackend());
    final fakeStore = _FakeRemoteStore();
    await _pumpSyncPage(
      tester,
      repo: repo,
      secureStore: secureStore,
      remoteStoreFactory: _FakeRemoteStoreFactory(fakeStore),
    );

    await tester.enterText(
      find.byType(TextField).first,
      'https://dav.jianguoyun.com/dav/todo/',
    );
    await tester.tap(find.text('测试连接'));
    await tester.pumpAndSettle();
    expect(find.text('连接成功'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('立即同步：配置完整但未开同步时，点击立即同步自动启用并同步成功', (tester) async {
    final db = AppDatabase.forTesting();
    addTearDown(db.close);
    final repo = TodoRepository(database: db);
    final secureStore = SecureStore(backend: _MemorySecureBackend());
    final fakeStore = _FakeRemoteStore();
    await _pumpSyncPage(
      tester,
      repo: repo,
      secureStore: secureStore,
      remoteStoreFactory: _FakeRemoteStoreFactory(fakeStore),
    );

    await tester.enterText(
      find.byType(TextField).first,
      'https://dav.jianguoyun.com/dav/todo/',
    );
    // 直接点击「立即同步」（开关仍为关闭态，也未先点保存）
    await tester.tap(find.text('立即同步'));
    await tester.pumpAndSettle();

    // 应自动保存并同步成功，弹出「已同步」提示
    expect(find.text('已同步'), findsWidgets);
    // 开关已自动变为开启态
    final settings = await repo.settings.getAll();
    expect(settings['sync_enabled'], '1');
    expect(fakeStore.remoteBytes, isNotNull);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
