// S3RemoteStore 单元测试（docs/60-sync-design.md §9.2 / §12 / §13）。
//
// 不实例化真实 Minio 做网络请求：对 Minio 包一层薄适配器 [S3Ops]
// （remote_store_s3.dart），本测试注入 Fake 适配器，覆盖：
// - 存在/不存在（NoSuchKey/NotFound）分支：exists / download / lastModified；
// - statObject 必须传 retrieveAcls: false（MinIO/R2 ?acl 非标准 XML 坑）；
// - lastModified UTC 归一、lastModified 为 null 分支；
// - getObject 字节流 → Uint8List、putObject 传入正确 bucket/对象键/字节/size；
// - §12 错误分类：AccessDenied → SyncAuthException、MinioError → SyncNetworkException、
//   其他 code → SyncRemoteException（上传路径 404 也属远端异常）；
// - 前缀拼接：'todo/' + key、缺尾 '/' 归一、空 prefix（桶根）；
// - 工厂：s3 有效/缺 serverUrl/缺 bucket。
//
// 注：上传内容 hash（§10.3 无变化跳过）已不在本层实现——判定改为
// SyncEngine 比较「合并/导出结果 vs 下载到的远端快照」的业务内容 hash，
// RemoteStore.contentHash 已移除（见 sync_engine.dart 上传优化注释）。

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:minio/minio.dart';
import 'package:minio/models.dart';
import 'package:ordo/core/sync/remote_store_factory.dart';
import 'package:ordo/core/sync/remote_store_s3.dart';
import 'package:ordo/core/sync/sync_config.dart';
import 'package:ordo/core/sync/sync_exceptions.dart';

/// Fake S3 底层客户端：按方法注入行为（默认抛 StateError 防漏配），
/// 参数（bucket/object/retrieveAcls/size/字节）记录到列表供断言。
class _FakeS3Ops implements S3Ops {
  Future<StatObjectResult> Function()? onStatObject;
  Future<MinioByteStream> Function()? onGetObject;
  Future<String> Function()? onPutObject;

  final List<String> statBuckets = [];
  final List<String> statObjects = [];
  final List<bool> statRetrieveAcls = [];
  final List<String> getBuckets = [];
  final List<String> getObjects = [];
  final List<String> putBuckets = [];
  final List<String> putObjects = [];
  final List<int?> putSizes = [];
  final List<Uint8List> putData = [];

  @override
  Future<StatObjectResult> statObject(
    String bucket,
    String object, {
    bool retrieveAcls = false,
  }) {
    statBuckets.add(bucket);
    statObjects.add(object);
    statRetrieveAcls.add(retrieveAcls);
    final handler = onStatObject;
    if (handler == null) throw StateError('onStatObject 未配置');
    return handler();
  }

  @override
  Future<MinioByteStream> getObject(String bucket, String object) {
    getBuckets.add(bucket);
    getObjects.add(object);
    final handler = onGetObject;
    if (handler == null) throw StateError('onGetObject 未配置');
    return handler();
  }

  @override
  Future<String> putObject(
    String bucket,
    String object,
    Stream<Uint8List> data, {
    int? size,
  }) async {
    putBuckets.add(bucket);
    putObjects.add(object);
    putSizes.add(size);
    final collected = await data.fold<List<int>>(
      <int>[],
      (acc, chunk) => acc..addAll(chunk),
    );
    putData.add(Uint8List.fromList(collected));
    final handler = onPutObject;
    if (handler == null) throw StateError('onPutObject 未配置');
    return handler();
  }
}

/// 构造 S3 错误（MinioS3Error）。
///
/// 注意：MinioResponse 不是 minio 的公开导出类型，测试无法构造带
/// statusCode 的实例；但分类逻辑**优先按 error.code 判定**
/// （真实服务器返回与 statusCode 同时具备），故 code 驱动足够覆盖全部分支。
MinioS3Error _s3Error(String code) {
  return MinioS3Error(code, Error(code, null, code, null));
}

/// 统一入口：注入 Fake ops，构造被测 store。
({S3RemoteStore store, _FakeS3Ops fake}) _build({
  String bucket = 'my-bucket',
  String prefix = 'todo/',
  String endpoint = 's3.example.com',
}) {
  final fake = _FakeS3Ops();
  final store = S3RemoteStore(
    endpoint: endpoint,
    accessKey: 'access',
    secretKey: 'secret',
    bucket: bucket,
    prefix: prefix,
    ops: fake,
  );
  return (store: store, fake: fake);
}

void main() {
  group('exists', () {
    test('statObject 成功 → true，且必须传 retrieveAcls: false', () async {
      final t = _build();
      t.fake.onStatObject = () async => StatObjectResult();

      expect(await t.store.exists(), isTrue);
      expect(t.fake.statObjects.single, 'todo/data.json.gz');
      expect(t.fake.statBuckets.single, 'my-bucket');
      expect(
        t.fake.statRetrieveAcls.single,
        isFalse,
        reason: 'retrieveAcls 必须为 false（MinIO/R2 ?acl 非标准 XML）',
      );
    });

    test('NoSuchKey → false（对象不存在，§9 契约）', () async {
      final t = _build();
      t.fake.onStatObject = () async => throw _s3Error('NoSuchKey');

      expect(await t.store.exists(), isFalse);
    });

    test('NotFound → false（对象不存在）', () async {
      final t = _build();
      t.fake.onStatObject = () async => throw _s3Error('NotFound');

      expect(await t.store.exists(), isFalse);
    });

    test('AccessDenied → SyncAuthException（§12 认证失败，不重试）', () async {
      final t = _build();
      t.fake.onStatObject = () async => throw _s3Error('AccessDenied');

      await expectLater(t.store.exists(), throwsA(isA<SyncAuthException>()));
    });

    test('MinioError（连接失败）→ SyncNetworkException（退避重试）', () async {
      final t = _build();
      t.fake.onStatObject = () async => throw MinioError('Connection refused');

      await expectLater(t.store.exists(), throwsA(isA<SyncNetworkException>()));
    });

    test('http.ClientException（http 栈直抛，未包装）→ SyncNetworkException', () async {
      // minio 3.5.8 底层网络失败直接抛 ClientException（源码未包装进 MinioError）。
      final t = _build();
      t.fake.onStatObject = () async =>
          throw http.ClientException('Connection refused');

      await expectLater(t.store.exists(), throwsA(isA<SyncNetworkException>()));
    });

    test('其他错误（InternalError）→ SyncRemoteException', () async {
      final t = _build();
      t.fake.onStatObject = () async => throw _s3Error('InternalError');

      await expectLater(t.store.exists(), throwsA(isA<SyncRemoteException>()));
    });
  });

  group('download', () {
    test('getObject 字节流 → Uint8List', () async {
      final t = _build();
      final raw = Uint8List.fromList([1, 2, 3, 255, 0]);
      t.fake.onGetObject = () async => MinioByteStream.fromStream(
        stream: Stream.value(raw),
        contentLength: raw.length,
      );

      final bytes = await t.store.download();

      expect(bytes, isA<Uint8List>());
      expect(bytes, raw);
      expect(t.fake.getObjects.single, 'todo/data.json.gz');
      expect(t.fake.getBuckets.single, 'my-bucket');
    });

    test('NoSuchKey → null（对象不存在）', () async {
      final t = _build();
      t.fake.onGetObject = () async => throw _s3Error('NoSuchKey');

      expect(await t.store.download(), isNull);
    });

    test('AccessDenied → SyncAuthException', () async {
      final t = _build();
      t.fake.onGetObject = () async => throw _s3Error('AccessDenied');

      await expectLater(t.store.download(), throwsA(isA<SyncAuthException>()));
    });

    test('MinioError → SyncNetworkException', () async {
      final t = _build();
      t.fake.onGetObject = () async => throw MinioError('DNS lookup failed');

      await expectLater(
        t.store.download(),
        throwsA(isA<SyncNetworkException>()),
      );
    });
  });

  group('lastModified', () {
    test('返回 UTC 归一时间（同一时间点，§3 时间一律 UTC）', () async {
      final t = _build();
      // 模拟极端情况：底层返回本地时区表示的时间（真实 minio 返回 UTC，
      // 但接口契约要求 toUtc 归一，测试确保实现做了归一）。
      final instant = DateTime.utc(2026, 8, 12, 8, 30, 0);
      final localLastModified = instant.toLocal();
      expect(localLastModified.isUtc, isFalse, reason: '前置：本地时区表示');
      t.fake.onStatObject = () async =>
          StatObjectResult(lastModified: localLastModified);

      final modified = await t.store.lastModified();

      expect(modified, isNotNull);
      expect(modified!.isUtc, isTrue, reason: '必须转 UTC（§3）');
      expect(
        modified.millisecondsSinceEpoch,
        instant.millisecondsSinceEpoch,
        reason: 'toUtc 保持同一时间点',
      );
    });

    test('NoSuchKey → null（对象不存在）', () async {
      final t = _build();
      t.fake.onStatObject = () async => throw _s3Error('NoSuchKey');

      expect(await t.store.lastModified(), isNull);
    });

    test('lastModified 为 null（无该元数据）→ null', () async {
      final t = _build();
      t.fake.onStatObject = () async => StatObjectResult();

      expect(await t.store.lastModified(), isNull);
    });

    test('AccessDenied → SyncAuthException', () async {
      final t = _build();
      t.fake.onStatObject = () async => throw _s3Error('AccessDenied');

      await expectLater(
        t.store.lastModified(),
        throwsA(isA<SyncAuthException>()),
      );
    });
  });

  group('upload', () {
    test('putObject 传入正确 bucket/对象键/字节/size', () async {
      final t = _build();
      t.fake.onPutObject = () async => 'etag';
      final payload = Uint8List.fromList([9, 8, 7, 6]);

      await t.store.upload(payload);

      expect(t.fake.putObjects.single, 'todo/data.json.gz');
      expect(t.fake.putBuckets.single, 'my-bucket');
      expect(t.fake.putSizes.single, payload.length);
      expect(t.fake.putData.single, payload);
    });

    test('AccessDenied → SyncAuthException（不重试类）', () async {
      final t = _build();
      t.fake.onPutObject = () async => throw _s3Error('AccessDenied');

      await expectLater(
        t.store.upload(Uint8List(0)),
        throwsA(isA<SyncAuthException>()),
      );
    });

    test('MinioError → SyncNetworkException（重试类）', () async {
      final t = _build();
      t.fake.onPutObject = () async => throw MinioError('Connection timeout');

      await expectLater(
        t.store.upload(Uint8List(0)),
        throwsA(isA<SyncNetworkException>()),
      );
    });

    test('上传遇 NoSuchKey 视为远端异常（非「对象不存在」）', () async {
      final t = _build();
      t.fake.onPutObject = () async => throw _s3Error('NoSuchKey');

      await expectLater(
        t.store.upload(Uint8List(0)),
        throwsA(isA<SyncRemoteException>()),
      );
    });
  });

  group('对象键拼接', () {
    test("prefix 'todo/' + 默认 key → 'todo/data.json.gz'", () async {
      final t = _build();
      t.fake.onStatObject = () async => StatObjectResult();

      await t.store.exists();

      expect(t.fake.statObjects.single, 'todo/data.json.gz');
    });

    test('prefix 缺尾 / 时自动补齐（与 WebDAV baseUrl 归一一致）', () async {
      final t = _build(prefix: 'todo');
      t.fake.onStatObject = () async => StatObjectResult();

      await t.store.exists();

      expect(t.fake.statObjects.single, 'todo/data.json.gz');
    });

    test('prefix 为空 → 对象键直接是 key（桶根）', () async {
      final t = _build(prefix: '');
      t.fake.onStatObject = () async => StatObjectResult();

      await t.store.exists();

      expect(t.fake.statObjects.single, 'data.json.gz');
    });

    test('构造函数默认 prefix 为 todo/', () async {
      final fake = _FakeS3Ops();
      final store = S3RemoteStore(
        endpoint: 's3.example.com',
        accessKey: 'a',
        secretKey: 's',
        bucket: 'b',
        ops: fake,
      );
      fake.onStatObject = () async => StatObjectResult();

      await store.exists();

      expect(fake.statObjects.single, 'todo/data.json.gz');
    });
  });

  group('构造函数配置校验', () {
    test('endpoint 为空 → SyncConfigException', () {
      expect(
        () => S3RemoteStore(
          endpoint: '   ',
          accessKey: 'a',
          secretKey: 's',
          bucket: 'b',
        ),
        throwsA(isA<SyncConfigException>()),
      );
    });

    test('endpoint 为空 → SyncConfigException（即使注入 ops）', () {
      expect(
        () => S3RemoteStore(
          endpoint: '',
          accessKey: 'a',
          secretKey: 's',
          bucket: 'b',
          ops: _FakeS3Ops(),
        ),
        throwsA(isA<SyncConfigException>()),
      );
    });

    test('bucket 为空 → SyncConfigException（即使注入 ops）', () {
      expect(
        () => S3RemoteStore(
          endpoint: 's3.example.com',
          accessKey: 'a',
          secretKey: 's',
          bucket: ' ',
          ops: _FakeS3Ops(),
        ),
        throwsA(isA<SyncConfigException>()),
      );
    });
  });

  group('RemoteStoreFactory（§9.3）', () {
    test('s3 有效配置 → 返回 S3RemoteStore', () {
      final store = RemoteStoreFactory.fromConfig(
        const SyncConfig(
          type: RemoteType.s3,
          serverUrl: 's3.example.com',
          username: 'access',
          secret: 'secret',
          bucket: 'my-bucket',
          region: 'auto',
          prefix: 'todo/',
        ),
      );

      expect(store, isA<S3RemoteStore>());
    });

    test('s3 缺 serverUrl → SyncConfigException', () {
      expect(
        () => RemoteStoreFactory.fromConfig(
          const SyncConfig(
            type: RemoteType.s3,
            serverUrl: null,
            bucket: 'my-bucket',
          ),
        ),
        throwsA(isA<SyncConfigException>()),
      );
    });

    test('s3 serverUrl 全空白 → SyncConfigException', () {
      expect(
        () => RemoteStoreFactory.fromConfig(
          const SyncConfig(
            type: RemoteType.s3,
            serverUrl: '   ',
            bucket: 'my-bucket',
          ),
        ),
        throwsA(isA<SyncConfigException>()),
      );
    });

    test('s3 缺 bucket → SyncConfigException', () {
      expect(
        () => RemoteStoreFactory.fromConfig(
          const SyncConfig(
            type: RemoteType.s3,
            serverUrl: 's3.example.com',
            bucket: null,
          ),
        ),
        throwsA(isA<SyncConfigException>()),
      );
    });

    test('s3 缺 endpoint 但无 bucket → SyncConfigException（先报 endpoint）', () {
      expect(
        () => RemoteStoreFactory.fromConfig(
          const SyncConfig(type: RemoteType.s3, serverUrl: null, bucket: null),
        ),
        throwsA(isA<SyncConfigException>()),
      );
    });
  });
}
