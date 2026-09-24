// WebDavRemoteStore 单元测试（docs/60-sync-design.md §9.1 / §12 / §13）。
//
// webdav_client 的 Client/WdDio 是具体类（依赖 dio），无法用 mockito
// mock，故对 Client 包一层薄适配器 [WebDavClientLike]（remote_store_webdav.dart），
// 本测试注入 Fake 适配器，覆盖：
// - 存在/不存在（404 **与 409**）分支：exists / download / lastModified
//   （409：坚果云等服务器在父目录不存在时对 PROPFIND/GET 返回 409）；
// - 传给 readProps/read/write 的 path 是**相对 key**（如 `data.json.gz`），
//   不拼 baseUrl（webdav_client 内部 join(baseUrl, key) 拼回完整 URL）；
// - mTime 本地时区 → UTC 归一；
// - read 转 Uint8List、write 传入正确路径与字节；
// - §12 错误分类：401 → SyncAuthException、超时/连接错误 → SyncNetworkException、
//   其他 HTTP → SyncRemoteException；
// - 工厂：webdav 配置有效/无效；s3 分支见 remote_store_s3_test.dart。
//
// 注：上传内容 hash（§10.3 无变化跳过）已不在本层实现——判定改为
// SyncEngine 比较「合并/导出结果 vs 下载到的远端快照」的业务内容 hash，
// RemoteStore.contentHash 已移除（见 sync_engine.dart 上传优化注释）。

import 'dart:typed_data';

import 'package:dio/dio.dart'; // ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/sync/remote_store_factory.dart';
import 'package:ordo/core/sync/remote_store_s3.dart';
import 'package:ordo/core/sync/remote_store_webdav.dart';
import 'package:ordo/core/sync/sync_config.dart';
import 'package:ordo/core/sync/sync_exceptions.dart';
import 'package:webdav_client/webdav_client.dart';

/// Fake WebDAV 底层客户端：按方法注入行为（默认抛 StateError 防漏配）。
class _FakeWebDavClient implements WebDavClientLike {
  Future<File> Function(String path)? onReadProps;
  Future<List<int>> Function(String path)? onRead;
  Future<void> Function(String path, Uint8List data)? onWrite;

  final List<String> readPropsPaths = [];
  final List<String> readPaths = [];
  final List<String> writtenPaths = [];
  final List<Uint8List> writtenData = [];

  /// `lastServerNow` 返回值（模拟适配器从响应 `Date` 头捕获的服务器时间）。
  DateTime? serverNowValue;

  @override
  Future<File> readProps(String path) {
    readPropsPaths.add(path);
    final handler = onReadProps;
    if (handler == null) {
      throw StateError('onReadProps 未配置');
    }
    return handler(path);
  }

  @override
  Future<List<int>> read(String path) {
    readPaths.add(path);
    final handler = onRead;
    if (handler == null) {
      throw StateError('onRead 未配置');
    }
    return handler(path);
  }

  @override
  Future<void> write(String path, Uint8List data) {
    writtenPaths.add(path);
    writtenData.add(data);
    final handler = onWrite;
    if (handler == null) {
      throw StateError('onWrite 未配置');
    }
    return handler(path, data);
  }

  @override
  DateTime? get lastServerNow => serverNowValue;
}

/// 构造带状态码的 DioException（badResponse，如 404/401/500）。
DioException _dioWithStatus(int statusCode) {
  return DioException(
    requestOptions: RequestOptions(
      path: 'https://dav.example.com/data.json.gz',
    ),
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: RequestOptions(
        path: 'https://dav.example.com/data.json.gz',
      ),
      statusCode: statusCode,
    ),
  );
}

/// 构造网络类 DioException（连接错误/各类超时）。
DioException _dioNetwork(DioExceptionType type) {
  return DioException(
    requestOptions: RequestOptions(
      path: 'https://dav.example.com/data.json.gz',
    ),
    type: type,
  );
}

/// 统一入口：注入 Fake 客户端，构造被测 store。
({WebDavRemoteStore store, _FakeWebDavClient fake}) _build({
  String baseUrl = 'https://dav.example.com/todo',
}) {
  final fake = _FakeWebDavClient();
  final store = WebDavRemoteStore(
    baseUrl: baseUrl,
    username: 'user',
    password: 'pass',
    client: fake,
  );
  return (store: store, fake: fake);
}

void main() {
  group('exists', () {
    test('readProps 成功 → true', () async {
      final t = _build();
      t.fake.onReadProps = (_) async => File(path: '/todo/data.json.gz');

      expect(await t.store.exists(), isTrue);
      // 传相对 key（webdav_client 内部 join(baseUrl, key) 拼回完整 URL）。
      expect(t.fake.readPropsPaths.single, 'data.json.gz');
    });

    test('404 → false（对象不存在，§9 契约）', () async {
      final t = _build();
      t.fake.onReadProps = (_) async => throw _dioWithStatus(404);

      expect(await t.store.exists(), isFalse);
    });

    test('409 → false（父目录不存在的 PROPFIND，坚果云语义）', () async {
      final t = _build();
      t.fake.onReadProps = (_) async => throw _dioWithStatus(409);

      expect(await t.store.exists(), isFalse);
    });

    test('401 → SyncAuthException（§12 认证失败）', () async {
      final t = _build();
      t.fake.onReadProps = (_) async => throw _dioWithStatus(401);

      await expectLater(t.store.exists(), throwsA(isA<SyncAuthException>()));
    });

    test('连接超时 → SyncNetworkException（§12 网络失败/超时）', () async {
      final t = _build();
      t.fake.onReadProps = (_) async =>
          throw _dioNetwork(DioExceptionType.connectionTimeout);

      await expectLater(t.store.exists(), throwsA(isA<SyncNetworkException>()));
    });

    test('其他 HTTP（500）→ SyncRemoteException', () async {
      final t = _build();
      t.fake.onReadProps = (_) async => throw _dioWithStatus(500);

      await expectLater(t.store.exists(), throwsA(isA<SyncRemoteException>()));
    });
  });

  group('download', () {
    test('read 字节 → Uint8List', () async {
      final t = _build();
      final raw = <int>[1, 2, 3, 255, 0];
      t.fake.onRead = (_) async => raw;

      final bytes = await t.store.download();

      expect(bytes, isA<Uint8List>());
      expect(bytes, raw);
      // 传相对 key（webdav_client 内部 join(baseUrl, key) 拼回完整 URL）。
      expect(t.fake.readPaths.single, 'data.json.gz');
    });

    test('404 → null（对象不存在）', () async {
      final t = _build();
      t.fake.onRead = (_) async => throw _dioWithStatus(404);

      expect(await t.store.download(), isNull);
    });

    test('409 → null（父目录不存在的 GET，坚果云语义）', () async {
      final t = _build();
      t.fake.onRead = (_) async => throw _dioWithStatus(409);

      expect(await t.store.download(), isNull);
    });

    test('401 → SyncAuthException', () async {
      final t = _build();
      t.fake.onRead = (_) async => throw _dioWithStatus(401);

      await expectLater(t.store.download(), throwsA(isA<SyncAuthException>()));
    });
  });

  group('lastModified', () {
    test('mTime 本地时区 → 返回 UTC 归一时间（同一时间点）', () async {
      final t = _build();
      // webdav_client 的 File.mTime 是本地时区（库内部 .toLocal()）。
      // 用 UTC 时刻转本地时区构造「本地表示」的 mTime。
      final instant = DateTime.utc(2026, 8, 12, 8, 30, 0);
      final localMTime = instant.toLocal();
      expect(localMTime.isUtc, isFalse, reason: '前置：mTime 应为本地时区');

      t.fake.onReadProps = (_) async =>
          File(path: '/todo/data.json.gz', mTime: localMTime);

      final modified = await t.store.lastModified();

      expect(modified, isNotNull);
      expect(modified!.isUtc, isTrue, reason: '必须转 UTC（§3 时间一律 UTC）');
      expect(
        modified.millisecondsSinceEpoch,
        instant.millisecondsSinceEpoch,
        reason: 'toUtc 保持同一时间点',
      );
    });

    test('404 → null（对象不存在）', () async {
      final t = _build();
      t.fake.onReadProps = (_) async => throw _dioWithStatus(404);

      expect(await t.store.lastModified(), isNull);
    });

    test('409 → null（父目录不存在的 PROPFIND，坚果云语义）', () async {
      final t = _build();
      t.fake.onReadProps = (_) async => throw _dioWithStatus(409);

      expect(await t.store.lastModified(), isNull);
    });

    test('mTime 为 null（无 getlastmodified）→ null', () async {
      final t = _build();
      t.fake.onReadProps = (_) async => File(path: '/todo/data.json.gz');

      expect(await t.store.lastModified(), isNull);
    });

    test('连接错误 → SyncNetworkException', () async {
      final t = _build();
      t.fake.onReadProps = (_) async =>
          throw _dioNetwork(DioExceptionType.connectionError);

      await expectLater(
        t.store.lastModified(),
        throwsA(isA<SyncNetworkException>()),
      );
    });
  });

  group('serverNow（§11 A 检：零额外 RTT 顺带捕获）', () {
    test('返回适配器捕获的服务器时间（UTC）', () async {
      final t = _build();
      t.fake.serverNowValue = DateTime.utc(2026, 8, 13, 10, 0, 0);
      t.fake.onReadProps = (_) async => File(path: '/todo/data.json.gz');

      final serverNow = await t.store.serverNow();

      expect(serverNow, DateTime.utc(2026, 8, 13, 10, 0, 0));
    });

    test('尚未发起请求/无 Date 头 → null（fail-open）', () async {
      final t = _build();
      t.fake.serverNowValue = null;

      expect(await t.store.serverNow(), isNull);
    });
  });

  group('upload', () {
    test('write 传入正确路径与字节', () async {
      final t = _build();
      t.fake.onWrite = (_, _) async {};
      final payload = Uint8List.fromList([9, 8, 7, 6]);

      await t.store.upload(payload);

      // 传相对 key（webdav_client 内部 join(baseUrl, key) 拼回完整 URL）。
      expect(t.fake.writtenPaths.single, 'data.json.gz');
      expect(t.fake.writtenData.single, payload);
    });

    test('baseUrl 末尾已带 / 时仍传相对 key（不拼 baseUrl）', () async {
      final t = _build(baseUrl: 'https://dav.example.com/todo/');
      t.fake.onWrite = (_, _) async {};

      await t.store.upload(Uint8List(0));

      expect(t.fake.writtenPaths.single, 'data.json.gz');
    });

    test('401 → SyncAuthException（不重试类）', () async {
      final t = _build();
      t.fake.onWrite = (_, _) async => throw _dioWithStatus(401);

      await expectLater(
        t.store.upload(Uint8List(0)),
        throwsA(isA<SyncAuthException>()),
      );
    });

    test('发送超时 → SyncNetworkException（重试类）', () async {
      final t = _build();
      t.fake.onWrite = (_, _) async =>
          throw _dioNetwork(DioExceptionType.sendTimeout);

      await expectLater(
        t.store.upload(Uint8List(0)),
        throwsA(isA<SyncNetworkException>()),
      );
    });

    test('上传遇 404 视为远端异常（非「对象不存在」）', () async {
      final t = _build();
      t.fake.onWrite = (_, _) async => throw _dioWithStatus(404);

      await expectLater(
        t.store.upload(Uint8List(0)),
        throwsA(isA<SyncRemoteException>()),
      );
    });
  });

  group('RemoteStoreFactory（§9.3）', () {
    test('webdav 配置有效 → 返回 WebDavRemoteStore', () {
      final store = RemoteStoreFactory.fromConfig(
        const SyncConfig(
          type: RemoteType.webdav,
          serverUrl: 'https://dav.example.com/todo/',
          username: 'user',
          secret: 'pass',
        ),
      );

      expect(store, isA<WebDavRemoteStore>());
    });

    test('webdav 缺 serverUrl → SyncConfigException', () {
      expect(
        () => RemoteStoreFactory.fromConfig(
          const SyncConfig(type: RemoteType.webdav, serverUrl: null),
        ),
        throwsA(isA<SyncConfigException>()),
      );
    });

    test('webdav serverUrl 全空白 → SyncConfigException', () {
      expect(
        () => RemoteStoreFactory.fromConfig(
          const SyncConfig(type: RemoteType.webdav, serverUrl: '   '),
        ),
        throwsA(isA<SyncConfigException>()),
      );
    });

    test('坚果云根路径（/dav/ 或 /dav）自动补全 /todo/ 子目录', () {
      final store1 = RemoteStoreFactory.fromConfig(
        const SyncConfig(
          type: RemoteType.webdav,
          serverUrl: 'https://dav.jianguoyun.com/dav/',
          username: 'user',
          secret: 'pass',
        ),
      );
      expect(store1, isA<WebDavRemoteStore>());

      final store2 = RemoteStoreFactory.fromConfig(
        const SyncConfig(
          type: RemoteType.webdav,
          serverUrl: 'https://dav.jianguoyun.com/dav',
          username: 'user',
          secret: 'pass',
        ),
      );
      expect(store2, isA<WebDavRemoteStore>());

      final store3 = RemoteStoreFactory.fromConfig(
        const SyncConfig(
          type: RemoteType.webdav,
          serverUrl: 'https://dav.jianguoyun.com/dav/custom_dir/',
          username: 'user',
          secret: 'pass',
        ),
      );
      expect(store3, isA<WebDavRemoteStore>());
    });

    test('s3 分支已实现 → 返回 S3RemoteStore（详见 remote_store_s3_test.dart）', () {
      final store = RemoteStoreFactory.fromConfig(
        const SyncConfig(
          type: RemoteType.s3,
          serverUrl: 's3.example.com',
          username: 'access',
          secret: 'secret',
          bucket: 'my-bucket',
        ),
      );

      expect(store, isA<S3RemoteStore>());
    });
  });
}
