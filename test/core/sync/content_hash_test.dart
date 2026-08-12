// FNV-1a 64 内容 hash 单元测试（docs/60-sync-design.md §10.3 上传优化）。
//
// 标准测试向量（与 remote_store_webdav_test.dart 的 contentHash 测试一致）：
// - 空内容 → `cbf29ce484222325`
// - 单字节 'a' → `af63dc4c8601ec8c`
// 额外：确定性、异内容不同 hash、长内容不崩溃。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/sync/content_hash.dart';

void main() {
  group('FNV-1a 64 标准向量', () {
    test('空内容 → cbf29ce484222325', () {
      expect(fnv1a64Hex(const []), 'cbf29ce484222325');
      expect(fnv1a64Hex(const <int>[]), 'cbf29ce484222325');
    });

    test("'a' → af63dc4c8601ec8c", () {
      expect(fnv1a64Hex(utf8.encode('a')), 'af63dc4c8601ec8c');
      expect(fnv1a64Hex(const [0x61]), 'af63dc4c8601ec8c');
    });
  });

  group('确定性与区分度', () {
    test('同内容 hash 稳定（确定性）', () {
      final a = List<int>.generate(256, (i) => i);
      expect(fnv1a64Hex(a), fnv1a64Hex(List<int>.of(a)));
    });

    test('不同内容 hash 不同', () {
      expect(
        fnv1a64Hex(utf8.encode('hello')),
        isNot(fnv1a64Hex(utf8.encode('hello!'))),
      );
      expect(fnv1a64Hex(const [1, 2, 3]), isNot(fnv1a64Hex(const [3, 2, 1])));
      // 仅单字节不同也必须不同。
      expect(
        fnv1a64Hex(const [0, 0, 0, 1]),
        isNot(fnv1a64Hex(const [0, 0, 0, 2])),
      );
    });

    test('长内容（10KB）可计算且稳定', () {
      final bytes = List<int>.generate(10240, (i) => (i * 31) % 256);
      final h1 = fnv1a64Hex(bytes);
      expect(h1, matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(fnv1a64Hex(bytes), h1);
    });

    test('输出恒为 16 位十六进制', () {
      for (final input in [
        <int>[],
        utf8.encode('todo'),
        List<int>.generate(1000, (i) => i % 7),
      ]) {
        expect(fnv1a64Hex(input), matches(RegExp(r'^[0-9a-f]{16}$')));
      }
    });
  });
}
