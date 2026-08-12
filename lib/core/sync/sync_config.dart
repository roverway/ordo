// 同步配置模型（docs/60-sync-design.md §10.1）。
//
// 不可变模型，按存储介质拆分：
// - 非敏感 6 项（type/enabled/autoOnStart/autoOnEdit/wifiOnly/lastSyncedAt）
//   存 settings 表（docs/40-data-model.md §2.5，key/value 均为 TEXT）；
// - 凭据 6 项（serverUrl/username/secret/bucket/region/prefix）只存
//   flutter_secure_storage（§13 安全约束，禁止进 settings JSON），
//   由 lib/core/security/secure_store.dart 负责读写。
//
// toMap/fromMap 仅序列化 settings 表字段：toMap() 的返回值**不含任何凭据**，
// 凭据字段不参与 settings 序列化（单测断言 map 无 serverUrl/secret 等 key）。

/// 远端类型（docs/60-sync-design.md §9）：WebDAV 或 S3 兼容桶，二选一启用。
enum RemoteType { webdav, s3 }

/// settings 表使用的同步 key（非敏感项，值均为字符串）。
///
/// 凭据 key 见 secure_store.dart（`sync_<type>_<field>`，走 secure storage）。
abstract final class SyncSettingsKeys {
  static const String type = 'sync_type';
  static const String enabled = 'sync_enabled';
  static const String autoOnStart = 'sync_auto_on_start';
  static const String autoOnEdit = 'sync_auto_on_edit';
  static const String wifiOnly = 'sync_wifi_only';
  static const String lastSyncedAt = 'sync_last_synced_at';

  /// 本设备同步设备 ID（UUID v4，首次同步时生成持久化，docs/60-sync-design.md §5）。
  static const String deviceId = 'sync_device_id';

  /// 墓碑集合（JSON 数组，docs/60-sync-design.md §8 / 40-data-model.md §7）。
  ///
  /// 条目格式 `{"type":"project"|"task"|"tag","id":"...","updatedAt":<UTC ms>}`，
  /// 由 lib/core/db/repositories/todo_repository.dart 维护（本地 DB 不保留
  /// 已删行，删除即物理硬删，墓碑持久化在 settings）；SyncEngine 导出快照时
  /// 并入（D1 决策）。常量值两处约定一致。
  static const String tombstones = 'sync_tombstones';
}

/// 同步配置（§10.1）。
///
/// 全字段不可变；字段说明：
/// - [serverUrl]：webdav 的 baseUrl（如 `https://dav.example.com/todo/`）
///   或 s3 的 endpoint（如 `https://<bucket>.r2.cloudflarestorage.com`）；
/// - [username]/[secret]：webdav 用户名/密码，s3 accessKey/secretKey；
/// - [bucket]/[region]/[prefix]：仅 s3；[region] 可为 null（由 s3_dart
///   探测），[prefix] 默认 `todo/`（§9.2）。
class SyncConfig {
  const SyncConfig({
    this.type = RemoteType.webdav,
    this.enabled = false,
    this.autoOnStart = false,
    this.autoOnEdit = false,
    this.wifiOnly = false,
    this.lastSyncedAt,
    this.serverUrl,
    this.username,
    this.secret,
    this.bucket,
    this.region,
    this.prefix,
  });

  /// 远端类型（settings 表）。
  final RemoteType type;

  /// 同步总开关（settings 表）。
  final bool enabled;

  /// 启动时自动同步（settings 表，FR-SYNC-02）。
  final bool autoOnStart;

  /// 编辑后防抖 2s 自动同步（settings 表，FR-SYNC-02）。
  final bool autoOnEdit;

  /// 仅 WiFi 时自动同步（settings 表，FR-SYNC-02/07；桌面恒真）。
  final bool wifiOnly;

  /// 上次成功同步时间（settings 表，UTC 毫秒）。
  final int? lastSyncedAt;

  /// webdav baseUrl / s3 endpoint（secure storage）。
  final String? serverUrl;

  /// webdav 用户名 / s3 accessKey（secure storage）。
  final String? username;

  /// webdav 密码 / s3 secretKey（secure storage）。
  final String? secret;

  /// s3 bucket，仅 s3（secure storage）。
  final String? bucket;

  /// s3 region，仅 s3（secure storage；可为 null，由客户端探测）。
  final String? region;

  /// s3 prefix，仅 s3（secure storage；默认 `todo/`）。
  final String? prefix;

  /// 复制并修改部分字段（全字段可选）。
  SyncConfig copyWith({
    RemoteType? type,
    bool? enabled,
    bool? autoOnStart,
    bool? autoOnEdit,
    bool? wifiOnly,
    int? lastSyncedAt,
    String? serverUrl,
    String? username,
    String? secret,
    String? bucket,
    String? region,
    String? prefix,
  }) {
    return SyncConfig(
      type: type ?? this.type,
      enabled: enabled ?? this.enabled,
      autoOnStart: autoOnStart ?? this.autoOnStart,
      autoOnEdit: autoOnEdit ?? this.autoOnEdit,
      wifiOnly: wifiOnly ?? this.wifiOnly,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      secret: secret ?? this.secret,
      bucket: bucket ?? this.bucket,
      region: region ?? this.region,
      prefix: prefix ?? this.prefix,
    );
  }

  /// 序列化为 settings 表 key/value（**仅非敏感 6 项**，§13）。
  ///
  /// - bool 存 `'1'`/`'0'`（与 DB 层 int 布尔一致）；
  /// - [lastSyncedAt] 为 null 时不输出该 key；
  /// - 凭据字段（serverUrl/username/secret/bucket/region/prefix）
  ///   **绝不**进入返回值。
  Map<String, String> toMap() {
    return <String, String>{
      SyncSettingsKeys.type: type.name,
      SyncSettingsKeys.enabled: enabled ? '1' : '0',
      SyncSettingsKeys.autoOnStart: autoOnStart ? '1' : '0',
      SyncSettingsKeys.autoOnEdit: autoOnEdit ? '1' : '0',
      SyncSettingsKeys.wifiOnly: wifiOnly ? '1' : '0',
      if (lastSyncedAt != null) SyncSettingsKeys.lastSyncedAt: '$lastSyncedAt',
    };
  }

  /// 从 settings 表 key/value 解析配置（仅非敏感项，§13）。
  ///
  /// 缺省/非法值回退默认：type→webdav、布尔→false、lastSyncedAt→null。
  /// 凭据字段保持 null（由 SecureStore.readCreds 另行填充）。
  factory SyncConfig.fromMap(Map<String, dynamic> map) {
    return SyncConfig(
      type: _readType(map),
      enabled: _readBool(map, SyncSettingsKeys.enabled),
      autoOnStart: _readBool(map, SyncSettingsKeys.autoOnStart),
      autoOnEdit: _readBool(map, SyncSettingsKeys.autoOnEdit),
      wifiOnly: _readBool(map, SyncSettingsKeys.wifiOnly),
      lastSyncedAt: _readNullableInt(map, SyncSettingsKeys.lastSyncedAt),
    );
  }

  /// 是否已配置可用凭据（serverUrl + 对应账号）。
  ///
  /// 供工厂/配置页判断能否构造 RemoteStore；webdav 仅需 serverUrl。
  bool get hasCredentials => serverUrl != null && serverUrl!.trim().isNotEmpty;
}

/// 解析 [SyncSettingsKeys.type]：仅接受 `webdav`/`s3`，其余回退 webdav。
RemoteType _readType(Map<String, dynamic> map) {
  final value = map[SyncSettingsKeys.type];
  if (value is String) {
    return RemoteType.values.asNameMap()[value] ?? RemoteType.webdav;
  }
  return RemoteType.webdav;
}

/// 容错解析布尔（'1'/'0'、'true'/'false'、int、bool；其余回退 false）。
bool _readBool(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final t = value.toLowerCase();
    if (t == '1' || t == 'true' || t == 'yes') return true;
    if (t == '0' || t == 'false' || t == 'no') return false;
  }
  return false;
}

/// 解析可空 int（lastSyncedAt）：非整数/缺失返回 null。
int? _readNullableInt(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
