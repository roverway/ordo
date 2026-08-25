// 同步凭据安全存储（docs/60-sync-design.md §9 / §13，FR-SYNC-05）。
//
// 凭据（serverUrl/username/secret/bucket/region/prefix）只存
// flutter_secure_storage（Android Keystore / Windows DPAPI / Linux libsecret），
// 禁止明文存 shared_preferences / settings 表（AGENTS.md §3-6，§13）。
//
// 设计：
// - key 命名 `sync_<type>_<field>`，每远端类型独立命名空间，互不覆盖
//   （webdav 的 serverUrl 不会与 s3 的 endpoint 互相覆盖）；
// - 可注入 key-value 后端（[SecureKeyValueStore]）：生产用
//   [FlutterSecureStorage]，测试注入内存 Fake（本项目无 mockito）；
// - 底层抛 [PlatformException] 时包装为领域异常 [SecureStoreException]。

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../sync/sync_config.dart';

/// 凭据安全存储领域异常：包装底层 [PlatformException]。
///
/// 消息不包含密钥/完整 URL（§13），供 sync_engine / 配置页映射文案。
class SecureStoreException implements Exception {
  const SecureStoreException(this.message, {this.cause});

  final String message;

  /// 底层 [PlatformException]（仅用于日志调试）。
  final Object? cause;

  @override
  String toString() => 'SecureStoreException: $message';
}

/// 可注入的 key-value 安全后端抽象。
///
/// 生产实现见 [FlutterSecureKeyValueStore]；测试用内存 Fake
/// （`FlutterSecureStorage` 的 write/read/delete 是方法级调用，不便于
/// 直接 mock，故通过本接口注入）。
abstract class SecureKeyValueStore {
  /// 读取；key 不存在返回 null。
  Future<String?> read(String key);

  /// 写入（覆盖）。
  Future<void> write(String key, String value);

  /// 删除；key 不存在时静默成功。
  Future<void> delete(String key);
}

/// 生产后端：flutter_secure_storage（const 单例，平台级加密存储）。
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// 同步凭据存取（§9 / §13）。
///
/// 与 [SyncConfig] 的分工：settings 表字段由 SettingsDao 读写（非敏感），
/// 本类只负责凭据字段。读写粒度按「远端类型」整体进行：
/// - [writeCreds]：按类型写全部非 null 凭据字段（null 字段跳过，不清除）；
/// - [readCreds]：按类型读全部凭据字段，serverUrl 未配置时返回 null；
/// - [clearCreds]：清除某类型全部凭据。
class SecureStore {
  SecureStore({SecureKeyValueStore? backend})
    : _backend = backend ?? const FlutterSecureKeyValueStore();

  /// 凭据 key 前缀。
  static const String keyPrefix = 'sync_';

  final SecureKeyValueStore _backend;

  /// 字段 key 映射：按 [RemoteType] 输出 (SyncConfig 字段名 → 存储 key)。
  ///
  /// s3 侧复用 SyncConfig 的 username/secret 语义，但 key 命名为
  /// accessKey/secretKey（与 s3_dart 配置命名一致，§9.2）。
  static Map<String, String> _keysFor(RemoteType type) {
    switch (type) {
      case RemoteType.webdav:
        return {
          'serverUrl': '${keyPrefix}webdav_serverUrl',
          'username': '${keyPrefix}webdav_username',
          'secret': '${keyPrefix}webdav_secret',
        };
      case RemoteType.s3:
        return {
          'serverUrl': '${keyPrefix}s3_serverUrl',
          'username': '${keyPrefix}s3_accessKey',
          'secret': '${keyPrefix}s3_secretKey',
          'bucket': '${keyPrefix}s3_bucket',
          'region': '${keyPrefix}s3_region',
          'prefix': '${keyPrefix}s3_prefix',
        };
    }
  }

  /// 写入某类型的凭据（仅写非 null 字段；null 字段保持原样）。
  Future<void> writeCreds(SyncConfig config) async {
    final keys = _keysFor(config.type);
    final values = <String, String?>{
      'serverUrl': config.serverUrl,
      'username': config.username,
      'secret': config.secret,
      'bucket': config.bucket,
      'region': config.region,
      'prefix': config.prefix,
    };
    for (final entry in keys.entries) {
      final value = values[entry.key];
      if (value == null) continue;
      await _guard(() => _backend.write(entry.value, value));
    }
  }

  /// 读取某类型的凭据；serverUrl 未配置（即该类型无凭据）时返回 null。
  Future<SyncConfig?> readCreds(RemoteType type) async {
    final keys = _keysFor(type);
    final serverUrl = await _guard(() => _backend.read(keys['serverUrl']!));
    if (serverUrl == null || serverUrl.isEmpty) return null;
    final username = await _guard(() => _backend.read(keys['username']!));
    final secret = await _guard(() => _backend.read(keys['secret']!));
    final bucket = type == RemoteType.s3
        ? await _guard(() => _backend.read(keys['bucket']!))
        : null;
    final region = type == RemoteType.s3
        ? await _guard(() => _backend.read(keys['region']!))
        : null;
    final prefix = type == RemoteType.s3
        ? await _guard(() => _backend.read(keys['prefix']!))
        : null;
    return SyncConfig(
      type: type,
      serverUrl: serverUrl,
      username: username,
      secret: secret,
      bucket: bucket,
      region: region,
      prefix: prefix,
    );
  }

  /// 清除某类型的全部凭据。
  Future<void> clearCreds(RemoteType type) async {
    for (final key in _keysFor(type).values) {
      await _guard(() => _backend.delete(key));
    }
  }

  /// 删除单个凭据 key（供设置页「断开同步」等场景逐项清理）。
  Future<void> delete(String key) async {
    await _guard(() => _backend.delete(key));
  }

  /// 包装底层 [PlatformException] 及其他异常为 [SecureStoreException]。
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PlatformException catch (e) {
      throw SecureStoreException(e.message ?? '安全存储操作失败', cause: e);
    } catch (e) {
      throw SecureStoreException('安全存储异常: $e', cause: e);
    }
  }
}
