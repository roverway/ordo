// RemoteStore 工厂（docs/60-sync-design.md §9.3）。
//
// 按 SyncConfig.type 返回对应远端实现；配置无效抛 SyncConfigException。
// - webdav → WebDavRemoteStore（remote_store_webdav.dart）；
// - s3 → S3RemoteStore（remote_store_s3.dart）。

import 'remote_store.dart';
import 'remote_store_s3.dart';
import 'remote_store_webdav.dart';
import 'sync_config.dart';
import 'sync_exceptions.dart';

/// 远端存储工厂（§9.3）。
class RemoteStoreFactory {
  /// 默认实例（无状态，同步引擎/配置页注入用）。
  ///
  /// 工厂本可做成纯静态，但 SyncEngine 需要可注入的工厂实例以便测试替换
  /// （D3 构造签名 `required RemoteStoreFactory remoteStoreFactory`），故暴露
  /// 公开 const 构造与实例方法 [create]；[fromConfig] 静态方法保留供既有
  /// 调用方与测试使用（行为一致，create 仅转发）。
  const RemoteStoreFactory();

  /// 按 [config] 构造远端实现（实例方法，等价于静态 [fromConfig]）。
  ///
  /// 测试通过 `implements RemoteStoreFactory` 覆盖本方法返回 FakeRemoteStore。
  RemoteStore create(SyncConfig config) => fromConfig(config);

  /// 按 [config] 构造远端实现。
  ///
  /// - webdav：要求 serverUrl 非空（凭据缺失允许匿名/公开只读场景，
  ///   由调用方决定是否校验 username/secret）；否则抛 [SyncConfigException]；
  /// - s3：要求 serverUrl（endpoint）与 bucket 非空，否则抛
  ///   [SyncConfigException]；region 可为 null（由客户端探测），
  ///   prefix 默认 `todo/`（§9.2）。
  static RemoteStore fromConfig(SyncConfig config) {
    switch (config.type) {
      case RemoteType.webdav:
        final serverUrl = config.serverUrl;
        if (serverUrl == null || serverUrl.trim().isEmpty) {
          throw const SyncConfigException('WebDAV 配置缺少服务器地址');
        }
        return WebDavRemoteStore(
          baseUrl: serverUrl,
          username: config.username ?? '',
          password: config.secret ?? '',
        );
      case RemoteType.s3:
        final serverUrl = config.serverUrl;
        if (serverUrl == null || serverUrl.trim().isEmpty) {
          throw const SyncConfigException('S3 配置缺少 endpoint');
        }
        return S3RemoteStore(
          endpoint: serverUrl,
          accessKey: config.username ?? '',
          secretKey: config.secret ?? '',
          bucket: config.bucket ?? '',
          region: config.region,
          prefix: config.prefix ?? 'todo/',
        );
    }
  }
}
