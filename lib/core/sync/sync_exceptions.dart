// 同步领域异常（docs/60-sync-design.md §12 错误处理 / NFR-03）。
//
// sync_engine 依据异常类型决定策略：
// - SyncNetworkException：网络失败/超时 → 指数退避重试（最多 5 次）；
// - SyncAuthException：认证失败 → 提示检查凭据，不重试；
// - SyncRemoteException：远端其他 HTTP 错误 → 展示错误，可重试；
// - SyncConfigException：本地配置无效 → 提示修正配置。
//
// §13 安全约束：异常消息**禁止包含密钥或完整 URL**（可含 host）。
// 消息**仅供日志/调试**（可含中文或底层摘要），UI 层**不得直接展示**；
// sync_engine 按异常类型设置 SyncErrorCode（sync_engine.dart），UI 据此
// 映射 ARB 文案（i18n 合规，AGENTS.md §3-8）。

/// 网络失败/超时（§12 第一行）：连接错误 / 连接超时 / 发送超时 / 接收超时。
///
/// sync_engine 应对此类异常做指数退避重试（最多 5 次），不破坏本地库。
class SyncNetworkException implements Exception {
  const SyncNetworkException(this.message, {this.cause});

  /// 调试消息（**仅日志用，UI 不得直接展示**；不包含密钥/完整 URL）。
  final String message;

  /// 底层异常（DioException 等），仅用于日志调试，不展示给用户。
  final Object? cause;

  @override
  String toString() => 'SyncNetworkException: $message';
}

/// 认证失败（§12 第二行）：远端返回 401，凭据错误。
///
/// sync_engine 应提示用户检查凭据，**不重试**。
class SyncAuthException implements Exception {
  const SyncAuthException(this.message, {this.cause});

  /// 调试消息（**仅日志用，UI 不得直接展示**）。
  final String message;

  /// 底层异常（DioException 等）。
  final Object? cause;

  @override
  String toString() => 'SyncAuthException: $message';
}

/// 远端其他 HTTP 错误（§12 其余行）：非 404 / 非认证 / 非网络错误。
///
/// 404 是「对象不存在」的**正常状态**（exists=false / download=null），
/// 由 RemoteStore 内部吞掉，不抛异常；其余 4xx/5xx 归此类。
class SyncRemoteException implements Exception {
  const SyncRemoteException(this.message, {this.cause});

  /// 调试消息（**仅日志用，UI 不得直接展示**）。
  final String message;

  final Object? cause;

  @override
  String toString() => 'SyncRemoteException: $message';
}

/// 同步配置无效（docs/60-sync-design.md §9.3 工厂）。
///
/// 例如 webdav 类型缺 serverUrl、凭据未配置。由同步配置页提示修正，
/// 不属于重试性错误。
class SyncConfigException implements Exception {
  const SyncConfigException(this.message, {this.cause});

  /// 调试消息（**仅日志用，UI 不得直接展示**）。
  final String message;

  final Object? cause;

  @override
  String toString() => 'SyncConfigException: $message';
}
