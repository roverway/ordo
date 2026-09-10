import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../sync/snapshot.dart';
import '../sync/snapshot_codec.dart';

/// `.ordobak` 文件的 4 字节魔数（ASCII: "ORDO"）。
final Uint8List kBackupMagicBytes = Uint8List.fromList([
  0x4F,
  0x52,
  0x44,
  0x4F,
]); // O, R, D, O

/// 当前备份文件格式版本。
const int kBackupFormatVersion = 1;

/// 支持的最早备份格式版本。
const int kMinSupportedBackupFormatVersion = 1;

/// 魔数不匹配异常（文件损坏或非 `.ordobak` 文件）。
class InvalidBackupMagicException implements Exception {
  const InvalidBackupMagicException(this.actualMagic);
  final List<int> actualMagic;

  @override
  String toString() =>
      'InvalidBackupMagicException: 非法备份文件魔数头 '
      '${actualMagic.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}，'
      '预期为 4f 72 64 6f (ORDO)';
}

/// 备份文件格式版本不受支持异常。
class UnsupportedBackupVersionException implements Exception {
  const UnsupportedBackupVersionException(this.actualVersion);
  final int actualVersion;

  @override
  String toString() =>
      'UnsupportedBackupVersionException: 备份文件格式版本 v$actualVersion 不受支持，'
      '当前支持版本范围为 [v$kMinSupportedBackupFormatVersion, v$kBackupFormatVersion]';
}

/// 将 [SnapshotData] 编码为带有魔数与版本头的 `.ordobak` 二进制字节流。
///
/// 格式布局：
/// ```
/// 0..3:   Magic Header (4 bytes: 'O', 'R', 'D', 'O')
/// 4..5:   Format Version (2 bytes, Big-Endian uint16, 当前为 1)
/// 6..end: Gzip-compressed JSON payload (SnapshotData)
/// ```
Uint8List encodeBackup(SnapshotData data) {
  // 1. 将 SnapshotData 转为 gzip 压缩的 JSON 字节流
  final jsonStr = jsonEncode(data.toJson());
  final jsonBytes = utf8.encode(jsonStr);
  final compressed = GZipCodec().encode(jsonBytes);

  // 2. 组装二进制头
  final totalLength = 4 + 2 + compressed.length;
  final buffer = Uint8List(totalLength);
  final byteData = ByteData.sublistView(buffer);

  // 魔数: 'O','R','D','O'
  buffer.setRange(0, 4, kBackupMagicBytes);
  // 版本号: uint16 big endian
  byteData.setUint16(4, kBackupFormatVersion, Endian.big);
  // 数据载荷
  buffer.setRange(6, totalLength, compressed);

  return buffer;
}

/// 从 `.ordobak` 二进制字节流解码出 [SnapshotData]。
///
/// 校验步骤：
/// 1. 检查长度至少为 6 字节（4 字节魔数 + 2 字节版本号）；
/// 2. 严格核对魔数 `ORDO`，不匹配则抛出 [InvalidBackupMagicException]；
/// 3. 解析版本号，超出当前支持范围则抛出 [UnsupportedBackupVersionException]；
/// 4. 提取后续载荷，通过内置 GZipCodec 解压并交由 [SnapshotData.fromJson] 进行崩溃安全解析；
/// 5. 数据 Schema 版本的兼容性在载荷解压后交由现有 [decodeSnapshot] 或底层 Schema 规则验证。
SnapshotData decodeBackup(Uint8List bytes) {
  if (bytes.length < 6) {
    throw const InvalidBackupMagicException([]);
  }

  // 1. 魔数核对
  for (int i = 0; i < 4; i++) {
    if (bytes[i] != kBackupMagicBytes[i]) {
      throw InvalidBackupMagicException(bytes.sublist(0, 4));
    }
  }

  // 2. 格式版本核对
  final byteData = ByteData.sublistView(bytes);
  final version = byteData.getUint16(4, Endian.big);
  if (version < kMinSupportedBackupFormatVersion ||
      version > kBackupFormatVersion) {
    throw UnsupportedBackupVersionException(version);
  }

  // 3. 提取载荷并解码
  final payloadBytes = Uint8List.sublistView(bytes, 6);
  return decodeSnapshot(payloadBytes);
}


/// 方便调用统一编解码静态入口。
class BackupCodec {
  const BackupCodec._();
  static Uint8List encode(SnapshotData data) => encodeBackup(data);
  static SnapshotData decode(Uint8List bytes) => decodeBackup(bytes);
}
