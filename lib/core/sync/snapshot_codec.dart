// 快照编解码 + gzip（docs/60-sync-design.md §3 / §12，docs/62-folder-nav.md §5.1）。
//
// - encodeSnapshot / decodeSnapshot 均为**顶层函数**，不捕获外层上下文，
//   可安全用于 Isolate.run / compute 做隔离解析（NFR-02，§9）。
// - gzip 使用 dart:io 内置 GZipCodec，不依赖任何第三方压缩库。
// - 字段级崩溃安全解析（缺失/越界回退）由 SnapshotData.fromJson 完成；
//   本文件负责结构级校验（gzip 损坏 / 非法 JSON / 根节点非对象 / schemaVersion）。
// - schemaVersion 支持区间 [kMinSupportedSnapshotSchemaVersion,
//   kSnapshotSchemaVersion]：v1 旧快照（无 folders/folderId 键，字段级兼容
//   读）与 v2 当前格式均接受；v0（含缺省回退 0）与未来版本拒绝。
//
// 上传优化 hash（§10.3）未在此实现：sha256 需依赖 package:crypto，而本项目
// 未直接依赖 crypto（仅传递依赖），禁止新增 pub 依赖；hash 由 sync_engine
// 层在后续里程碑实现（或引入 crypto 后补充）。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'snapshot.dart';

/// 当前快照 schema 版本（docs/60-sync-design.md §3 / docs/62-folder-nav.md §5.1 / docs/65-custom-views-and-panels.md §5.1）。
///
/// v2：新增 `folders` 记录列表 + `projects.folderId` 字段（文件夹归属）。
/// v3：新增 `customViews` 记录列表（自定义视图与多面板看板配置）。
const int kSnapshotSchemaVersion = 3;

/// 支持的最旧快照 schema 版本（docs/62-folder-nav.md §5.1「v1/v2 旧快照可兼容读」）。
///
/// v1 = 旧格式（无 folders/customViews 键 / 无 project.folderId 键）：`SnapshotData.fromJson`
/// 字段级崩溃安全回退（folders/customViews 空、folderId null），因此本版本可正常读入并
/// 参与合并；合并后本地重新导出恒为 [kSnapshotSchemaVersion]，无需额外迁移。
const int kMinSupportedSnapshotSchemaVersion = 1;

/// 快照 schema 版本不匹配异常（§5 / §12）：
/// 远端版本低于 [kMinSupportedSnapshotSchemaVersion]（如 v0/缺省）或高于
/// [kSnapshotSchemaVersion]（未来版本）→ 拒绝同步并提示升级应用
/// （不覆盖远端、不破坏本地）。
class SnapshotSchemaException implements Exception {
  const SnapshotSchemaException(
    this.actual, {
    this.expected = kSnapshotSchemaVersion,
  });

  /// 远端快照携带的 schemaVersion。
  final int actual;

  /// 本应用支持的最新 schemaVersion。
  final int expected;

  @override
  String toString() =>
      'SnapshotSchemaException: snapshot schemaVersion=$actual, '
      'this app supports schemaVersion=$expected '
      '(min=$kMinSupportedSnapshotSchemaVersion)';
}

/// 将 [SnapshotData] 编码为 gzip 压缩字节（供上传 / 远端存储）。
///
/// 顶层函数，无副作用，可在 isolate 中调用。
Uint8List encodeSnapshot(SnapshotData data) {
  final jsonBytes = utf8.encode(jsonEncode(data.toJson()));
  return GZipCodec().encode(jsonBytes) as Uint8List;
}

/// 从 gzip 压缩字节解码 [SnapshotData]。
///
/// 崩溃安全：
/// - 字段级（缺失/越界/类型异常）由 [SnapshotData.fromJson] 回退默认值
///   （v1 旧快照缺 folders/folderId 键即依赖此回退）；
/// - 结构级错误（gzip 损坏 / 非法 JSON / 根节点非对象）抛 [FormatException]
///   等，由 sync_engine 按 §12 处理（保留远端原文件，不覆盖）；
/// - schemaVersion 不在支持区间 [kMinSupportedSnapshotSchemaVersion,
///   kSnapshotSchemaVersion]（含缺省回退 0 与未来版本）时抛
///   [SnapshotSchemaException]。
///
/// 顶层函数，无副作用，可在 isolate 中调用。
SnapshotData decodeSnapshot(Uint8List bytes) {
  final jsonBytes = GZipCodec().decode(bytes);
  final decoded = jsonDecode(utf8.decode(jsonBytes));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Snapshot root must be a JSON object');
  }
  final data = SnapshotData.fromJson(decoded);
  if (data.schemaVersion < kMinSupportedSnapshotSchemaVersion ||
      data.schemaVersion > kSnapshotSchemaVersion) {
    throw SnapshotSchemaException(data.schemaVersion);
  }
  return data;
}
