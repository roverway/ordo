// 快照编解码单元测试（docs/60-sync-design.md §3 / §12，纯函数层）。
//
// 覆盖：encode→decode 往返一致、gzip 压缩、schemaVersion 校验、损坏字节、
// 字段级崩溃安全解析（缺失/越界/类型异常回退默认值）、
// v2 新字段（folders + project.folderId）编解码、v1 旧快照字段兼容读。

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/sync/snapshot.dart';
import 'package:ordo/core/sync/snapshot_codec.dart';

/// 构造一份覆盖所有字段形态的样本快照：
/// 中文/emoji/空字符串、null 字段（parentId/startAt/folderId）、
/// deleted=true 墓碑、非空与空 tagIds、folders 列表。
SnapshotData _sampleSnapshot() {
  return SnapshotData(
    schemaVersion: 3,
    deviceId: 'device-uuid-1',
    exportedAt: 1720000000000,
    projects: [
      const ProjectRecord(
        id: 'project-1',
        name: '工作',
        color: 4283215696,
        description: '描述',
        folderId: 'folder-1',
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
        status: 0,
        priority: 0,
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
    folders: [
      const FolderRecord(
        id: 'folder-1',
        name: '工作文件夹',
        sortOrder: 0,
        createdAt: 1720000000000,
        updatedAt: 1720000007000,
        deleted: false,
      ),
      const FolderRecord(
        id: 'folder-2',
        name: '已删除文件夹',
        sortOrder: 1,
        createdAt: 1720000000000,
        updatedAt: 1720000008000,
        deleted: true, // 墓碑
      ),
    ],
    customViews: [
      const CustomViewRecord(
        id: 'view-1',
        name: '自定义看板',
        icon: 'dashboard',
        color: 0xFF123456,
        sortOrder: 0,
        layoutMode: 'kanban',
        panelsJson: '[{"id":"p1","title":"待办"}]',
        createdAt: 1720000000000,
        updatedAt: 1720000009000,
        deleted: false,
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
      expect(decoded.schemaVersion, 3);
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

      // v2 新字段：folders 列表 + project.folderId 往返一致。
      expect(decoded.projects.first.folderId, 'folder-1');
      expect(decoded.projects[1].folderId, isNull);
      expect(decoded.folders.map((f) => f.id), ['folder-1', 'folder-2']);
      expect(decoded.folders.first.name, '工作文件夹');
      expect(decoded.folders.first.sortOrder, 0);
      expect(decoded.folders[1].deleted, isTrue);
    });

    test('toJson → fromJson 直接往返（不经 gzip）', () {
      final snapshot = _sampleSnapshot();
      final parsed = SnapshotData.fromJson(snapshot.toJson());
      expect(parsed.toJson(), equals(snapshot.toJson()));
    });

    test('gzip 压缩后字节显著小于原文', () {
      final bigText = '这是一个可压缩的中文长文本段落 😀\n' * 2000;
      final snapshot = SnapshotData(
        schemaVersion: 2,
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

    test('decodeSnapshot 支持直接解码未压缩的明文 JSON 字节（网络层自动解压场景）', () {
      final snapshot = _sampleSnapshot();
      final plainJsonBytes = Uint8List.fromList(
        utf8.encode(jsonEncode(snapshot.toJson())),
      );
      final decoded = decodeSnapshot(plainJsonBytes);
      expect(decoded.toJson(), equals(snapshot.toJson()));
    });
  });

  group('snapshot_codec 校验', () {
    test('schemaVersion=1（v1 旧快照）可正常 decode：结构级兼容读', () {
      // v1 真实快照形态：schemaVersion=1、无 folders 键、project 记录无
      // folderId 键（docs/62-folder-nav.md §5.1「v1 旧快照可兼容读」）。
      final v1Json = <String, dynamic>{
        'schemaVersion': 1,
        'deviceId': 'old-device',
        'exportedAt': 1720000000000,
        'projects': [
          {
            'id': 'p1',
            'name': '旧项目',
            'color': 0,
            'sortOrder': 0,
            'createdAt': 1,
            'updatedAt': 2,
            'deleted': false,
          },
        ],
        'tasks': [],
        'tags': [],
        // 无 'folders' 键。
      };

      final decoded = decodeSnapshot(_gzipJson(v1Json));
      expect(decoded.schemaVersion, 1);
      expect(decoded.folders, isEmpty, reason: 'v1 无 folders 键 → 空列表');
      expect(
        decoded.projects.single.folderId,
        isNull,
        reason: 'v1 project 无 folderId 键 → null',
      );
      expect(decoded.tasks, isEmpty);
      expect(decoded.tags, isEmpty);
    });

    test('schemaVersion=99（未来版本）抛 SnapshotSchemaException', () {
      final json = _sampleSnapshot().toJson()..['schemaVersion'] = 99;
      final bytes = _gzipJson(json);

      try {
        decodeSnapshot(bytes);
        fail('应抛出 SnapshotSchemaException');
      } on SnapshotSchemaException catch (e) {
        expect(e.actual, 99);
        expect(e.expected, kSnapshotSchemaVersion);
        expect(e.toString(), contains('supports'), reason: '异常信息描述支持版本');
      }
    });

    test('schemaVersion=0（缺省回退 0，v0/损坏）抛 SnapshotSchemaException', () {
      final json = _sampleSnapshot().toJson()..['schemaVersion'] = 0;
      expect(
        () => decodeSnapshot(_gzipJson(json)),
        throwsA(isA<SnapshotSchemaException>()),
      );

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
        'schemaVersion': 2,
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
        'folders': [],
      };

      final snapshot = decodeSnapshot(_gzipJson(json));
      expect(snapshot.schemaVersion, 2);
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
        'schemaVersion': 2,
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

  group('v2 新字段（folders + project.folderId）', () {
    test('businessToJson 含 folders（上传 hash 必须覆盖新字段）', () {
      final json = _sampleSnapshot().businessToJson();
      expect(
        json.containsKey('folders'),
        isTrue,
        reason: '上传 hash 必须含 folders',
      );
      final folders = json['folders'] as List;
      expect(folders.length, 2);
      expect(folders.first, containsPair('id', 'folder-1'));
      expect(folders.first, containsPair('name', '工作文件夹'));
    });

    test('project.folderId 非字符串/异常类型 → null（崩溃安全）', () {
      final json = <String, dynamic>{
        'schemaVersion': 2,
        'deviceId': 'd',
        'exportedAt': 0,
        'projects': [
          {
            'id': 'p1',
            'name': 'P',
            'folderId': 42, // 非字符串 → null
            'sortOrder': 0,
            'createdAt': 1,
            'updatedAt': 2,
            'deleted': false,
          },
          {
            'id': 'p2',
            'name': 'Q',
            'folderId': {'nested': true}, // 非字符串 → null
            'sortOrder': 1,
            'createdAt': 1,
            'updatedAt': 3,
            'deleted': false,
          },
        ],
        'tasks': [],
        'tags': [],
        'folders': [],
      };

      final snapshot = decodeSnapshot(_gzipJson(json));
      expect(snapshot.projects[0].folderId, isNull);
      expect(snapshot.projects[1].folderId, isNull);
    });

    test('folders 崩溃安全：缺失字段/非对象元素被跳过或回退默认值', () {
      final json = <String, dynamic>{
        'schemaVersion': 2,
        'deviceId': 'd',
        'exportedAt': 0,
        'projects': [],
        'tasks': [],
        'tags': [],
        'folders': [
          {
            'id': 'f1',
            // 缺 name/sortOrder/createdAt/updatedAt/deleted。
            'deleted': 1, // int → true
          },
          'not-a-map', // 非对象元素丢弃
          null,
          {
            'id': 'f2',
            'name': 'F2',
            'sortOrder': 1,
            'createdAt': 10,
            'updatedAt': 20,
            'deleted': false,
          },
        ],
      };

      final snapshot = decodeSnapshot(_gzipJson(json));
      expect(snapshot.folders.map((f) => f.id), ['f1', 'f2']);
      expect(snapshot.folders[0].name, '');
      expect(snapshot.folders[0].sortOrder, 0);
      expect(snapshot.folders[0].deleted, isTrue);
      expect(snapshot.folders[1].name, 'F2');
      expect(snapshot.folders[1].deleted, isFalse);
    });

    test('folders 键非 List（缺失/异常类型）→ 空列表', () {
      final json = _sampleSnapshot().toJson()
        ..remove('folders')
        ..['folders'] = 'garbage'; // 非 List → 空
      final snapshot = decodeSnapshot(_gzipJson(json));
      expect(snapshot.folders, isEmpty);
    });
  });

  group('v1 旧快照兼容读（schemaVersion=1，无 folders 键 / 无 folderId 键）', () {
    test('v1 真实快照完整 decode 往返：结构级接受 + 字段级回退 + 重序列化一致', () {
      // v1 真实快照形态：schemaVersion=1、无 folders 键、project 记录无 folderId 键。
      final v1Json = <String, dynamic>{
        'schemaVersion': 1,
        'deviceId': 'old-device',
        'exportedAt': 1720000000000,
        'projects': [
          {
            'id': 'p1',
            'name': '旧项目',
            'color': 0,
            'sortOrder': 0,
            'createdAt': 1,
            'updatedAt': 2,
            'deleted': false,
          },
        ],
        'tasks': [],
        'tags': [],
        // 无 'folders' 键（v1 无此字段）。
      };

      // 结构级：schemaVersion=1 在支持区间内，decodeSnapshot 不得拒绝。
      final decoded = decodeSnapshot(_gzipJson(v1Json));
      expect(decoded.schemaVersion, 1);
      expect(decoded.folders, isEmpty, reason: 'v1 无 folders 键 → 空列表');
      expect(
        decoded.projects.single.folderId,
        isNull,
        reason: 'v1 project 无 folderId 键 → null',
      );
      // 字段级（fromJson 直接解析）结果一致。
      final parsed = SnapshotData.fromJson(v1Json);
      expect(parsed.folders, isEmpty);
      expect(parsed.projects.single.folderId, isNull);

      // 重序列化：decode → encode → decode 往返稳定，且补齐 folders 键（空数组）。
      final reEncoded = encodeSnapshot(decoded);
      final reDecoded = decodeSnapshot(reEncoded);
      expect(reDecoded.schemaVersion, 1, reason: '重导出保持 v1 schemaVersion');
      expect(reDecoded.folders, isEmpty);
      expect(
        reDecoded.toJson().containsKey('folders'),
        isTrue,
        reason: '重序列化补齐 folders 键（空数组）',
      );
    });

    test('decodeSnapshot 接受无 folders/folderId 键的 v2 快照（兼容 v1 数据形态）', () {
      // schemaVersion=2 但内容为 v1 数据形态（无新字段键）→ 不崩溃，回退默认值。
      final json = <String, dynamic>{
        'schemaVersion': 2,
        'deviceId': 'd',
        'exportedAt': 0,
        'projects': [
          {
            'id': 'p1',
            'name': 'P',
            'color': 0,
            'sortOrder': 0,
            'createdAt': 1,
            'updatedAt': 2,
            'deleted': false,
          },
        ],
        'tasks': [],
        'tags': [],
      };

      final snapshot = decodeSnapshot(_gzipJson(json));
      expect(snapshot.folders, isEmpty);
      expect(snapshot.projects.single.folderId, isNull);
      expect(snapshot.customViews, isEmpty);
    });

    test('decodeSnapshot 接受包含 customViews 的 v3 快照', () {
      final json = <String, dynamic>{
        'schemaVersion': 3,
        'deviceId': 'd',
        'exportedAt': 0,
        'projects': [],
        'tasks': [],
        'tags': [],
        'folders': [],
        'customViews': [
          {
            'id': 'cv-1',
            'name': '看板视图',
            'icon': 'view_kanban',
            'color': 4283215696,
            'sortOrder': 0,
            'layoutMode': 'kanban',
            'panelsJson': '[{"id":"p1","title":"待办"}]',
            'createdAt': 1000,
            'updatedAt': 2000,
            'deleted': false,
          },
        ],
      };

      final snapshot = decodeSnapshot(_gzipJson(json));
      expect(snapshot.customViews.length, 1);
      final cv = snapshot.customViews.first;
      expect(cv.id, 'cv-1');
      expect(cv.name, '看板视图');
      expect(cv.icon, 'view_kanban');
      expect(cv.layoutMode, 'kanban');
      expect(cv.panelsJson, '[{"id":"p1","title":"待办"}]');
    });
  });
}
