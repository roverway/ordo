// WebDavClientAdapter 单元测试（Bug 1 回归）。
//
// 背景：生产适配器由封装 webdav_client.Client 改为**直接基于 Dio** 实现
// PROPFIND/GET/PUT/MKCOL，以规避 webdav_client 两个已知缺陷：
//   1. OPTIONS 预检硬性要求 200（真实服务器对不存在的目标常返回 404/204/405，
//      导致「测试连接正常但同步报远端服务器错误」）；
//   2. PUT 逐字节流上传（移动端慢网络下放大耗时触发服务器/反代超时）。
//
// 本测试通过注入 fake HttpClientAdapter 驱动真实 Dio，断言：
// - 不再发 OPTIONS（read/write 首请求即为 GET/PUT）；
// - write 父目录缺失（409/404）→ 递归 MKCOL → 重试 PUT；
// - 相对 key 拼回完整 URL；
// - PROPFIND 207 解析 mTime 为 UTC（RFC 1123 getlastmodified）；
// - 401 Basic 挑战协商（NoAuth 首请求 → 带 Authorization 重试）；
// - 凭据非空时预置 Basic 头（首请求即带认证，减少 401 往返）；
// - 非 2xx/207 状态抛 DioException(badResponse)（store 分类契约不变）。

import 'dart:typed_data';

import 'package:dio/dio.dart'; // ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/sync/remote_store_webdav.dart';

/// fake HttpClientAdapter：记录每个请求，按注入 handler 返回响应。
class _FakeHttpAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  ResponseBody Function(RequestOptions options)? onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final handler = onFetch;
    if (handler == null) throw StateError('onFetch 未配置');
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// 构造注入 fake 适配器的真实生产适配器。
WebDavClientAdapter _build(
  _FakeHttpAdapter fake, {
  String baseUrl = 'https://dav.example.com/todo',
  String username = '',
  String password = '',
}) {
  final dio = Dio(
    BaseOptions(
      validateStatus: (_) => true,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  )..httpClientAdapter = fake;
  return WebDavClientAdapter.create(
    baseUrl: baseUrl,
    username: username,
    password: password,
    dio: dio,
  );
}

/// 带一个请求的默认 handler：全返回 [status]。
ResponseBody _body(String text, int status, [Map<String, String>? headers]) {
  return ResponseBody.fromString(
    text,
    status,
    headers: headers == null
        ? null
        : {
            for (final e in headers.entries) e.key: [e.value],
          },
  );
}

const String _kXml207 = '''
<?xml version="1.0"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/todo/data.json.gz</d:href>
    <d:propstat>
      <d:prop>
        <d:getlastmodified>Thu, 13 Aug 2026 10:00:00 GMT</d:getlastmodified>
      </d:prop>
      <d:status>HTTP/1.1 200 OK</d:status>
    </d:propstat>
  </d:response>
</d:multistatus>''';

void main() {
  group('不再发 OPTIONS 预检（Bug 1 核心回归）', () {
    test('read：首请求即 GET，不再有 OPTIONS', () async {
      final fake = _FakeHttpAdapter();
      fake.onFetch = (_) =>
          ResponseBody.fromBytes(Uint8List.fromList([1, 2, 3]), 200);
      final adapter = _build(fake);

      final bytes = await adapter.read('data.json.gz');

      expect(bytes, [1, 2, 3]);
      expect(
        fake.requests.map((r) => r.method).toList(),
        ['GET'],
        reason: '旧实现 read 前会先发 OPTIONS 预检',
      );
      expect(
        fake.requests.single.path,
        'https://dav.example.com/todo/data.json.gz',
      );
    });

    test('write：首请求即 PUT，不再有 OPTIONS', () async {
      final fake = _FakeHttpAdapter();
      fake.onFetch = (_) => _body('', 201);
      final adapter = _build(fake);

      await adapter.write('data.json.gz', Uint8List.fromList([1, 2]));

      expect(
        fake.requests.map((r) => r.method).toList(),
        ['PUT'],
        reason: '旧实现 write 前会先发 OPTIONS 预检',
      );
      expect(
        fake.requests.single.path,
        'https://dav.example.com/todo/data.json.gz',
      );
    });
  });

  group('write 父目录缺失 → 递归建目录重试', () {
    test('PUT 409 → MKCOL(201) → 重试 PUT(201) 成功', () async {
      final fake = _FakeHttpAdapter();
      var putCount = 0;
      fake.onFetch = (options) {
        switch (options.method) {
          case 'PUT':
            putCount++;
            return _body('', putCount == 1 ? 409 : 201);
          case 'MKCOL':
            return _body('', 201);
          default:
            return _body('', 500);
        }
      };
      final adapter = _build(fake);

      await adapter.write('sub/data.json.gz', Uint8List.fromList([1]));

      expect(fake.requests.map((r) => '${r.method} ${r.path}').toList(), [
        'PUT https://dav.example.com/todo/sub/data.json.gz',
        'MKCOL https://dav.example.com/todo/sub/',
        'PUT https://dav.example.com/todo/sub/data.json.gz',
      ]);
    });

    test('PUT 404 → MKCOL 已存在(405) → 重试 PUT 成功', () async {
      final fake = _FakeHttpAdapter();
      var putCount = 0;
      fake.onFetch = (options) {
        if (options.method == 'PUT') {
          putCount++;
          return _body('', putCount == 1 ? 404 : 204);
        }
        return _body('', 405); // MKCOL 目录已存在。
      };
      final adapter = _build(fake);

      await adapter.write('a/b/data.json.gz', Uint8List.fromList([1]));

      expect(putCount, 2);
      // P3-8 优化：先试完整父路径 a/b/（405 已存在即完成），不再逐级。
      expect(fake.requests.where((r) => r.method == 'MKCOL').length, 1);
      expect(
        fake.requests.singleWhere((r) => r.method == 'MKCOL').path,
        'https://dav.example.com/todo/a/b/',
      );
    });

    test('PUT 409（配置目录不存在）→ 创建 baseUrl 目录 → 重试成功（用户实测场景）', () async {
      final fake = _FakeHttpAdapter();
      var putCount = 0;
      fake.onFetch = (options) {
        if (options.method == 'PUT') {
          putCount++;
          // 第一次 PUT：baseUrl 目录（mytodotest）不存在 → 坚果云 409。
          return _body('', putCount == 1 ? 409 : 201);
        }
        return _body('', 201); // MKCOL 创建 baseUrl 目录成功。
      };
      final adapter = _build(fake);

      await adapter.write('data.json.gz', Uint8List.fromList([1]));

      expect(putCount, 2);
      expect(fake.requests.map((r) => '${r.method} ${r.path}').toList(), [
        'PUT https://dav.example.com/todo/data.json.gz',
        // 修复：key 无父级时也须确保 baseUrl 目录本身存在。
        'MKCOL https://dav.example.com/todo/',
        'PUT https://dav.example.com/todo/data.json.gz',
      ]);
    });

    test('MKCOL 整段 409 → 从根逐级创建（403 系统根跳过，坚果云语义）', () async {
      final fake = _FakeHttpAdapter();
      var putCount = 0;
      var mkcolCount = 0;
      fake.onFetch = (options) {
        switch (options.method) {
          case 'PUT':
            putCount++;
            // 第一次 PUT：baseUrl 目录不存在 → 409。
            return _body('', putCount == 1 ? 409 : 201);
          case 'MKCOL':
            mkcolCount++;
            // 第 1 个 MKCOL：整段目标目录 → 父链缺失 409（触发逐级）。
            if (mkcolCount == 1) return _body('', 409);
            // 逐级：系统根 /dav/ → 403（视为已存在跳过）。
            if (options.path == 'https://dav.example.com/dav/') {
              return _body('', 403);
            }
            return _body('', 201);
          default:
            return _body('', 500);
        }
      };
      final adapter = _build(
        fake,
        baseUrl: 'https://dav.example.com/dav/Apps/mytodotest',
      );

      await adapter.write('data.json.gz', Uint8List.fromList([1]));

      // PUT 409 → 整段 MKCOL(409) → 逐级 /dav/(403) → /dav/Apps/(201)
      // → /dav/Apps/mytodotest/(201) → 重试 PUT。
      expect(fake.requests.map((r) => '${r.method} ${r.path}').toList(), [
        'PUT https://dav.example.com/dav/Apps/mytodotest/data.json.gz',
        'MKCOL https://dav.example.com/dav/Apps/mytodotest/',
        'MKCOL https://dav.example.com/dav/',
        'MKCOL https://dav.example.com/dav/Apps/',
        'MKCOL https://dav.example.com/dav/Apps/mytodotest/',
        'PUT https://dav.example.com/dav/Apps/mytodotest/data.json.gz',
      ]);
    });
  });

  group('readProps 解析 mTime', () {
    test('PROPFIND 207 → File.mTime 为对应 UTC 时刻', () async {
      final fake = _FakeHttpAdapter();
      fake.onFetch = (_) =>
          _body(_kXml207, 207, {'content-type': 'application/xml'});
      final adapter = _build(fake);

      final file = await adapter.readProps('data.json.gz');

      expect(file.mTime, DateTime.utc(2026, 8, 13, 10, 0, 0));
      expect(
        file.mTime!.isUtc,
        isTrue,
        reason: 'mTime 必须 UTC 归一（§3 时间一律 UTC 毫秒）',
      );
    });

    test('PROPFIND 404 → DioException(badResponse, statusCode 404)', () async {
      final fake = _FakeHttpAdapter();
      fake.onFetch = (_) => _body('', 404);
      final adapter = _build(fake);

      await expectLater(
        adapter.readProps('data.json.gz'),
        throwsA(
          isA<DioException>()
              .having((e) => e.type, 'type', DioExceptionType.badResponse)
              .having((e) => e.response?.statusCode, 'status', 404),
        ),
      );
    });
  });

  group('serverNow 捕获（§11 A 检，零额外 RTT）', () {
    test('响应携带 Date 头 → 顺带捕获为 UTC 服务器时间', () async {
      final fake = _FakeHttpAdapter();
      fake.onFetch = (_) => _body(_kXml207, 207, {
        'content-type': 'application/xml',
        'date': 'Thu, 13 Aug 2026 10:00:00 GMT',
      });
      final adapter = _build(fake);

      await adapter.readProps('data.json.gz');

      expect(adapter.lastServerNow, DateTime.utc(2026, 8, 13, 10, 0, 0));
      expect(adapter.lastServerNow!.isUtc, isTrue, reason: '§3 时间一律 UTC');
    });

    test('无 Date 头 → null（fail-open）', () async {
      final fake = _FakeHttpAdapter();
      fake.onFetch = (_) =>
          _body(_kXml207, 207, {'content-type': 'application/xml'});
      final adapter = _build(fake);

      await adapter.readProps('data.json.gz');

      expect(adapter.lastServerNow, isNull);
    });
  });

  group('401 认证协商', () {
    test('NoAuth 首请求 401 Basic 挑战 → 重试带 Authorization 头', () async {
      final fake = _FakeHttpAdapter();
      fake.onFetch = (options) {
        if (options.headers['authorization'] == null) {
          return _body('', 401, {'www-authenticate': 'Basic realm="test"'});
        }
        return _body(_kXml207, 207, {'content-type': 'application/xml'});
      };
      // username 为空 → 初始 NoAuth（旧语义）。
      final adapter = _build(fake, username: '', password: '');

      await adapter.readProps('data.json.gz');

      expect(fake.requests.length, 2);
      expect(fake.requests.first.headers['authorization'], isNull);
      expect(
        (fake.requests.last.headers['authorization'] as String).startsWith(
          'Basic ',
        ),
        isTrue,
      );
    });

    test('凭据非空 → 预置 Basic 头，首请求即带认证（减少 401 往返）', () async {
      final fake = _FakeHttpAdapter();
      fake.onFetch = (_) => _body('', 201);
      final adapter = _build(fake, username: 'user', password: 'pass');

      await adapter.write('data.json.gz', Uint8List.fromList([1]));

      expect(fake.requests.single.method, 'PUT');
      expect(
        (fake.requests.single.headers['authorization'] as String).startsWith(
          'Basic ',
        ),
        isTrue,
        reason: '凭据非空应预置 Basic，避免每次同步首请求都多一轮 401',
      );
    });

    test('凭据错误 → 401 原样上抛（不无限重试）', () async {
      final fake = _FakeHttpAdapter();
      fake.onFetch = (_) =>
          _body('', 401, {'www-authenticate': 'Basic realm="test"'});
      final adapter = _build(fake, username: 'user', password: 'wrong');

      await expectLater(
        adapter.read('data.json.gz'),
        throwsA(isA<DioException>()),
      );
      // 预置 Basic 后 401 不再协商（凭据错误），只请求一次。
      expect(fake.requests.length, 1);
    });

    test('预置 Basic → 401 Digest 挑战 → 切换 DigestAuth 重试成功', () async {
      final fake = _FakeHttpAdapter();
      fake.onFetch = (options) {
        final auth = options.headers['authorization'] as String?;
        if (auth == null || auth.startsWith('Basic ')) {
          return _body('', 401, {
            'www-authenticate':
                'Digest realm="r", nonce="n1", qop="auth", opaque="o"',
          });
        }
        return _body(_kXml207, 207, {'content-type': 'application/xml'});
      };
      final adapter = _build(fake, username: 'user', password: 'pass');

      await adapter.readProps('data.json.gz');

      expect(fake.requests.length, 2);
      expect(
        (fake.requests.last.headers['authorization'] as String).startsWith(
          'Digest ',
        ),
        isTrue,
        reason: 'Basic 预置被服务器拒绝（Digest 挑战）时应升级为 DigestAuth',
      );
    });

    test('Digest stale=true → 重建 DigestAuth 续期重试', () async {
      final fake = _FakeHttpAdapter();
      var digestRequests = 0;
      fake.onFetch = (options) {
        final auth = options.headers['authorization'] as String?;
        if (auth == null || auth.startsWith('Basic ')) {
          return _body('', 401, {
            'www-authenticate': 'Digest realm="r", nonce="n1", qop="auth"',
          });
        }
        digestRequests++;
        if (digestRequests == 1) {
          return _body('', 401, {
            'www-authenticate':
                'Digest realm="r", nonce="n2", qop="auth", stale=true',
          });
        }
        return _body(_kXml207, 207, {'content-type': 'application/xml'});
      };
      final adapter = _build(fake, username: 'user', password: 'pass');

      await adapter.readProps('data.json.gz');

      // Basic 首探 → Digest 401 stale → 续期重试 → 207。
      expect(fake.requests.length, 3);
      expect(
        fake.requests
            .skip(1)
            .every(
              (r) =>
                  (r.headers['authorization'] as String).startsWith('Digest '),
            ),
        isTrue,
      );
    });

    test('401 无 WWW-Authenticate 挑战头 → 直接抛错，仅请求一次', () async {
      final fake = _FakeHttpAdapter();
      fake.onFetch = (_) => _body('', 401); // 无挑战头。
      final adapter = _build(fake, username: '', password: ''); // NoAuth。

      await expectLater(
        adapter.readProps('data.json.gz'),
        throwsA(isA<DioException>()),
      );
      expect(fake.requests.length, 1, reason: '无挑战头应直接失败，不空转重试');
    });

    test('重定向 Location 为相对路径 → resolveUri 解析后跟随', () async {
      final fake = _FakeHttpAdapter();
      var getCount = 0;
      fake.onFetch = (options) {
        getCount++;
        // NoAuth 始终不带 authorization，用请求计数区分首跳/重试。
        if (getCount == 1) {
          return _body('', 302, {'location': '/todo/data.json.gz'});
        }
        return ResponseBody.fromBytes(Uint8List.fromList([9]), 200);
      };
      final adapter = _build(fake, username: '', password: '');

      final bytes = await adapter.read('data.json.gz');

      expect(bytes, [9]);
      expect(fake.requests.length, 2);
      expect(
        fake.requests.last.path,
        'https://dav.example.com/todo/data.json.gz',
      );
    });

    test('跨主机重定向不转发凭据（Basic 不泄露给第三方）', () async {
      final fake = _FakeHttpAdapter();
      fake.onFetch = (options) {
        final auth = options.headers['authorization'] as String?;
        // 原主机：无论是否带认证都重定向到 CDN。
        if (options.path.startsWith('https://dav.example.com')) {
          return _body('', 302, {'location': 'https://cdn.example.com/file'});
        }
        // CDN：若凭据被转发 → 403 拒收（测试失败信号）。
        if (options.path.startsWith('https://cdn.example.com')) {
          if (auth != null) return _body('', 403);
          return ResponseBody.fromBytes(Uint8List.fromList([7]), 200);
        }
        return _body('', 500);
      };
      final adapter = _build(fake, username: 'user', password: 'pass');

      final bytes = await adapter.read('data.json.gz');

      expect(bytes, [7]);
      expect(fake.requests.length, 2);
      expect(
        fake.requests.last.headers['authorization'],
        isNull,
        reason: '跨主机重定向必须剥离凭据',
      );
    });

    test('跨主机重定向后目标 Basic 挑战 → 按新 origin 重新协商成功', () async {
      final fake = _FakeHttpAdapter();
      fake.onFetch = (options) {
        final auth = options.headers['authorization'] as String?;
        if (options.path.startsWith('https://dav.example.com')) {
          return _body('', 302, {'location': 'https://cdn.example.com/file'});
        }
        if (options.path.startsWith('https://cdn.example.com')) {
          if (auth == null) {
            // 未带凭据（跨主机不转发）→ 目标主机自己发起 Basic 挑战。
            return _body('', 401, {'www-authenticate': 'Basic realm="cdn"'});
          }
          return ResponseBody.fromBytes(Uint8List.fromList([7]), 200);
        }
        return _body('', 500);
      };
      final adapter = _build(fake, username: 'user', password: 'pass');

      final bytes = await adapter.read('data.json.gz');

      expect(bytes, [7]);
      // dav 302 → cdn 401(Basic 挑战) → cdn 200(带 Basic 头)。
      expect(fake.requests.length, 3);
      expect(fake.requests.last.path, 'https://cdn.example.com/file');
      expect(
        (fake.requests.last.headers['authorization'] as String).startsWith(
          'Basic ',
        ),
        isTrue,
        reason: '目标主机 Basic 挑战应对当前 origin 重新协商而非误判凭据错误',
      );
    });
  });
}
