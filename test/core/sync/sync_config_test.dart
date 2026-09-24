// SyncConfig 模型单元测试（docs/60-sync-design.md §10.1 / §13）。
//
// 覆盖：toMap/fromMap 往返、settings 表仅存非敏感 6 项（凭据字段绝不
// 进入 settings JSON）、缺省值容错、copyWith、类型解析。

import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/sync/sync_config.dart';

void main() {
  group('SyncConfig.toMap（settings 表序列化）', () {
    test('输出非敏感 6 项，值格式正确', () {
      const config = SyncConfig(
        type: RemoteType.webdav,
        enabled: true,
        autoOnStart: true,
        autoOnEdit: false,
        wifiOnly: true,
        lastSyncedAt: 1720000000000,
        // 凭据字段（不应出现）。
        serverUrl: 'https://dav.example.com/todo/',
        username: 'user',
        secret: 'secret-password',
      );

      final map = config.toMap();

      expect(map, {
        'sync_type': 'webdav',
        'sync_enabled': '1',
        'sync_auto_on_start': '1',
        'sync_auto_on_edit': '0',
        'sync_wifi_only': '1',
        'sync_last_synced_at': '1720000000000',
      });
    });

    test('§13 安全约束：凭据字段绝不进入 settings JSON', () {
      const config = SyncConfig(
        type: RemoteType.s3,
        enabled: true,
        lastSyncedAt: 1720000000000,
        serverUrl: 'https://s3.example.com',
        username: 'AKIAxxxx',
        secret: 's3-secret-key',
        bucket: 'my-bucket',
        region: 'us-east-1',
        prefix: 'todo/',
      );

      final map = config.toMap();

      expect(map.containsKey('serverUrl'), isFalse);
      expect(map.containsKey('username'), isFalse);
      expect(map.containsKey('secret'), isFalse);
      expect(map.containsKey('bucket'), isFalse);
      expect(map.containsKey('region'), isFalse);
      expect(map.containsKey('prefix'), isFalse);
      // 全部 6 项均为非敏感 settings 项。
      expect(map.keys.toSet(), {
        'sync_type',
        'sync_enabled',
        'sync_auto_on_start',
        'sync_auto_on_edit',
        'sync_wifi_only',
        'sync_last_synced_at',
      });
    });

    test('lastSyncedAt 为 null 时省略该 key', () {
      const config = SyncConfig(lastSyncedAt: null);
      expect(config.toMap().containsKey('sync_last_synced_at'), isFalse);
    });
  });

  group('SyncConfig.fromMap（settings 表解析）', () {
    test('toMap → fromMap 往返一致', () {
      const config = SyncConfig(
        type: RemoteType.s3,
        enabled: true,
        autoOnStart: false,
        autoOnEdit: true,
        wifiOnly: false,
        lastSyncedAt: 1720000000000,
      );

      final parsed = SyncConfig.fromMap(config.toMap());

      expect(parsed.type, RemoteType.s3);
      expect(parsed.enabled, isTrue);
      expect(parsed.autoOnStart, isFalse);
      expect(parsed.autoOnEdit, isTrue);
      expect(parsed.wifiOnly, isFalse);
      expect(parsed.lastSyncedAt, 1720000000000);
      // 凭据字段来自 secure storage，解析后保持 null。
      expect(parsed.serverUrl, isNull);
      expect(parsed.username, isNull);
      expect(parsed.secret, isNull);
    });

    test('空/缺省 map 回退默认值（webdav、全关、lastSyncedAt=null）', () {
      final parsed = SyncConfig.fromMap(const {});

      expect(parsed.type, RemoteType.webdav);
      expect(parsed.enabled, isFalse);
      expect(parsed.autoOnStart, isFalse);
      expect(parsed.autoOnEdit, isFalse);
      expect(parsed.wifiOnly, isFalse);
      expect(parsed.lastSyncedAt, isNull);
    });

    test('非法 type 回退 webdav', () {
      final parsed = SyncConfig.fromMap({'sync_type': 'ftp'});
      expect(parsed.type, RemoteType.webdav);
    });

    test('布尔容错：接受 "true"/"false"、整数、bool', () {
      final parsed = SyncConfig.fromMap({
        'sync_enabled': 'true',
        'sync_auto_on_start': 1,
        'sync_auto_on_edit': false,
        'sync_wifi_only': 'no',
      });

      expect(parsed.enabled, isTrue);
      expect(parsed.autoOnStart, isTrue);
      expect(parsed.autoOnEdit, isFalse);
      expect(parsed.wifiOnly, isFalse);
    });

    test('lastSyncedAt 非法字符串回退 null', () {
      final parsed = SyncConfig.fromMap({'sync_last_synced_at': 'abc'});
      expect(parsed.lastSyncedAt, isNull);
    });
  });

  group('SyncConfig.copyWith', () {
    test('仅修改指定字段，其余保持不变', () {
      const config = SyncConfig(
        type: RemoteType.webdav,
        enabled: true,
        autoOnStart: true,
        lastSyncedAt: 100,
        serverUrl: 'https://dav.example.com/todo/',
      );

      final updated = config.copyWith(enabled: false, serverUrl: 'https://x/');

      expect(updated.type, RemoteType.webdav);
      expect(updated.enabled, isFalse);
      expect(updated.autoOnStart, isTrue);
      expect(updated.lastSyncedAt, 100);
      expect(updated.serverUrl, 'https://x/');
      // 原对象不可变。
      expect(config.enabled, isTrue);
      expect(config.serverUrl, 'https://dav.example.com/todo/');
    });
  });

  group('SyncConfig.hasCredentials', () {
    test('serverUrl 非空即有凭据；为空/缺失则无', () {
      expect(
        const SyncConfig(serverUrl: 'https://dav.example.com/').hasCredentials,
        isTrue,
      );
      expect(const SyncConfig(serverUrl: '  ').hasCredentials, isFalse);
      expect(const SyncConfig().hasCredentials, isFalse);
    });
  });
}
