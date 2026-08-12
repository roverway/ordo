// 内容 hash（docs/60-sync-design.md §10.3 上传优化）。
//
// FNV-1a 64 —— 与 WebDAV RemoteStore 内联实现（remote_store_webdav.dart）
// 完全一致的算法，作为「上传内容无变化则跳过」的变化判定，**非密码学用途**。
// 顶层函数，无副作用，可安全用于 isolate（NFR-02）。
//
// 标准测试向量（与 remote_store_webdav_test.dart 一致）：
// - 空内容 → `cbf29ce484222325`
// - 单字节 `'a'`(0x61) → `af63dc4c8601ec8c`

import 'dart:typed_data';

/// FNV-1a 64 哈希的十六进制小写字符串（16 位）。
///
/// 确定性：同内容必同 hash；不同内容大概率不同（非密码学保证）。
String fnv1a64Hex(List<int> bytes) {
  const int offsetBasis = 0xcbf29ce484222325;
  const int prime = 0x100000001b3;
  const int mask64 = 0xffffffffffffffff;
  var hash = offsetBasis;
  for (final b in bytes) {
    hash ^= b;
    // Dart VM int 为 64 位有符号、溢出按模 2^64 回绕；掩码保证后续
    // setUint64 写出低 64 位原文（与 remote_store_webdav.dart 同款写法）。
    hash = (hash * prime) & mask64;
  }
  final bd = ByteData(8)..setUint64(0, hash);
  final sb = StringBuffer();
  for (var i = 0; i < 8; i++) {
    sb.write(bd.getUint8(i).toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}
