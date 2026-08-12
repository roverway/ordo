// WebDAV RemoteStore 实现（docs/60-sync-design.md §9.1 / §12 / §13）。
//
// 调用约定（已实测确认，勿改动）：
// - 实例化：newClient(baseUrl, user:, password:)（baseUrl 末尾自动补 '/'），
//   随后 setConnectTimeout(8000) / setReceiveTimeout(30000) / setSendTimeout(30000)；
// - exists/lastModified：readProps(path)（PROPFIND）；
// - download：read(path)（GET）→ List<int> → Uint8List；
// - upload：write(path, Uint8List)（PUT，父目录自动递归创建）；
// - path 传**相对 key**（如 `data.json.gz`，见 remote_store.dart），不拼 baseUrl：
//   webdav_client 内部 `join(baseUrl, key)` = `rtrim(baseUrl,'/') + '/' + key`
//   拼回完整 URL（webdav_dio.dart:83）。key 无 `/` 时 write 前的 mkdirAll
//   自动跳过（父目录即 baseUrl 目录，用户配置的同步文件夹必然存在）；
//   若传完整 URL，mkdirAll 在父目录缺失走 409 分支时会 `path.split('/')`
//   把 `https://` 拆成 `https:/` 再 MKCOL → 坚果云 400（勿改回完整 URL）。
//
// 错误分类（§12）：
// - 404 与 409 → 对象不存在（exists=false / download=null / lastModified=null）；
//   部分 WebDAV 服务器（含坚果云 dav.jianguoyun.com）在**父目录不存在**时对
//   PROPFIND/GET 返回 409（父目录存在而文件缺失才返回 404）；
// - DioException 的 connectionError / connectionTimeout / sendTimeout /
//   receiveTimeout → SyncNetworkException（退避重试）；
// - 401 → SyncAuthException（不重试）；
// - 其余 HTTP → SyncRemoteException。
//
// 可测试性：对 webdav_client.Client 包一层薄适配器 [WebDavClientLike]，
// 测试注入 Fake 实现（模拟 404/401/超时/本地时区 mTime），无需 mockito。

import 'dart:typed_data';

// webdav_client 依赖 dio 5.x，其抛出的异常类型为 DioException（io.dart 需
// 判断 404/401/网络类型）。dio 是传递依赖，但异常类型是 webdav_client 的
// 固定公共接口，本文件必须引用它；按仓库依赖锁定约束不新增 pub 依赖，
// 故在此对 depend_on_referenced_packages 做定点豁免。
// ignore: depend_on_referenced_packages
import 'package:dio/dio.dart';
import 'package:webdav_client/webdav_client.dart';

import 'remote_store.dart';
import 'sync_exceptions.dart';

/// 连接超时（毫秒）。
const int _kConnectTimeoutMs = 8000;

/// 发送/接收超时（毫秒）。
const int _kTransferTimeoutMs = 30000;

/// WebDAV 底层客户端薄抽象（可注入测试）。
///
/// 与 [WebDavRemoteStore] 的分工：本接口直接透传 webdav 语义
/// （PROPFIND/GET/PUT），异常按原样上抛（真实实现抛 DioException）；
/// 404/网络/认证的**分类**由 [WebDavRemoteStore] 统一负责。
abstract class WebDavClientLike {
  /// PROPFIND：读取单文件属性（mTime 等）。
  /// 对象不存在时底层抛 DioException(404)。
  Future<File> readProps(String path);

  /// GET：读取原始字节。
  Future<List<int>> read(String path);

  /// PUT：写入（原子覆盖，父目录自动递归创建）。
  Future<void> write(String path, Uint8List data);
}

/// 生产适配器：封装 webdav_client.Client（newClient + 超时配置）。
class WebDavClientAdapter implements WebDavClientLike {
  WebDavClientAdapter._(this._client);

  /// 按 §9.1 创建真实客户端（baseUrl 末尾自动补 '/', 并配置超时）。
  factory WebDavClientAdapter.create({
    required String baseUrl,
    String username = '',
    String password = '',
  }) {
    final client = newClient(baseUrl, user: username, password: password);
    client.setConnectTimeout(_kConnectTimeoutMs);
    client.setReceiveTimeout(_kTransferTimeoutMs);
    client.setSendTimeout(_kTransferTimeoutMs);
    return WebDavClientAdapter._(client);
  }

  final Client _client;

  @override
  Future<File> readProps(String path) => _client.readProps(path);

  @override
  Future<List<int>> read(String path) => _client.read(path);

  @override
  Future<void> write(String path, Uint8List data) => _client.write(path, data);
}

/// WebDAV 远端存储（§9.1）。
class WebDavRemoteStore implements RemoteStore {
  WebDavRemoteStore({
    required String baseUrl,
    String username = '',
    String password = '',
    String key = kRemoteSnapshotKey,
    WebDavClientLike? client,
  }) : _client = client ?? _createClient(baseUrl, username, password),
       _path = key;

  /// 实例化真实客户端（供生产构造路径）。
  static WebDavClientLike _createClient(
    String baseUrl,
    String username,
    String password,
  ) {
    return WebDavClientAdapter.create(
      baseUrl: baseUrl,
      username: username,
      password: password,
    );
  }

  final WebDavClientLike _client;

  /// 传给 readProps/read/write 的相对路径（仅 key，如 `data.json.gz`）。
  final String _path;

  @override
  Future<bool> exists() async {
    try {
      await _client.readProps(_path);
      return true;
    } on DioException catch (e) {
      if (_isNotFound(e)) return false;
      throw _classify(e);
    }
  }

  @override
  Future<Uint8List?> download() async {
    try {
      final bytes = await _client.read(_path);
      return Uint8List.fromList(bytes);
    } on DioException catch (e) {
      if (_isNotFound(e)) return null;
      throw _classify(e);
    }
  }

  @override
  Future<void> upload(Uint8List bytes) async {
    try {
      await _client.write(_path, bytes);
    } on DioException catch (e) {
      // 上传路径出现 404/409 均属远端异常（父目录/根路径不可达是配置问题），
      // 不是「对象不存在」；upload 不经过 _isNotFound，保持 §12 分类语义。
      throw _classify(e);
    }
  }

  @override
  Future<DateTime?> lastModified() async {
    try {
      final file = await _client.readProps(_path);
      final mTime = file.mTime;
      if (mTime == null) return null;
      // 坑：webdav_client 的 File.mTime 是**本地时区**（内部 .toLocal()），
      // 必须 toUtc 归一（§3 时间一律 UTC 毫秒）。DateTime.toUtc 保持同一
      // 时间点、仅切换时区表示，下游 .millisecondsSinceEpoch 与格式化不受影响。
      return mTime.toUtc();
    } on DioException catch (e) {
      if (_isNotFound(e)) return null;
      throw _classify(e);
    }
  }

  /// 是否为「对象不存在」。
  ///
  /// 404 = 对象不存在（标准语义）；**409 也视为不存在**：部分 WebDAV
  /// 服务器（含坚果云 dav.jianguoyun.com）在**父目录不存在**时对 PROPFIND/GET
  /// 返回 409（父目录存在而文件缺失才返回 404），此时对象同样读不到。
  /// 仅用于 read 系操作（exists/download/lastModified）；upload 路径的
  /// 404/409 仍走 [_classify] 归为远端异常（见 upload 注释），勿误用本方法。
  bool _isNotFound(DioException e) {
    final status = e.response?.statusCode;
    return status == 404 || status == 409;
  }

  /// §12 错误分类：DioException → 领域异常（调用方 `throw` 之）。
  ///
  /// 网络失败/超时 → SyncNetworkException；401 → SyncAuthException；
  /// 其余 HTTP → SyncRemoteException。
  Exception _classify(DioException e) {
    final type = e.type;
    if (type == DioExceptionType.connectionError ||
        type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.receiveTimeout) {
      return SyncNetworkException('网络连接失败或超时', cause: e);
    }
    final status = e.response?.statusCode;
    if (status == 401) {
      return SyncAuthException('认证失败，请检查账号与密码', cause: e);
    }
    return SyncRemoteException('远端返回 HTTP $status', cause: e);
  }
}
