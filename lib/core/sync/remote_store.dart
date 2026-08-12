// RemoteStore 抽象接口（docs/60-sync-design.md §9）。
//
// 双远端实现（WebDAV / S3）统一本接口，sync_engine 只依赖本抽象，
// 不依赖具体远端（docs/30-architecture.md §1：同步引擎只依赖
// Repository 与 RemoteStore 抽象）。
//
// 契约（所有实现必须遵守）：
// - 对象不存在：exists()=false、download()/lastModified()=null
//   （WebDAV 下即 404，S3 下即 NoSuchKey）；
// - 时间：lastModified() 返回**已按 UTC 归一**的 DateTime
//   （§3 时间一律 UTC 毫秒；WebDAV 的 mTime 是本地时区，必须 toUtc）；
// - 上传：原子覆盖（整文件 PUT/putObject）；
// - 错误：按 §12 分类抛领域异常（SyncNetworkException / SyncAuthException /
//   SyncRemoteException，定义于 sync_exceptions.dart）；
// - 日志/异常消息不得包含密钥或完整 URL（§13）。

import 'dart:typed_data';

/// 远端快照对象默认 key（§3 / §9.1）：WebDAV 路径 `{baseUrl}{key}`，
/// S3 对象键 `{prefix}data.json.gz`（§9.2，key 与 prefix 语义等价）。
const String kRemoteSnapshotKey = 'data.json.gz';

/// 远端存储抽象（§9）。
abstract class RemoteStore {
  /// 远端对象是否存在（不存在 = 首次同步「本地有+远端空」分支）。
  Future<bool> exists();

  /// 下载原始字节（gzip 压缩的完整快照）；对象不存在返回 null。
  Future<Uint8List?> download();

  /// 上传（原子覆盖整个对象）。
  Future<void> upload(Uint8List bytes);

  /// 远端对象最后修改时间（UTC）；对象不存在返回 null。
  Future<DateTime?> lastModified();

  /// 本进程内「最近一次成功上传内容」的 hash（§10.3 无变化跳过优化）。
  ///
  /// - 未上传过返回 null（进程重启后也为 null，sync_engine 会退化为
  ///   用 lastModified 判定或直接上传）；
  /// - hash 仅用于「远端是否与我上次上传一致」的变化判定，
  ///   非密码学用途，不保证防碰撞安全。
  ///
  /// 实现约定：upload() 成功后内部记录本次字节的 hash，contentHash()
  /// 原样返回；不做任何网络请求。
  Future<String?> contentHash();
}
