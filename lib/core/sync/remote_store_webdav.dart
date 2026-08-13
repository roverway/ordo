// WebDAV RemoteStore 实现（docs/60-sync-design.md §9.1 / §12 / §13）。
//
// 调用约定：
// - exists/lastModified：readProps(path)（PROPFIND）；
// - download：read(path)（GET）→ List<int> → Uint8List；
// - upload：write(path, Uint8List)（PUT，父目录缺失时自动递归创建后重试）；
// - path 传**相对 key**（如 `data.json.gz`，见 remote_store.dart），由
//   WebDavClientAdapter 内部拼回完整 URL（`{baseUrl}/{key}`）。
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
// 可测试性：对底层客户端包一层薄适配器 [WebDavClientLike]，测试注入 Fake
// 实现（模拟 404/401/超时/时区 mTime），无需 mockito。

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

/// 重定向最大跟随次数（防重定向死循环）。
const int _kMaxRedirects = 5;

/// 401 认证协商最大尝试次数（Basic/Digest 升级 + Digest stale 续期）。
const int _kMaxAuthAttempts = 3;

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

/// PROPFIND 请求体（请求单文件属性，含 mTime）。
const String _kPropfindBody = '''
<d:propfind xmlns:d='DAV:'>
  <d:prop>
    <d:displayname/>
    <d:resourcetype/>
    <d:getcontentlength/>
    <d:getcontenttype/>
    <d:getetag/>
    <d:getlastmodified/>
  </d:prop>
</d:propfind>''';

/// 生产适配器：直接基于 Dio 实现 PROPFIND/GET/PUT/MKCOL。
///
/// 不再封装 webdav_client 的 Client/WdDio，规避其两个已知缺陷
/// （flymzero/webdav_client 已停更，issue 积压）——二者正是用户实测
/// 「测试连接正常但同步报远端服务器错误」的根因：
///
/// 1. **OPTIONS 预检硬性要求 200**：库的 read/write 第一步都发 OPTIONS 且
///    `statusCode != 200` 直接抛错（webdav_dio.dart:459/251）。真实服务器
///    （尤其 CDN/WAF 反代，及对尚不存在的上传目标）常返回 404/204/405
///    （issue #49、PR #56/#57 有真实抓包日志）→ 测试连接（仅 PROPFIND，
///    目标目录已存在）正常、真实同步失败。本实现**不发 OPTIONS 预检**。
/// 2. **逐字节流上传**：库把 PUT body 拆成每字节一个流事件
///    （`Stream.fromIterable(data.map((e) => [e]))`，1MB = 100 万事件 +
///    100 万次分配），在移动端慢网络下放大上传耗时，易触发服务器/反代
///    超时。本实现直接传字节（dio 自动带 Content-Length 定长发送）。
///
/// 认证：复用 webdav_client 导出的 Auth/BasicAuth/DigestAuth（401 挑战
/// 协商，兼容坚果云 Basic 应用密码与 Digest 服务器）。凭据非空时预置
/// Basic 头，Basic 服务器免去 401 往返（减少请求数，坚果云有 600 次/
/// 30 分钟频率限制）；Digest 挑战出现时自动切换。
class WebDavClientAdapter implements WebDavClientLike {
  WebDavClientAdapter._({
    required Dio dio,
    required String baseUrl,
    required String username,
    required String password,
  }) : _dio = dio,
       _baseUrl = baseUrl,
       _username = username,
       _password = password,
       _auth = username.isEmpty
           ? Auth(user: username, pwd: password)
           : BasicAuth(user: username, pwd: password);

  /// 创建真实客户端（超时配置与旧实现一致；[dio] 仅测试注入用）。
  factory WebDavClientAdapter.create({
    required String baseUrl,
    String username = '',
    String password = '',
    Dio? dio,
  }) {
    return WebDavClientAdapter._(
      dio:
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(milliseconds: _kConnectTimeoutMs),
              receiveTimeout: const Duration(milliseconds: _kTransferTimeoutMs),
              sendTimeout: const Duration(milliseconds: _kTransferTimeoutMs),
              // WebDAV 状态码语义由本类自行判断（207/200/201/204…）。
              validateStatus: (_) => true,
              // 重定向由 [_request] 手动跟随（部分服务器/反代会重定向）。
              followRedirects: false,
            ),
          ),
      baseUrl: baseUrl,
      username: username,
      password: password,
    );
  }

  final Dio _dio;
  final String _baseUrl;
  final String _username;
  final String _password;

  /// 认证状态（初始 BasicAuth/NoAuth，401 挑战后切换）。
  ///
  /// 非线程安全：设计为单同步串行使用（同步引擎每次 run() 新建 store/客户端，
  /// run() 由 _running 串行化），无需并发保护。
  Auth _auth;

  /// 当前 [_auth] 所属的 origin（scheme://host[:port]）。
  ///
  /// 重定向到**其它主机**时不得转发凭据（防 Basic/Digest 泄露给第三方）；
  /// 目标主机自己 401 挑战后再按新 origin 协商。null = 尚未发起请求。
  String? _authOrigin;

  @override
  Future<File> readProps(String path) async {
    final resp = await _request(
      'PROPFIND',
      path,
      data: _kPropfindBody,
      options: Options(
        responseType: ResponseType.plain,
        headers: const {
          'depth': '1',
          'content-type': 'application/xml;charset=UTF-8',
          'accept': 'application/xml,text/xml',
          'accept-charset': 'utf-8',
        },
      ),
    );
    if (resp.statusCode != 207) {
      throw _statusError(resp);
    }
    return File(
      path: path,
      mTime: _parsePropfindModified('${resp.data ?? ''}'),
    );
  }

  @override
  Future<List<int>> read(String path) async {
    final resp = await _request(
      'GET',
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    if (resp.statusCode != 200) {
      throw _statusError(resp);
    }
    return resp.data as List<int>;
  }

  @override
  Future<void> write(String path, Uint8List data) async {
    var resp = await _request('PUT', path, data: data);
    if (_putOk(resp)) return;
    // 父目录缺失（坚果云不会自动建目录，PROPFIND/GET 也会因此返回 409）：
    // 递归创建父目录后重试一次。
    if (resp.statusCode == 409 || resp.statusCode == 404) {
      await _mkdirAllParent(path);
      resp = await _request('PUT', path, data: data);
      if (_putOk(resp)) return;
    }
    throw _statusError(resp);
  }

  /// PUT 成功状态码（WebDAV：200 覆盖 / 201 新建 / 204 无内容）。
  bool _putOk(Response resp) {
    final s = resp.statusCode;
    return s == 200 || s == 201 || s == 204;
  }

  /// 核心请求：拼 URL、预置认证头、401 挑战协商、3xx 重定向跟随。
  ///
  /// 状态码**不在此校验**（WebDAV 语义由各方法自行判断），非预期状态码
  /// 由各方法经 [_statusError] 抛 DioException(badResponse)，与 webdav_client
  /// 的 newResponseError 同构，保证 [WebDavRemoteStore] 的 404/409/401 分类
  /// 与既有测试不变。
  ///
  /// - 重定向最多跟随 [kMaxRedirects] 次（Location 可能是相对路径，用
  ///   `resolveUri` 解析）；**跨主机重定向不转发凭据**（防泄露，目标主机
  ///   自己 401 时再协商）；
  /// - 401 认证协商最多 [kMaxAuthAttempts] 次（Basic/Digest 升级、Digest
  ///   stale 续期）；凭据错误 → 最后一个 401 原样上抛（→ SyncAuthException）。
  Future<Response<dynamic>> _request(
    String method,
    String path, {
    dynamic data,
    Options? options,
  }) async {
    var uri = _resolve(path);
    // 首次请求即锁定认证归属 origin（预置 Basic 场景；NoAuth 时 authorize
    // 返回 null，无影响）。
    _authOrigin ??= _originOf(uri);
    var redirects = 0;
    var authAttempts = 0;
    while (true) {
      // 注意：必须构造**全新** Options（不能复用调用方传入的 options）——
      // 否则上一轮写入的 authorization 头会残留在共享对象上，被下一轮
      //（重定向/认证重试）复制出去（实测 bug：跨主机重定向仍带 Basic 头）。
      final opts = Options(
        method: method,
        headers: <String, dynamic>{...?(options?.headers)},
        responseType: options?.responseType,
      );
      // 仅当请求 origin 与认证归属一致才发送凭据（跨主机重定向不转发）。
      final authHeader = _originOf(uri) == _authOrigin
          ? _auth.authorize(method, Uri.parse(uri).path)
          : null;
      if (authHeader != null) {
        opts.headers!['authorization'] = authHeader;
      }

      final resp = await _dio.requestUri<dynamic>(
        Uri.parse(uri),
        options: opts,
        data: data,
      );
      final status = resp.statusCode;

      // 3xx 重定向：跟随 Location（相对/绝对均可）。达到上限则视为远端错误。
      if (status != null && status >= 300 && status < 400) {
        final location = resp.headers.value('location');
        if (location != null &&
            location.isNotEmpty &&
            redirects < _kMaxRedirects) {
          uri = Uri.parse(uri).resolveUri(Uri.parse(location)).toString();
          redirects++;
          continue;
        }
        throw _statusError(resp);
      }
      if (status != 401) return resp;

      // 401 → 认证协商（语义同 webdav_client req）：
      // - NoAuth → 按挑战切 Basic/Digest；
      // - 预置 Basic 但服务器要 Digest → 切 Digest；
      // - **挑战来自新 origin**（跨主机重定向后目标主机的 401）→ 按挑战类型
      //   对当前 origin 重新协商（旧 origin 的认证状态不适用于新主机，
      //   例如预置 Basic 被重定向目标以 Basic 挑战——否则会误判凭据错误）；
      // - Digest stale → 重建 DigestAuth 续期。
      // 重试超限或凭据错误 → 最后一个 401 上抛（→ SyncAuthException）。
      if (authAttempts >= _kMaxAuthAttempts) {
        throw _statusError(resp);
      }
      final w3a = resp.headers.value('www-authenticate');
      final lower = w3a?.toLowerCase();
      final challengeFromNewOrigin = _originOf(uri) != _authOrigin;
      final canUpgrade =
          challengeFromNewOrigin ||
          _auth.type == AuthType.NoAuth ||
          (_auth.type == AuthType.BasicAuth &&
              lower?.contains('digest') == true);
      if (canUpgrade) {
        if (lower?.contains('digest') == true) {
          _auth = DigestAuth(
            user: _username,
            pwd: _password,
            dParts: DigestParts(w3a),
          );
        } else if (lower?.contains('basic') == true) {
          _auth = BasicAuth(user: _username, pwd: _password);
        } else {
          throw _statusError(resp);
        }
      } else if (_auth.type == AuthType.DigestAuth &&
          lower?.contains('stale=true') == true) {
        _auth = DigestAuth(
          user: _username,
          pwd: _password,
          dParts: DigestParts(w3a),
        );
      } else {
        // 凭据错误或服务器拒绝该认证方式 → 401 原样上抛（→ SyncAuthException）。
        throw _statusError(resp);
      }
      // 认证归属锁定为当前请求 origin（跨主机 401 后按新 origin 协商）。
      _authOrigin = _originOf(uri);
      authAttempts++;
      // 带新认证头重试。
    }
  }

  /// 相对 key → 完整 URL；绝对 URL 原样返回（重定向目标）。
  String _resolve(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    // 显式去首尾 '/'（Dart String.trimLeft/trimRight 无参，勿用）。
    final base = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final rel = path.startsWith('/') ? path.substring(1) : path;
    return '$base/$rel';
  }

  /// URL 的 origin（scheme://host[:port]）；用于跨主机重定向不转发凭据。
  String _originOf(String uri) => Uri.parse(uri).origin;

  /// 创建相对 key 的父目录（先试完整父路径，409 才逐级 MKCOL）。
  ///
  /// - 405「已存在」视为成功（与 webdav_client mkdirAll 同语义）；
  /// - key 不含 `/`（如 `data.json.gz`）时无父级 → 直接返回（父目录即
  ///   baseUrl 目录，用户配置的同步文件夹必然存在）；
  /// - 先整段 MKCOL 省请求（坚果云 600 次/30 分钟限流），父级缺失（409）
  ///   才逐级从短到长创建。
  Future<void> _mkdirAllParent(String path) async {
    final parent = _parentOf(path);
    if (parent == null) return;

    var resp = await _request('MKCOL', '$parent/');
    if (resp.statusCode == 201 || resp.statusCode == 405) return;
    if (resp.statusCode != 409) throw _statusError(resp);

    // 409：父级缺失 → 逐级创建（a/ → a/b/ → …）。
    var current = '';
    for (final segment in parent.split('/')) {
      if (segment.isEmpty) continue;
      current = current.isEmpty ? segment : '$current/$segment';
      resp = await _request('MKCOL', '$current/');
      final s = resp.statusCode;
      if (s == 201 || s == 405) continue; // 201=创建 / 405=已存在。
      throw _statusError(resp);
    }
  }

  /// 相对 key 的父路径；无 `/` 时返回 null。
  String? _parentOf(String path) {
    final idx = path.lastIndexOf('/');
    if (idx <= 0) return null;
    return path.substring(0, idx);
  }

  /// 从 PROPFIND 207 响应 XML 中提取 `getlastmodified` 并解析为 UTC。
  ///
  /// 只关心 mTime（store.lastModified 用），忽略其余属性。解析失败返回
  /// null（调用方按「无修改时间」处理，与 webdav_client 的 str2LocalTime
  /// 语义一致，不阻塞同步）。
  DateTime? _parsePropfindModified(String xml) {
    final match = RegExp(
      r'<[^>]*getlastmodified[^>]*>([^<]*)</[^>]*>',
      caseSensitive: false,
    ).firstMatch(xml);
    if (match == null) return null;
    return _parseHttpDate(match.group(1)!.trim());
  }

  /// 解析 WebDAV `getlastmodified`（RFC 1123，如 `Thu, 13 Aug 2026 10:00:00 GMT`）。
  DateTime? _parseHttpDate(String value) {
    if (!value.toLowerCase().endsWith('gmt')) return null;
    final parts = value.split(' ');
    if (parts.length != 6) return null;
    final month = _kMonths[parts[2].toLowerCase()];
    if (month == null) return null;
    final dt = DateTime.tryParse(
      '${parts[3]}-$month-${parts[1].padLeft(2, '0')}T${parts[4]}Z',
    );
    // 已是 UTC（GMT）；toUtc() 归一保证接口契约（§3 时间一律 UTC 毫秒）。
    return dt?.toUtc();
  }

  /// 非预期 HTTP 状态码 → DioException(badResponse)（与 webdav_client 的
  /// newResponseError 同构，保证 [WebDavRemoteStore] 分类不变）。
  DioException _statusError(Response resp) {
    return DioException(
      requestOptions: resp.requestOptions,
      response: resp,
      type: DioExceptionType.badResponse,
      error: resp.statusMessage,
    );
  }
}

/// RFC 1123 月份缩写 → 数字（getlastmodified 解析用）。
const Map<String, String> _kMonths = {
  'jan': '01',
  'feb': '02',
  'mar': '03',
  'apr': '04',
  'may': '05',
  'jun': '06',
  'jul': '07',
  'aug': '08',
  'sep': '09',
  'oct': '10',
  'nov': '11',
  'dec': '12',
};

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
      // 契约：mTime 必须 UTC 归一（§3 时间一律 UTC 毫秒）。新适配器
      // （WebDavClientAdapter）解析 getlastmodified 时已直接产出 UTC；
      // 此处 toUtc() 幂等，但对注入的 Fake（可返回本地时区）保持防御性归一。
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
