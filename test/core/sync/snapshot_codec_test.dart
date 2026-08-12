// 快照编解码单元测试（docs/60-sync-design.md §3 / §12，纯函数层）。
//
// 覆盖：encode→decode 往返一致、gzip 压缩、schemaVersion 校验、损坏字节、
// 字段级崩溃安全解析（缺失/越界/类型异常回退默认值）。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo/core/sync/snapshot.dart';
import 'package:todo/core/sync/snapshot_codec.dart';

/// 构造一份覆盖所有字段形态的样本快照：
/// 中文/emoji/空字符串、null 字段（parentId/startAt）、deleted=true 墓碑、
/// 非空与空 tagIds。
SnapshotData _sampleSnapshot() {
  return SnapshotData(
    schemaVersion: 1,
    deviceId: 'device-uuid-1',
    exportedAt: 1720000000000,
    projects: [
      const ProjectRecord(
        id: 'project-1',
        name: '工作',
        color: 4283215696,
        description: '描述',
        sortOrder: 0,
        createdAt: 1720000000000,
        updatedAt: 1720000001000,
        deleted: false,
      ),
      const ProjectRecord(
        id: 'project-2',
        name: '已删除项目',
        color: 0,
        description: '',
        sortOrder: 1,
        createdAt: 1720000000000,
        updatedAt: 1720000002000,
        deleted: true, // 墓碑
      ),
    ],
    tasks: [
      const TaskRecord(
        id: 'task-1',
        projectId: 'project-1',
        title: '写周报 📝 中文标题',
        description: '描述…',
        notes: '备注',
        endAt: 1720500000000,
        status: 2,
        priority: 3,
        sortOrder: 0,
        createdAt: 1720000000000,
        updatedAt: 1720000003000,
        deleted: false,
        tagIds: ['tag-1', 'tag-2'],
      ),
      const TaskRecord(
        id: 'task-2',
        projectId: 'project-1',
        parentId: 'task-1',
        title: '子任务',
        startAt: 1720000000000,
        sortOrder: 1,
        createdAt: 1720000000000,
        updatedAt: 1720000004000,
        deleted: true, // 墓碑
      ),
    ],
    tags: [
      const TagRecord(
        id: 'tag-1',
        name: '重要 ⭐',
        color: 4283215696,
        sortOrder: 0,
        createdAt: 1720000000000,
        updatedAt: 1720000005000,
        deleted: false,
      ),
      const TagRecord(
        id: 'tag-2',
        name: '待归档',
        color: 0,
        sortOrder: 1,
        createdAt: 1720000000000,
        updatedAt: 1720000006000,
        deleted: true, // 墓碑
      ),
    ],
  );
}

/// 将 [json] 直接 gzip 编码为字节（用于构造「缺失字段/损坏」的原始快照）。
Uint8List _gzipJson(Object json) {
  return GZipCodec().encode(utf8.encode(jsonEncode(json))) as Uint8List;
}

void main() {
  group('snapshot_codec 往返', () {
    test('encode→decode 往返一致（tagIds/null 字段/墓碑/中文/emoji）', () {
      final snapshot = _sampleSnapshot();
      final decoded = decodeSnapshot(encodeSnapshot(snapshot));

      // 顶层与整棵 JSON 树逐字段一致。
      expect(decoded.schemaVersion, 1);
      expect(decoded.deviceId, 'device-uuid-1');
      expect(decoded.exportedAt, 1720000000000);
      expect(decoded.toJson(), equals(snapshot.toJson()));

      // 关键字段形态复核。
      final task1 = decoded.tasks.first;
      expect(task1.tagIds, ['tag-1', 'tag-2']);
      expect(task1.parentId, isNull);
      expect(task1.startAt, isNull);
      expect(task1.endAt, 1720500000000);
      expect(task1.deleted, isFalse);
      expect(task1.title, '写周报 📝 中文标题');

      final task2 = decoded.tasks[1];
      expect(task2.parentId, 'task-1');
      expect(task2.startAt, 1720000000000);
      expect(task2.endAt, isNull);
      expect(task2.tagIds, isEmpty);
      expect(task2.deleted, isTrue);

      expect(decoded.projects[1].deleted, isTrue);
      expect(decoded.tags[1].deleted, isTrue);
    });

    test('toJson → fromJson 直接往返（不经 gzip）', () {
      final snapshot = _sampleSnapshot();
      final parsed = SnapshotData.fromJson(snapshot.toJson());
      expect(parsed.toJson(), equals(snapshot.toJson()));
    });

    test('gzip 压缩后字节显著小于原文', () {
      final bigText = '这是一个可压缩的中文长文本段落 😀\n' * 2000;
      final snapshot = SnapshotData(
        schemaVersion: 1,
        deviceId: 'd',
        exportedAt: 1,
        projects: const [
          ProjectRecord(
            id: 'p1',
            name: 'P',
            color: 0,
            sortOrder: 0,
            createdAt: 1,
            updatedAt: 1,
            deleted: false,
          ),
        ],
        tasks: [
          TaskRecord(
            id: 't1',
            projectId: 'p1',
            title: 'T',
            notes: bigText,
            sortOrder: 0,
            createdAt: 1,
            updatedAt: 1,
            deleted: false,
          ),
        ],
      );

      final raw = utf8.encode(jsonEncode(snapshot.toJson()));
      final compressed = encodeSnapshot(snapshot);

      expect(
        compressed.length,
        lessThan(raw.length ~/ 2),
        reason: '重复文本 gzip 后应显著缩小',
      );
      // 大内容往返仍然一致。
      final decoded = decodeSnapshot(compressed);
      expect(decoded.toJson(), equals(snapshot.toJson()));
    });
  });

  group('snapshot_codec 校验', () {
    test('schemaVersion != 1 抛 SnapshotSchemaException', () {
      final json = _sampleSnapshot().toJson()..['schemaVersion'] = 2;
      final bytes = _gzipJson(json);

      try {
        decodeSnapshot(bytes);
        fail('应抛出 SnapshotSchemaException');
      } on SnapshotSchemaException catch (e) {
        expect(e.actual, 2);
        expect(e.expected, 1);
      }

      // 缺 schemaVersion 同样拒绝（fromJson 回退 0）。
      final noVersion = _sampleSnapshot().toJson()..remove('schemaVersion');
      expect(
        () => decodeSnapshot(_gzipJson(noVersion)),
        throwsA(isA<SnapshotSchemaException>()),
      );
    });

    test('损坏字节（乱码）抛异常不崩溃', () {
      final garbage = Uint8List.fromList(
        List.generate(64, (i) => (i * 7) % 256),
      );
      expect(() => decodeSnapshot(garbage), throwsA(anything));
    });

    test('gzip 合法但 JSON 非法 → FormatException', () {
      final badJson = _gzipJson('{{{ this is not json');
      expect(() => decodeSnapshot(badJson), throwsA(isA<FormatException>()));
    });

    test('根节点非 JSON 对象 → FormatException', () {
      final rootList = _gzipJson([
        {'id': 'x'},
      ]);
      expect(() => decodeSnapshot(rootList), throwsA(isA<FormatException>()));
    });
  });

  group('snapshot_codec 崩溃安全解析', () {
    test('缺失/异常字段回退默认值（status 越界、deleted 为 int、缺 tagIds）', () {
      final json = <String, dynamic>{
        'schemaVersion': 1,
        'deviceId': 'd',
        'exportedAt': 100,
        'projects': [
          {
            'id': 'p1',
            'name': 'P',
            'color': 1,
            'sortOrder': 0,
            'createdAt': 1,
            'updatedAt': 2,
            'deleted': 1, // int 而非 bool → true
          },
        ],
        'tasks': [
          {
            'id': 't1',
            'projectId': 'p1',
            'title': 'T',
            // 缺 description/notes/parentId/startAt/endAt/tagIds。
            'status': 99, // 越界 → 0
            'priority': -5, // 越界 → 0
            'sortOrder': 0,
            'createdAt': 1,
            'updatedAt': 2,
            'deleted': false,
            'unknownField': {'ignored': true}, // 未知字段忽略
          },
        ],
        'tags': [],
      };

      final snapshot = decodeSnapshot(_gzipJson(json));
      expect(snapshot.schemaVersion, 1);
      expect(snapshot.projects.single.deleted, isTrue);

      final task = snapshot.tasks.single;
      expect(task.status, 0);
      expect(task.priority, 0);
      expect(task.tagIds, isEmpty);
      expect(task.parentId, isNull);
      expect(task.startAt, isNull);
      expect(task.endAt, isNull);
      expect(task.description, '');
      expect(task.notes, '');
      expect(task.deleted, isFalse);
    });

    test('tagIds 非字符串元素被丢弃，deleted 非 0/1 值容错', () {
      final json = <String, dynamic>{
        'schemaVersion': 1,
        'deviceId': 'd',
        'exportedAt': 0,
        'projects': [
          {
            'id': 'p1',
            'name': null, // 缺失 → ''
            'sortOrder': 0,
            'createdAt': 1,
            'updatedAt': 2,
            'deleted': 'false', // 非 bool 非 num → false
          },
        ],
        'tasks': [
          {
            'id': 't1',
            'projectId': 'p1',
            'title': 'T',
            'tagIds': ['keep', 42, null, 'also'],
            'sortOrder': 0,
            'createdAt': 1,
            'updatedAt': 2,
            'deleted': false,
          },
        ],
        'tags': [],
      };

      final snapshot = decodeSnapshot(_gzipJson(json));
      expect(snapshot.projects.single.name, '');
      expect(snapshot.projects.single.deleted, isFalse);
      expect(snapshot.tasks.single.tagIds, ['keep', 'also']);
    });
  });
}
