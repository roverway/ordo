// 合并引擎单元测试（docs/60-sync-design.md §4 / §7 / §14，docs/62-folder-nav.md
// §5.2，纯函数层）。
//
// 覆盖 §14 场景 1–4、8（合并函数层面）+ §4 边界：
// 1 本地新增 / 2 远端新增 / 3 两端改同一 id（updatedAt + tie-break）/
// 4 一端删除（墓碑传播）/ 8 标签删除后悬空引用清理。
// 额外：文件夹 LWW 合并、reconcileFolderIds 悬空文件夹引用清理、
// 跨类型不互相影响、空快照合并、同 updatedAt 确定性、纯函数不改入参。

import 'package:flutter_test/flutter_test.dart';
import 'package:ordo/core/sync/merge_engine.dart';
import 'package:ordo/core/sync/snapshot.dart';

ProjectRecord _project({
  required String id,
  String name = 'P',
  int color = 0,
  String description = '',
  String? folderId,
  int sortOrder = 0,
  int createdAt = 1,
  int updatedAt = 1,
  bool deleted = false,
}) {
  return ProjectRecord(
    id: id,
    name: name,
    color: color,
    description: description,
    folderId: folderId,
    sortOrder: sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted,
  );
}

TaskRecord _task({
  required String id,
  required String projectId,
  String? parentId,
  String title = 'T',
  String description = '',
  String notes = '',
  int? startAt,
  int? endAt,
  int status = 0,
  int priority = 0,
  int sortOrder = 0,
  int createdAt = 1,
  int updatedAt = 1,
  bool deleted = false,
  List<String> tagIds = const [],
}) {
  return TaskRecord(
    id: id,
    projectId: projectId,
    parentId: parentId,
    title: title,
    description: description,
    notes: notes,
    startAt: startAt,
    endAt: endAt,
    status: status,
    priority: priority,
    sortOrder: sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted,
    tagIds: tagIds,
  );
}

TagRecord _tag({
  required String id,
  String name = 'TAG',
  int color = 0,
  int sortOrder = 0,
  int createdAt = 1,
  int updatedAt = 1,
  bool deleted = false,
}) {
  return TagRecord(
    id: id,
    name: name,
    color: color,
    sortOrder: sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted,
  );
}

FolderRecord _folder({
  required String id,
  String name = 'FOLDER',
  int sortOrder = 0,
  int createdAt = 1,
  int updatedAt = 1,
  bool deleted = false,
}) {
  return FolderRecord(
    id: id,
    name: name,
    sortOrder: sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted,
  );
}

CustomViewRecord _customView({
  required String id,
  String name = 'VIEW',
  String icon = 'dashboard',
  int color = 0xFF123456,
  int sortOrder = 0,
  String layoutMode = 'kanban',
  String panelsJson = '[]',
  int createdAt = 1,
  int updatedAt = 1,
  bool deleted = false,
}) {
  return CustomViewRecord(
    id: id,
    name: name,
    icon: icon,
    color: color,
    sortOrder: sortOrder,
    layoutMode: layoutMode,
    panelsJson: panelsJson,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted,
  );
}

SnapshotData _snapshot({
  int schemaVersion = 1,
  String deviceId = 'local-device',
  int exportedAt = 100,
  List<ProjectRecord> projects = const [],
  List<TaskRecord> tasks = const [],
  List<TagRecord> tags = const [],
  List<FolderRecord> folders = const [],
  List<CustomViewRecord> customViews = const [],
}) {
  return SnapshotData(
    schemaVersion: schemaVersion,
    deviceId: deviceId,
    exportedAt: exportedAt,
    projects: projects,
    tasks: tasks,
    tags: tags,
    folders: folders,
    customViews: customViews,
  );
}

void main() {
  group('§14 场景 1/2：单侧新增', () {
    test('场景 1：本地新增 → 合并结果含新记录（远端为空）', () {
      final local = _snapshot(
        projects: [_project(id: 'p1', name: '本地项目', updatedAt: 100)],
        tasks: [_task(id: 't1', projectId: 'p1', updatedAt: 100)],
        tags: [_tag(id: 'tag1', updatedAt: 100)],
      );
      final remote = _snapshot();

      final result = merge(
        local,
        remote,
        localDeviceId: 'dev-a',
        remoteDeviceId: 'dev-b',
      );

      expect(result.projects.map((p) => p.id), ['p1']);
      expect(result.projects.single.name, '本地项目');
      expect(result.tasks.map((t) => t.id), ['t1']);
      expect(result.tags.map((t) => t.id), ['tag1']);
    });

    test('场景 2：远端新增 → 合并结果含远端记录（本地为空）', () {
      final local = _snapshot();
      final remote = _snapshot(
        tasks: [
          _task(id: 't1', projectId: 'p1', title: '远端任务', updatedAt: 200),
        ],
        tags: [_tag(id: 'tag1', updatedAt: 200)],
      );

      final result = merge(
        local,
        remote,
        localDeviceId: 'dev-a',
        remoteDeviceId: 'dev-b',
      );

      expect(result.tasks.map((t) => t.id), ['t1']);
      expect(result.tasks.single.title, '远端任务');
      expect(result.tags.map((t) => t.id), ['tag1']);
    });
  });

  group('§14 场景 3：两端改同一 id', () {
    test('取 updatedAt 大者（与来源设备无关）', () {
      // 远端更新更晚 → 远端胜。
      final local = _snapshot(
        projects: [_project(id: 'p1', name: '旧', updatedAt: 100)],
      );
      final remote = _snapshot(
        projects: [_project(id: 'p1', name: '新', updatedAt: 200)],
      );
      final r1 = merge(local, remote, localDeviceId: 'a', remoteDeviceId: 'b');
      expect(r1.projects.single.name, '新');
      expect(r1.projects.single.updatedAt, 200);

      // 与谁在「第一个参数」无关：LWW 只看 updatedAt，结果不变。
      final r2 = merge(remote, local, localDeviceId: 'a', remoteDeviceId: 'b');
      expect(r2.projects.single.name, '新');
      expect(r2.projects.single.updatedAt, 200);
    });

    test('updatedAt 相等 → tie-break 字典序，两端算出相同 winner', () {
      // deviceId 'aaa'（本地）< 'bbb'（远端）→ 字典序大者 'bbb' 胜。
      final local = _snapshot(
        deviceId: 'aaa',
        projects: [_project(id: 'p1', name: '来自aaa', updatedAt: 100)],
      );
      final remote = _snapshot(
        deviceId: 'bbb',
        projects: [_project(id: 'p1', name: '来自bbb', updatedAt: 100)],
      );

      // 设备 A 视角：local='aaa'，remote='bbb'。
      final fromA = merge(
        local,
        remote,
        localDeviceId: 'aaa',
        remoteDeviceId: 'bbb',
      );
      // 设备 B 视角：参数对偶（swap 两端 deviceId）。
      final fromB = merge(
        remote,
        local,
        localDeviceId: 'bbb',
        remoteDeviceId: 'aaa',
      );

      expect(fromA.projects.single.name, '来自bbb');
      expect(fromB.projects.single.name, '来自bbb', reason: '两端必须算出相同 winner');

      // 重复调用稳定（确定性）。
      final again = merge(
        local,
        remote,
        localDeviceId: 'aaa',
        remoteDeviceId: 'bbb',
      );
      expect(again.projects.single.name, '来自bbb');
    });

    test('同 id 不同内容、updatedAt 相同时结果确定（不可交换方向后翻转）', () {
      final local = _snapshot(
        deviceId: 'device-x',
        tasks: [_task(id: 't1', projectId: 'p1', title: '内容X', updatedAt: 42)],
      );
      final remote = _snapshot(
        deviceId: 'device-y',
        tasks: [_task(id: 't1', projectId: 'p1', title: '内容Y', updatedAt: 42)],
      );

      final ab = merge(
        local,
        remote,
        localDeviceId: 'device-x',
        remoteDeviceId: 'device-y',
      );
      final ba = merge(
        remote,
        local,
        localDeviceId: 'device-y',
        remoteDeviceId: 'device-x',
      );

      expect(
        ab.tasks.single.title,
        ba.tasks.single.title,
        reason: '同一对设备两端合并结果必须相同',
      );
      // 合并出的记录内容两端完全一致（结果快照的 deviceId 元信息按设计保留
      // 本地值，因此只比对记录本身）。
      expect(
        ab.tasks.single.toJson(),
        equals(ba.tasks.single.toJson()),
        reason: '两端合并出的记录内容一致（确定性合并）',
      );
    });
  });

  group('§14 场景 4：一端删除（墓碑）', () {
    test('墓碑 updatedAt 新 → 墓碑胜，deleted=true 传播', () {
      final local = _snapshot(
        tasks: [
          _task(id: 't1', projectId: 'p1', deleted: true, updatedAt: 500),
        ],
      );
      final remote = _snapshot(
        tasks: [_task(id: 't1', projectId: 'p1', title: '旧任务', updatedAt: 100)],
      );

      final result = merge(
        local,
        remote,
        localDeviceId: 'a',
        remoteDeviceId: 'b',
      );
      expect(result.tasks.single.deleted, isTrue);
      expect(result.tasks.single.updatedAt, 500);
    });

    test('墓碑更旧、另一端修改更新 → 修改胜，墓碑被覆盖（LWW 反向边界）', () {
      final local = _snapshot(
        tasks: [
          _task(id: 't1', projectId: 'p1', deleted: true, updatedAt: 100),
        ],
      );
      final remote = _snapshot(
        tasks: [_task(id: 't1', projectId: 'p1', title: '新修改', updatedAt: 500)],
      );

      final result = merge(
        local,
        remote,
        localDeviceId: 'a',
        remoteDeviceId: 'b',
      );
      expect(result.tasks.single.deleted, isFalse);
      expect(result.tasks.single.title, '新修改');
    });
  });

  group('§14 场景 8：标签删除后合并 → 悬空引用清理', () {
    test('tagIds 指向 deleted 标签或不存在标签 → 合并后被清理', () {
      final local = _snapshot(
        tasks: [
          _task(
            id: 't1',
            projectId: 'p1',
            tagIds: ['tag-live', 'tag-deleted', 'tag-missing'],
            updatedAt: 100,
          ),
        ],
        tags: [
          _tag(id: 'tag-live', updatedAt: 100),
          _tag(id: 'tag-deleted', deleted: true, updatedAt: 200), // 墓碑
        ],
      );
      final remote = _snapshot();

      final result = merge(
        local,
        remote,
        localDeviceId: 'a',
        remoteDeviceId: 'b',
      );
      expect(result.tasks.single.tagIds, ['tag-live']);
    });

    test('墓碑标签来自远端、任务来自本地 → 清理同样生效', () {
      final local = _snapshot(
        tasks: [
          _task(id: 't1', projectId: 'p1', tagIds: ['tag1'], updatedAt: 100),
        ],
      );
      final remote = _snapshot(
        tags: [_tag(id: 'tag1', deleted: true, updatedAt: 300)], // 远端墓碑
      );

      final result = merge(
        local,
        remote,
        localDeviceId: 'a',
        remoteDeviceId: 'b',
      );
      expect(result.tasks.single.tagIds, isEmpty);
      // 标签墓碑本身保留。
      expect(result.tags.single.deleted, isTrue);
    });

    test('reconcileTagIds 纯函数：返回新对象、不修改入参', () {
      final task = _task(id: 't1', projectId: 'p1', tagIds: ['a', 'b', 'c']);
      final merged = _snapshot(
        tasks: [task],
        tags: [_tag(id: 'a')],
      );

      final result = reconcileTagIds(merged);

      expect(result.tasks.single.tagIds, ['a']);
      expect(
        identical(result.tasks.single, task),
        isFalse,
        reason: '清理后必须返回新 TaskRecord',
      );
      expect(task.tagIds, ['a', 'b', 'c'], reason: '入参不得被修改');
      expect(identical(result, merged), isFalse);

      // 无悬空引用时复用原对象（无谓拷贝应避免）。
      final clean = _snapshot(
        tasks: [
          _task(id: 't2', projectId: 'p1', tagIds: ['a']),
        ],
        tags: [_tag(id: 'a')],
      );
      final cleanResult = reconcileTagIds(clean);
      expect(cleanResult.tasks.single, same(clean.tasks.single));
    });
  });

  group('§5.2 场景：文件夹 LWW 合并（folders 作为独立类型）', () {
    test('单侧新增：本地/远端各自新增文件夹 → 合并结果含全部', () {
      final local = _snapshot(
        folders: [_folder(id: 'f1', name: '本地夹', updatedAt: 100)],
      );
      final remote = _snapshot(
        folders: [_folder(id: 'f2', name: '远端夹', updatedAt: 200)],
      );

      final result = merge(
        local,
        remote,
        localDeviceId: 'dev-a',
        remoteDeviceId: 'dev-b',
      );
      expect(result.folders.map((f) => f.id), containsAll(['f1', 'f2']));
      expect(result.folders.length, 2);
    });

    test('同 id 取 updatedAt 大者（与来源设备无关）', () {
      final local = _snapshot(
        folders: [_folder(id: 'f1', name: '旧名', updatedAt: 100)],
      );
      final remote = _snapshot(
        folders: [_folder(id: 'f1', name: '新名', updatedAt: 300)],
      );

      final r1 = merge(local, remote, localDeviceId: 'a', remoteDeviceId: 'b');
      expect(r1.folders.single.name, '新名');
      expect(r1.folders.single.updatedAt, 300);

      // 与参数顺序无关：LWW 只看 updatedAt。
      final r2 = merge(remote, local, localDeviceId: 'a', remoteDeviceId: 'b');
      expect(r2.folders.single.name, '新名');
    });

    test('updatedAt 相等 → tie-break 字典序，两端算出相同 winner', () {
      final local = _snapshot(
        deviceId: 'aaa',
        folders: [_folder(id: 'f1', name: '来自aaa', updatedAt: 100)],
      );
      final remote = _snapshot(
        deviceId: 'bbb',
        folders: [_folder(id: 'f1', name: '来自bbb', updatedAt: 100)],
      );

      final fromA = merge(
        local,
        remote,
        localDeviceId: 'aaa',
        remoteDeviceId: 'bbb',
      );
      final fromB = merge(
        remote,
        local,
        localDeviceId: 'bbb',
        remoteDeviceId: 'aaa',
      );

      expect(fromA.folders.single.name, '来自bbb');
      expect(fromB.folders.single.name, '来自bbb', reason: '两端必须算出相同 winner');
    });

    test('一端删除文件夹（墓碑）→ deleted=true 传播', () {
      final local = _snapshot(
        folders: [_folder(id: 'f1', deleted: true, updatedAt: 500)],
      );
      final remote = _snapshot(
        folders: [_folder(id: 'f1', name: '旧夹', updatedAt: 100)],
      );

      final result = merge(
        local,
        remote,
        localDeviceId: 'a',
        remoteDeviceId: 'b',
      );
      expect(result.folders.single.deleted, isTrue);
      expect(result.folders.single.updatedAt, 500);
    });

    test('folders 与其他类型互不影响（四类各自独立合并）', () {
      final local = _snapshot(
        projects: [_project(id: 'p1', updatedAt: 100)],
        folders: [_folder(id: 'f1', updatedAt: 100)],
      );
      final remote = _snapshot(
        tasks: [_task(id: 't1', projectId: 'p1', updatedAt: 200)],
        folders: [_folder(id: 'f2', updatedAt: 200)],
      );

      final result = merge(
        local,
        remote,
        localDeviceId: 'a',
        remoteDeviceId: 'b',
      );
      expect(result.projects.single.id, 'p1');
      expect(result.tasks.single.id, 't1');
      expect(result.folders.map((f) => f.id), containsAll(['f1', 'f2']));
    });
  });

  group('§5.2 场景：reconcileFolderIds 悬空文件夹引用清理', () {
    test('folderId 指向不存在或 deleted=true 文件夹 → 置 null（回未分组）', () {
      final merged = _snapshot(
        projects: [
          _project(id: 'p-live', folderId: 'f-live', updatedAt: 100),
          _project(id: 'p-deleted', folderId: 'f-deleted', updatedAt: 100),
          _project(id: 'p-missing', folderId: 'f-missing', updatedAt: 100),
          _project(id: 'p-none', folderId: null, updatedAt: 100),
        ],
        folders: [
          _folder(id: 'f-live', updatedAt: 100),
          _folder(id: 'f-deleted', deleted: true, updatedAt: 200), // 墓碑
          // 无 f-missing。
        ],
      );

      final result = reconcileFolderIds(merged);

      final byId = {for (final p in result.projects) p.id: p.folderId};
      expect(byId, {
        'p-live': 'f-live', // 存活文件夹 → 保留
        'p-deleted': null, // 已删文件夹 → 置 null
        'p-missing': null, // 不存在文件夹 → 置 null
        'p-none': null, // 本就 null → 不变
      });
      // folders 原样保留。
      expect(result.folders, same(merged.folders));
    });

    test('reconcileFolderIds 纯函数：返回新对象、不修改入参；无悬空时复用原记录', () {
      final project = _project(id: 'p1', folderId: 'f-gone');
      final merged = _snapshot(projects: [project], folders: []);

      final result = reconcileFolderIds(merged);

      expect(result.projects.single.folderId, isNull);
      expect(
        identical(result.projects.single, project),
        isFalse,
        reason: '清理后必须返回新 ProjectRecord',
      );
      expect(project.folderId, 'f-gone', reason: '入参不得被修改');
      expect(identical(result, merged), isFalse);

      // 无悬空引用时复用原记录（无谓拷贝应避免）。
      final clean = _snapshot(
        projects: [_project(id: 'p2', folderId: 'f-live')],
        folders: [_folder(id: 'f-live')],
      );
      final cleanResult = reconcileFolderIds(clean);
      expect(cleanResult.projects.single, same(clean.projects.single));
    });

    test('merge 结果同时清理悬空 tagIds 与 folderId（reconcile 组合不丢字段）', () {
      final local = _snapshot(
        projects: [
          _project(id: 'p1', folderId: 'f-live', updatedAt: 100),
          _project(id: 'p2', folderId: 'f-gone', updatedAt: 100),
        ],
        tasks: [
          _task(id: 't1', projectId: 'p1', tagIds: ['tag-live', 'tag-gone']),
        ],
        tags: [_tag(id: 'tag-live')],
        folders: [_folder(id: 'f-live')],
      );
      final remote = _snapshot();

      final result = merge(
        local,
        remote,
        localDeviceId: 'a',
        remoteDeviceId: 'b',
      );

      expect(result.tasks.single.tagIds, ['tag-live'], reason: 'tagIds 悬空被清理');
      final p2 = result.projects.singleWhere((p) => p.id == 'p2');
      expect(p2.folderId, isNull, reason: 'folderId 悬空被清理');
      expect(result.folders.single.id, 'f-live', reason: 'folders 字段不丢失');
      expect(
        result.projects.singleWhere((p) => p.id == 'p1').folderId,
        'f-live',
        reason: '存活引用保留',
      );
    });
  });

  group('额外边界', () {
    test('跨类型互不影响（三类各自独立合并）', () {
      final local = _snapshot(
        projects: [_project(id: 'p1', updatedAt: 100)],
        tags: [_tag(id: 'tag1', updatedAt: 100)],
      );
      final remote = _snapshot(
        tasks: [_task(id: 't1', projectId: 'p1', updatedAt: 200)],
      );

      final result = merge(
        local,
        remote,
        localDeviceId: 'a',
        remoteDeviceId: 'b',
      );
      expect(result.projects.single.id, 'p1');
      expect(result.tags.single.id, 'tag1');
      expect(result.tasks.single.id, 't1');
    });

    test('两个空快照合并 → 空结果，不崩溃', () {
      final result = merge(
        _snapshot(),
        _snapshot(),
        localDeviceId: 'a',
        remoteDeviceId: 'b',
      );
      expect(result.projects, isEmpty);
      expect(result.tasks, isEmpty);
      expect(result.tags, isEmpty);
      expect(result.schemaVersion, 1);
    });

    test('合并结果保留本地 schemaVersion/deviceId/exportedAt', () {
      final local = _snapshot(deviceId: 'dev-local', exportedAt: 777);
      final remote = _snapshot(deviceId: 'dev-remote', exportedAt: 888);

      final result = merge(
        local,
        remote,
        localDeviceId: 'dev-local',
        remoteDeviceId: 'dev-remote',
      );
      expect(result.deviceId, 'dev-local');
      expect(result.exportedAt, 777);
      expect(result.schemaVersion, 1);
    });

    test('merge 纯函数：不修改入参快照', () {
      final local = _snapshot(
        projects: [_project(id: 'p1', name: 'A', updatedAt: 100)],
      );
      final remote = _snapshot(
        projects: [_project(id: 'p1', name: 'B', updatedAt: 200)],
      );

      final before = local.toJson();
      merge(local, remote, localDeviceId: 'a', remoteDeviceId: 'b');

      expect(local.toJson(), equals(before), reason: 'local 入参不得被修改');
      expect(remote.projects.single.name, 'B', reason: 'remote 入参不得被修改');
    });

    test('多记录合并：各自独立按 id 决出 winner，互不干扰', () {
      final local = _snapshot(
        projects: [
          _project(id: 'p1', name: 'A1', updatedAt: 100),
          _project(id: 'p2', name: 'A2', updatedAt: 300),
        ],
      );
      final remote = _snapshot(
        projects: [
          _project(id: 'p1', name: 'B1', updatedAt: 200), // 远端新 → 远端胜
          _project(id: 'p2', name: 'B2', updatedAt: 100), // 本地新 → 本地胜
          _project(id: 'p3', name: 'B3', updatedAt: 50), // 仅远端 → 新增
        ],
      );

      final result = merge(
        local,
        remote,
        localDeviceId: 'a',
        remoteDeviceId: 'b',
      );
      final byId = {for (final p in result.projects) p.id: p.name};
      expect(byId, {'p1': 'B1', 'p2': 'A2', 'p3': 'B3'});
    });
  });

  group('自定义视图 LWW 合并与 reconcileCustomViews', () {
    test('自定义视图 LWW 合并：按 updatedAt 决出 winner', () {
      final local = _snapshot(
        customViews: [
          _customView(id: 'cv1', name: '本地旧视图', updatedAt: 100),
          _customView(id: 'cv2', name: '本地新视图', updatedAt: 300),
        ],
      );
      final remote = _snapshot(
        customViews: [
          _customView(id: 'cv1', name: '远端新视图', updatedAt: 200),
          _customView(id: 'cv2', name: '远端旧视图', updatedAt: 100),
          _customView(id: 'cv3', name: '远端独有视图', updatedAt: 150),
        ],
      );

      final result = merge(
        local,
        remote,
        localDeviceId: 'a',
        remoteDeviceId: 'b',
      );

      final byId = {for (final cv in result.customViews) cv.id: cv.name};
      expect(byId, {'cv1': '远端新视图', 'cv2': '本地新视图', 'cv3': '远端独有视图'});
    });

    test('reconcileCustomViews 清理已删项目、标签与文件夹引用', () {
      final merged = _snapshot(
        projects: [
          _project(id: 'p1', name: '存活项目', deleted: false),
          _project(id: 'p2', name: '已删项目', deleted: true),
        ],
        tags: [
          _tag(id: 't1', name: '存活标签', deleted: false),
          _tag(id: 't2', name: '已删标签', deleted: true),
        ],
        folders: [
          _folder(id: 'f1', name: '存活文件夹', deleted: false),
          _folder(id: 'f2', name: '已删文件夹', deleted: true),
        ],
        customViews: [
          _customView(
            id: 'cv1',
            panelsJson: '''
[
  {
    "id": "panel-1",
    "title": "面板1",
    "filter": {
      "folderIds": ["f1", "f2", "unassigned"],
      "projectIds": ["p1", "p2"],
      "tagIds": ["t1", "t2"]
    }
  }
]
''',
          ),
        ],
      );

      final reconciled = reconcileCustomViews(merged);
      expect(reconciled.customViews.length, 1);
      final cv = reconciled.customViews.first;
      expect(cv.panelsJson.contains('"f2"'), isFalse);
      expect(cv.panelsJson.contains('"f1"'), isTrue);
      expect(cv.panelsJson.contains('"unassigned"'), isTrue);
      expect(cv.panelsJson.contains('"p2"'), isFalse);
      expect(cv.panelsJson.contains('"p1"'), isTrue);
      expect(cv.panelsJson.contains('"t2"'), isFalse);
      expect(cv.panelsJson.contains('"t1"'), isTrue);
    });
  });
}
