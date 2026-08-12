// SecureStore 凭据安全存储单元测试（docs/60-sync-design.md §9 / §13）。
//
// FlutterSecureStorage 的 write/read/delete 无法方法级 mock（本项目无
// mockito），故 SecureStore 接受可注入的 [SecureKeyValueStore] 后端；
// 本测试用内存 Fake 验证：key 命名、写读删、类型隔离、PlatformException
// 包装为 SecureStoreException。

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/security/secure_store.dart';
import 'package:todo/core/sync/sync_config.dart';

/// 内存 Fake 后端。
class _InMemoryBackend implements SecureKeyValueStore {
  final Map<String, String> store = {};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async {
    store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    store.remove(key);
  }
}

/// 读/写/删全部抛 PlatformException 的后端（验证异常包装）。
class _ThrowingBackend implements SecureKeyValueStore {
  @override
  Future<String?> read(String key) async =>
      throw PlatformException(code: 'boom', message: '存储损坏');

  @override
  Future<void> write(String key, String value) async =>
      throw PlatformException(code: 'boom', message: '存储损坏');

  @override
  Future<void> delete(String key) async =>
      throw PlatformException(code: 'boom', message: '存储损坏');
}

/// 构造一份带完整凭据的 webdav 配置。
SyncConfig _webdavCreds() => const SyncConfig(
  type: RemoteType.webdav,
  serverUrl: 'https://dav.example.com/todo/',
  username: 'webdav-user',
  secret: 'webdav-secret',
);

/// 构造一份带完整凭据的 s3 配置。
SyncConfig _s3Creds() => const SyncConfig(
  type: RemoteType.s3,
  serverUrl: 'https://s3.example.com',
  username: 'AKIAEXAMPLE',
  secret: 's3-secret',
  bucket: 'my-bucket',
  region: 'us-east-1',
  prefix: 'todo/',
);

void main() {
  late _InMemoryBackend backend;
  late SecureStore store;

  setUp(() {
    backend = _InMemoryBackend();
    store = SecureStore(backend: backend);
  });

  group('key 命名（每类型独立命名空间，§13）', () {
    test('webdav：sync_webdav_{serverUrl,username,secret}', () async {
      await store.writeCreds(_webdavCreds());

      expect(
        backend.store['sync_webdav_serverUrl'],
        'https://dav.example.com/todo/',
      );
      expect(backend.store['sync_webdav_username'], 'webdav-user');
      expect(backend.store['sync_webdav_secret'], 'webdav-secret');
    });

    test('s3：serverUrl/accessKey/secretKey/bucket/region/prefix', () async {
      await store.writeCreds(_s3Creds());

      expect(backend.store.keys.toSet(), {
        'sync_s3_serverUrl',
        'sync_s3_accessKey',
        'sync_s3_secretKey',
        'sync_s3_bucket',
        'sync_s3_region',
        'sync_s3_prefix',
      });
      expect(backend.store['sync_s3_accessKey'], 'AKIAEXAMPLE');
      expect(backend.store['sync_s3_secretKey'], 's3-secret');
      expect(backend.store['sync_s3_bucket'], 'my-bucket');
      expect(backend.store['sync_s3_region'], 'us-east-1');
      expect(backend.store['sync_s3_prefix'], 'todo/');
    });

    test('两种远端不会互相覆盖（key 前缀隔离）', () async {
      await store.writeCreds(_webdavCreds());
      await store.writeCreds(_s3Creds());

      expect(
        backend.store['sync_webdav_serverUrl'],
        'https://dav.example.com/todo/',
      );
      expect(backend.store['sync_s3_serverUrl'], 'https://s3.example.com');
    });
  });

  group('writeCreds / readCreds 往返', () {
    test('webdav 写读一致', () async {
      await store.writeCreds(_webdavCreds());

      final config = await store.readCreds(RemoteType.webdav);

      expect(config, isNotNull);
      expect(config!.type, RemoteType.webdav);
      expect(config.serverUrl, 'https://dav.example.com/todo/');
      expect(config.username, 'webdav-user');
      expect(config.secret, 'webdav-secret');
    });

    test('s3 写读一致（含 bucket/region/prefix）', () async {
      await store.writeCreds(_s3Creds());

      final config = await store.readCreds(RemoteType.s3);

      expect(config, isNotNull);
      expect(config!.serverUrl, 'https://s3.example.com');
      expect(config.username, 'AKIAEXAMPLE');
      expect(config.secret, 's3-secret');
      expect(config.bucket, 'my-bucket');
      expect(config.region, 'us-east-1');
      expect(config.prefix, 'todo/');
    });

    test('writeCreds 仅写非 null 字段（部分凭据不覆盖已有项）', () async {
      await store.writeCreds(_webdavCreds());
      // 只更新 serverUrl，其余字段为 null → 不写也不清。
      await store.writeCreds(
        const SyncConfig(
          type: RemoteType.webdav,
          serverUrl: 'https://dav2.example.com/',
        ),
      );

      expect(
        backend.store['sync_webdav_serverUrl'],
        'https://dav2.example.com/',
      );
      expect(backend.store['sync_webdav_username'], 'webdav-user');
      expect(backend.store['sync_webdav_secret'], 'webdav-secret');
    });
  });

  group('类型隔离与未配置', () {
    test('仅配置 webdav 时 readCreds(s3) 返回 null', () async {
      await store.writeCreds(_webdavCreds());

      expect(await store.readCreds(RemoteType.s3), isNull);
      expect(await store.readCreds(RemoteType.webdav), isNotNull);
    });

    test('无任何凭据时 readCreds 返回 null', () async {
      expect(await store.readCreds(RemoteType.webdav), isNull);
    });

    test('serverUrl 为空字符串视为未配置', () async {
      await store.writeCreds(
        const SyncConfig(type: RemoteType.webdav, serverUrl: ''),
      );

      expect(await store.readCreds(RemoteType.webdav), isNull);
    });
  });

  group('clearCreds / delete', () {
    test('clearCreds 清除该类型全部凭据，不影响另一类型', () async {
      await store.writeCreds(_webdavCreds());
      await store.writeCreds(_s3Creds());

      await store.clearCreds(RemoteType.webdav);

      expect(
        backend.store.keys.any((k) => k.startsWith('sync_webdav')),
        isFalse,
      );
      expect(backend.store['sync_s3_accessKey'], 'AKIAEXAMPLE');
    });

    test('delete 删除单个 key', () async {
      await store.writeCreds(_webdavCreds());

      await store.delete('sync_webdav_secret');

      expect(backend.store.containsKey('sync_webdav_secret'), isFalse);
      expect(
        backend.store['sync_webdav_serverUrl'],
        'https://dav.example.com/todo/',
      );
    });

    test('删除不存在的 key 静默成功', () async {
      await store.delete('sync_webdav_secret');
      // 不抛异常即通过。
    });
  });

  group('PlatformException 包装（§13）', () {
    test('readCreds 抛 PlatformException → SecureStoreException', () async {
      final throwing = SecureStore(backend: _ThrowingBackend());

      await expectLater(
        throwing.readCreds(RemoteType.webdav),
        throwsA(
          isA<SecureStoreException>().having(
            (e) => e.cause,
            'cause',
            isA<PlatformException>(),
          ),
        ),
      );
    });

    test('writeCreds 抛 PlatformException → SecureStoreException', () async {
      final throwing = SecureStore(backend: _ThrowingBackend());

      await expectLater(
        throwing.writeCreds(_webdavCreds()),
        throwsA(isA<SecureStoreException>()),
      );
    });
  });
}
