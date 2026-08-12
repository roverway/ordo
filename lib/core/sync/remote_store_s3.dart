// S3 RemoteStore 实现（docs/60-sync-design.md §9.2 / §12 / §13）。
//
// 依赖：minio 3.5.8（纯 Dart，无原生配置）。
//
// 调用约定（已实测确认，勿改动）：
// - 实例化：Minio(endPoint:, accessKey:, secretKey:, region:)；
//   endPoint 必须是**裸域名/IP**（禁止 https:// 前缀或路径），useSSL 默认
//   true，pathStyle 默认 true（MinIO/R2 正确，AWS 自动切换虚拟主机风格）；
// - exists/lastModified：statObject(bucket, object, retrieveAcls: false)；
//   **务必传 retrieveAcls: false**（否则连带 GET ?acl，MinIO/R2 返回非标准
//   XML 会抛 XmlParserException）。返回 StatObjectResult{ size, etag,
//   lastModified(UTC), ... }；
// - download：getObject(bucket, object) → MinioByteStream（StreamView），
//   fold 收集字节 → Uint8List；
// - upload：putObject(bucket, object, Stream<Uint8List>.value(bytes),
//   size: bytes.length)（≥5MB 自动分块；返回 ETag 可忽略）；
// - 对象键：`{prefix}{key}`，prefix 默认 `todo/`，key 默认 data.json.gz。
//
// 错误分类（§12）：
// - MinioS3Error 的 error.code == 'NoSuchKey'/'NotFound' 或 statusCode == 404
//   → 对象不存在（exists=false / download=null / lastModified=null）；
// - MinioS3Error 且 code/status 属认证（AccessDenied/InvalidAccessKeyId/
//   SignatureDoesNotMatch/AuthenticationRequired、401/403）→ SyncAuthException；
// - MinioS3Error 其余 → SyncRemoteException；
// - MinioError 非 S3 子类（连接失败/DNS 的包装层）以及 http 栈直接抛出的
//   ClientException/SocketException → SyncNetworkException（退避重试）。
//
// 可测试性：对 Minio 包一层薄适配器 [S3Ops]，测试注入 Fake 实现
// （模拟 404/403/网络错误），无需真实网络与 mockito。

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

// minio 依赖 http（传递依赖），其底层在网络失败时抛 http.ClientException
//（连接失败/DNS/连接中断），本文件必须引用该类型做 §12 分类；按仓库依赖
// 锁定约束不新增 pub 依赖，故在此对 depend_on_referenced_packages 做定点
// 豁免（同 remote_store_webdav.dart 对 dio 的处理）。
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:minio/minio.dart';
import 'package:minio/models.dart';

import 'remote_store.dart';
import 'sync_exceptions.dart';

/// S3 底层操作薄抽象（可注入测试）。
///
/// 与 [S3RemoteStore] 的分工：本接口直接透传 S3 语义（statObject/getObject/
/// putObject，签名与 minio 3.5.8 对齐），异常按原样上抛（真实实现抛
/// MinioS3Error / MinioError）；404/认证/网络/远端错误的**分类**由
/// [S3RemoteStore] 统一负责。
abstract class S3Ops {
  /// HEAD：读取对象元信息（size/etag/lastModified）。
  ///
  /// [retrieveAcls] 必须为 false（MinIO/R2 的 ?acl 响应非标准 XML，
  /// 传 true 会抛 XmlParserException）；默认值即 false。
  Future<StatObjectResult> statObject(
    String bucket,
    String object, {
    bool retrieveAcls = false,
  });

  /// GET：返回对象内容字节流（对象不存在时抛 MinioS3Error）。
  Future<MinioByteStream> getObject(String bucket, String object);

  /// PUT：上传（原子覆盖；≥5MB 自动分块，返回 ETag 可忽略）。
  Future<String> putObject(
    String bucket,
    String object,
    Stream<Uint8List> data, {
    int? size,
  });
}

/// 生产适配器：封装 [Minio]。
class S3OpsMinioAdapter implements S3Ops {
  S3OpsMinioAdapter(this._minio);

  final Minio _minio;

  @override
  Future<StatObjectResult> statObject(
    String bucket,
    String object, {
    bool retrieveAcls = false,
  }) {
    return _minio.statObject(bucket, object, retrieveAcls: retrieveAcls);
  }

  @override
  Future<MinioByteStream> getObject(String bucket, String object) {
    return _minio.getObject(bucket, object);
  }

  @override
  Future<String> putObject(
    String bucket,
    String object,
    Stream<Uint8List> data, {
    int? size,
  }) {
    return _minio.putObject(bucket, object, data, size: size);
  }
}

/// S3 兼容桶远端存储（§9.2）。
class S3RemoteStore implements RemoteStore {
  S3RemoteStore({
    required String endpoint,
    required String accessKey,
    required String secretKey,
    required String bucket,
    String? region,
    String prefix = 'todo/',
    String key = kRemoteSnapshotKey,
    S3Ops? ops,
  }) : _ops =
           ops ??
           S3OpsMinioAdapter(
             _createMinio(endpoint, accessKey, secretKey, region),
           ),
       _bucket = bucket,
       _objectKey = _buildObjectKey(prefix, key) {
    if (endpoint.trim().isEmpty) {
      throw const SyncConfigException('S3 配置缺少 endpoint');
    }
    if (bucket.trim().isEmpty) {
      throw const SyncConfigException('S3 配置缺少 bucket');
    }
  }

  /// 实例化真实 Minio 客户端（供生产构造路径）。
  ///
  /// endPoint 必须是裸域名/IP；空值 → SyncConfigException（§9.3 配置无效）。
  static Minio _createMinio(
    String endpoint,
    String accessKey,
    String secretKey,
    String? region,
  ) {
    if (endpoint.trim().isEmpty) {
      throw const SyncConfigException('S3 配置缺少 endpoint');
    }
    return Minio(
      endPoint: endpoint.trim(),
      accessKey: accessKey,
      secretKey: secretKey,
      region: region,
      // useSSL/pathStyle 走 minio 默认值：useSSL=true、pathStyle=true
      //（MinIO/R2 正确；AWS 端点自动切换虚拟主机风格）。
    );
  }

  /// 拼接对象键：`{prefix}{key}`（prefix 缺尾 `/` 时补上，与 WebDAV
  /// baseUrl 归一风格一致；prefix 为空则对象键直接是 key，即桶根）。
  static String _buildObjectKey(String prefix, String key) {
    if (prefix.isEmpty) return key;
    final normalized = prefix.endsWith('/') ? prefix : '$prefix/';
    return '$normalized$key';
  }

  final S3Ops _ops;

  /// bucket 名。
  final String _bucket;

  /// 完整对象键（`{prefix}data.json.gz`）。
  final String _objectKey;

  @override
  Future<bool> exists() async {
    try {
      await _ops.statObject(_bucket, _objectKey, retrieveAcls: false);
      return true;
    } on MinioS3Error catch (e) {
      if (_isNotFound(e)) return false;
      throw _classify(e);
    } on MinioError catch (e) {
      throw _classifyNetwork(e);
    } on SocketException catch (e) {
      // minio 底层 http 栈直接抛出的网络错误（未包装进 MinioError）。
      throw _classifyNetwork(e);
    } on http.ClientException catch (e) {
      throw _classifyNetwork(e);
    }
  }

  @override
  Future<Uint8List?> download() async {
    try {
      final stream = await _ops.getObject(_bucket, _objectKey);
      final bytes = await stream.fold<List<int>>(
        <int>[],
        (acc, chunk) => acc..addAll(chunk),
      );
      return Uint8List.fromList(bytes);
    } on MinioS3Error catch (e) {
      if (_isNotFound(e)) return null;
      throw _classify(e);
    } on MinioError catch (e) {
      throw _classifyNetwork(e);
    } on SocketException catch (e) {
      // minio 底层 http 栈直接抛出的网络错误（未包装进 MinioError）。
      throw _classifyNetwork(e);
    } on http.ClientException catch (e) {
      throw _classifyNetwork(e);
    }
  }

  @override
  Future<void> upload(Uint8List bytes) async {
    try {
      await _ops.putObject(
        _bucket,
        _objectKey,
        Stream<Uint8List>.value(bytes),
        size: bytes.length,
      );
    } on MinioS3Error catch (e) {
      // 上传路径出现 404 属于远端异常（bucket 不可达等），不是「对象不存在」。
      throw _classify(e);
    } on MinioError catch (e) {
      throw _classifyNetwork(e);
    } on SocketException catch (e) {
      // minio 底层 http 栈直接抛出的网络错误（未包装进 MinioError）。
      throw _classifyNetwork(e);
    } on http.ClientException catch (e) {
      throw _classifyNetwork(e);
    }
  }

  @override
  Future<DateTime?> lastModified() async {
    try {
      final result = await _ops.statObject(
        _bucket,
        _objectKey,
        retrieveAcls: false,
      );
      final lastModified = result.lastModified;
      if (lastModified == null) return null;
      // minio 返回的 lastModified 已是 UTC；toUtc() 归一保证接口契约
      //（§3 时间一律 UTC 毫秒，与 WebDAV 实现一致）。
      return lastModified.toUtc();
    } on MinioS3Error catch (e) {
      if (_isNotFound(e)) return null;
      throw _classify(e);
    } on MinioError catch (e) {
      throw _classifyNetwork(e);
    } on SocketException catch (e) {
      // minio 底层 http 栈直接抛出的网络错误（未包装进 MinioError）。
      throw _classifyNetwork(e);
    } on http.ClientException catch (e) {
      throw _classifyNetwork(e);
    }
  }

  /// 是否为「对象不存在」（NoSuchKey/NotFound/HTTP 404）。
  bool _isNotFound(MinioS3Error e) {
    final code = e.error?.code;
    if (code == 'NoSuchKey' || code == 'NotFound') return true;
    return e.response?.statusCode == 404;
  }

  /// §12 错误分类：MinioS3Error（远端 HTTP 层错误）→ 领域异常。
  ///
  /// 认证类（code 或 401/403）→ SyncAuthException；其余 → SyncRemoteException。
  Exception _classify(MinioS3Error e) {
    final code = e.error?.code;
    if (code == 'AccessDenied' ||
        code == 'InvalidAccessKeyId' ||
        code == 'SignatureDoesNotMatch' ||
        code == 'AuthenticationRequired') {
      return SyncAuthException('认证失败，请检查 AccessKey 与 SecretKey', cause: e);
    }
    final status = e.response?.statusCode;
    if (status == 401 || status == 403) {
      return SyncAuthException('认证失败，请检查 AccessKey 与 SecretKey', cause: e);
    }
    return SyncRemoteException(
      status == null ? '远端 S3 错误（${code ?? '未知'}）' : '远端返回 HTTP $status',
      cause: e,
    );
  }

  /// §12 错误分类：网络层异常（MinioError 包装，或 http 栈直接抛出的
  /// ClientException/SocketException）→ SyncNetworkException（退避重试）。
  ///
  /// 注意参数类型不能用 `Object`：本文件 import 的 `package:minio/models.dart`
  /// 导出了 S3 实体类 `Object`，会遮蔽 dart:core 的 `Object`；三者共同父类
  /// `Exception` 未被遮蔽，故用之。
  Exception _classifyNetwork(Exception e) {
    return SyncNetworkException('网络连接失败或超时', cause: e);
  }
}
