import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/backup/backup_codec.dart';
import 'package:ordo/core/sync/snapshot.dart';
import 'package:ordo/core/sync/snapshot_codec.dart';

void main() {
  group('BackupCodec Tests', () {
    final sampleSnapshot = SnapshotData(
      schemaVersion: kSnapshotSchemaVersion,
      deviceId: 'test-device-uuid',
      exportedAt: 1720000000000,
      projects: [
        const ProjectRecord(
          id: 'proj-1',
          name: '工作清单',
          color: 0xFF1E88E5,
          sortOrder: 0,
          createdAt: 1720000000000,
          updatedAt: 1720000000000,
          deleted: false,
        ),
      ],
      tasks: [
        const TaskRecord(
          id: 'task-1',
          projectId: 'proj-1',
          title: '设计导入导出功能',
          sortOrder: 0,
          tagIds: ['tag-1'],
          createdAt: 1720000000000,
          updatedAt: 1720000000000,
          deleted: false,
        ),
      ],
      tags: [
        const TagRecord(
          id: 'tag-1',
          name: '高优',
          color: 0xFFE53935,
          sortOrder: 0,
          createdAt: 1720000000000,
          updatedAt: 1720000000000,
          deleted: false,
        ),
      ],
      folders: [
        const FolderRecord(
          id: 'folder-1',
          name: '个人事务',
          sortOrder: 0,
          createdAt: 1720000000000,
          updatedAt: 1720000000000,
          deleted: false,
        ),
      ],
      customViews: [
        const CustomViewRecord(
          id: 'view-1',
          name: '待办看板',
          panelsJson: '[]',
          layoutMode: 'kanban',
          createdAt: 1720000000000,
          updatedAt: 1720000000000,
          deleted: false,
        ),
      ],
    );

    test('正常编码为 .ordobak 二进制并正确解码还原', () {
      final bytes = encodeBackup(sampleSnapshot);

      // 验证二进制头
      expect(bytes.length, greaterThan(6));
      expect(
        bytes.sublist(0, 4),
        equals([0x4F, 0x52, 0x44, 0x4F]),
      ); // 'O','R','D','O'
      final byteData = ByteData.sublistView(bytes);
      expect(byteData.getUint16(4, Endian.big), equals(1)); // Version 1

      // 验证解码还原
      final restored = decodeBackup(bytes);
      expect(restored.schemaVersion, equals(sampleSnapshot.schemaVersion));
      expect(restored.deviceId, equals(sampleSnapshot.deviceId));
      expect(restored.exportedAt, equals(sampleSnapshot.exportedAt));
      expect(restored.projects.length, equals(1));
      expect(restored.projects.first.name, equals('工作清单'));
      expect(restored.tasks.length, equals(1));
      expect(restored.tasks.first.title, equals('设计导入导出功能'));
      expect(restored.tasks.first.tagIds, equals(['tag-1']));
      expect(restored.tags.length, equals(1));
      expect(restored.tags.first.name, equals('高优'));
      expect(restored.folders.length, equals(1));
      expect(restored.folders.first.name, equals('个人事务'));
      expect(restored.customViews.length, equals(1));
      expect(restored.customViews.first.name, equals('待办看板'));
    });

    test('文件长度小于 6 字节抛出 InvalidBackupMagicException', () {
      final shortBytes = Uint8List.fromList([0x4F, 0x52]);
      expect(
        () => decodeBackup(shortBytes),
        throwsA(isA<InvalidBackupMagicException>()),
      );
    });

    test('魔数头错误抛出 InvalidBackupMagicException', () {
      final badMagic = Uint8List.fromList([
        0x50, 0x4B, 0x03, 0x04, // ZIP magic
        0x00, 0x01,
        0x1F, 0x8B,
      ]);
      expect(
        () => decodeBackup(badMagic),
        throwsA(isA<InvalidBackupMagicException>()),
      );
    });

    test('不受支持的高版本格式抛出 UnsupportedBackupVersionException', () {
      final validEncoded = encodeBackup(sampleSnapshot);
      final manipulated = Uint8List.fromList(validEncoded);
      // 将版本篡改为 99
      ByteData.sublistView(manipulated).setUint16(4, 99, Endian.big);

      expect(
        () => decodeBackup(manipulated),
        throwsA(isA<UnsupportedBackupVersionException>()),
      );
    });

    test('格式版本为 0 抛出 UnsupportedBackupVersionException', () {
      final validEncoded = encodeBackup(sampleSnapshot);
      final manipulated = Uint8List.fromList(validEncoded);
      ByteData.sublistView(manipulated).setUint16(4, 0, Endian.big);

      expect(
        () => decodeBackup(manipulated),
        throwsA(isA<UnsupportedBackupVersionException>()),
      );
    });

    test('载荷被截断或损坏抛出异常', () {
      final validEncoded = encodeBackup(sampleSnapshot);
      // 仅截取前 10 字节（破坏 gzip 尾部）
      final truncated = validEncoded.sublist(0, 10);

      expect(() => decodeBackup(truncated), throwsA(anything));
    });

    test('非 gzip 载荷明文 JSON 在格式合法时亦可自愈容错', () {
      final jsonBytes = utf8.encode(jsonEncode(sampleSnapshot.toJson()));
      final buffer = Uint8List(6 + jsonBytes.length);
      buffer.setRange(0, 4, [0x4F, 0x52, 0x44, 0x4F]);
      ByteData.sublistView(buffer).setUint16(4, 1, Endian.big);
      buffer.setRange(6, buffer.length, jsonBytes);

      final restored = decodeBackup(buffer);
      expect(restored.tasks.first.title, equals('设计导入导出功能'));
    });
  });
}
