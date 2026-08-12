// LWW 合并引擎（docs/60-sync-design.md §4 / §7）。
//
// 纯函数层：无 IO、无 DB、无全局状态；入参不被修改，始终返回**新对象**。
// merge / reconcileTagIds 均为顶层函数，不捕获外层上下文，可安全用于 isolate。
//
// 合并语义（§4）：
// - projects/tasks/tags 各自以 id 为 key 合并；同 id 取 updatedAt 大者；
// - updatedAt 相等时比较 (deviceId, id) 字典序取大者（两端结果一致）；
// - 合并后调用 reconcileTagIds 清理悬空标签引用（§7）。

import 'snapshot.dart';

/// 合并本地与远端快照（LWW，§4）。
///
/// [localDeviceId] / [remoteDeviceId]：本地与远端各自的设备 ID（UUID），
/// 仅用于 updatedAt 相等时的 tie-break。同一对设备两端传入的是对方的对偶
/// 参数（A 端传 (A, B)，B 端传 (B, A)），因此两端算出相同 winner。
///
/// 结果快照保留本地的 schemaVersion / deviceId / exportedAt（合并后由
/// sync_engine 重新导出上传，见 60-sync-design.md §6）；设计文档未规定
/// 结果快照的元信息取值，此处取本地值以保证纯函数确定性。
SnapshotData merge(
  SnapshotData local,
  SnapshotData remote, {
  required String localDeviceId,
  required String remoteDeviceId,
}) {
  final projects = _mergeType(
    local.projects,
    remote.projects,
    idOf: (r) => r.id,
    updatedAtOf: (r) => r.updatedAt,
    localDeviceId: localDeviceId,
    remoteDeviceId: remoteDeviceId,
  );
  final tasks = _mergeType(
    local.tasks,
    remote.tasks,
    idOf: (r) => r.id,
    updatedAtOf: (r) => r.updatedAt,
    localDeviceId: localDeviceId,
    remoteDeviceId: remoteDeviceId,
  );
  final tags = _mergeType(
    local.tags,
    remote.tags,
    idOf: (r) => r.id,
    updatedAtOf: (r) => r.updatedAt,
    localDeviceId: localDeviceId,
    remoteDeviceId: remoteDeviceId,
  );

  final merged = SnapshotData(
    schemaVersion: local.schemaVersion,
    deviceId: local.deviceId,
    exportedAt: local.exportedAt,
    projects: projects,
    tasks: tasks,
    tags: tags,
  );
  return reconcileTagIds(merged);
}

/// 清理标签孤儿引用（§7）：删除每个 task.tagIds 中指向「不存在于 tags 列表
/// 或 deleted=true」的标签的引用。
///
/// 纯函数：返回新快照；无引用需要清理时复用原对象（不产生无谓拷贝）。
SnapshotData reconcileTagIds(SnapshotData merged) {
  final aliveTagIds = <String>{
    for (final tag in merged.tags)
      if (!tag.deleted) tag.id,
  };

  final tasks = <TaskRecord>[];
  for (final task in merged.tasks) {
    final filtered = task.tagIds.where(aliveTagIds.contains).toList();
    if (filtered.length == task.tagIds.length) {
      tasks.add(task);
    } else {
      tasks.add(_withTagIds(task, filtered));
    }
  }

  return SnapshotData(
    schemaVersion: merged.schemaVersion,
    deviceId: merged.deviceId,
    exportedAt: merged.exportedAt,
    projects: merged.projects,
    tasks: tasks,
    tags: merged.tags,
  );
}

/// 按 §4 合并单一类型的两份记录列表。
///
/// 以 id 为 key：local 行先入 map，remote 行随后按 LWW 规则覆盖；
/// updatedAt 相等时经 [_tieBreak] 决出 winner。返回新列表，不修改入参。
List<R> _mergeType<R>(
  List<R> localRows,
  List<R> remoteRows, {
  required String Function(R) idOf,
  required int Function(R) updatedAtOf,
  required String localDeviceId,
  required String remoteDeviceId,
}) {
  final map = <String, R>{};
  for (final row in localRows) {
    map[idOf(row)] = row;
  }
  for (final row in remoteRows) {
    final key = idOf(row);
    final current = map[key];
    if (current == null) {
      map[key] = row;
    } else if (updatedAtOf(row) > updatedAtOf(current)) {
      map[key] = row;
    } else if (updatedAtOf(row) == updatedAtOf(current)) {
      map[key] = _tieBreak(
        current,
        row,
        localDeviceId: localDeviceId,
        remoteDeviceId: remoteDeviceId,
        idOf: idOf,
      );
    }
  }
  return map.values.toList();
}

/// §4 tie-break：updatedAt 相等时比较 (deviceId, id) 字典序，取大者。
///
/// [localRow] 视为携带 [localDeviceId]（来自本地快照或 map 中已有记录），
/// [remoteRow] 视为携带 [remoteDeviceId]。两端对偶传入设备 ID，结果一致。
R _tieBreak<R>(
  R localRow,
  R remoteRow, {
  required String localDeviceId,
  required String remoteDeviceId,
  required String Function(R) idOf,
}) {
  final deviceCmp = localDeviceId.compareTo(remoteDeviceId);
  if (deviceCmp != 0) return deviceCmp > 0 ? localRow : remoteRow;
  final idCmp = idOf(localRow).compareTo(idOf(remoteRow));
  if (idCmp != 0) return idCmp > 0 ? localRow : remoteRow;
  return localRow; // 完全相等（罕见），任取本地保证两端确定性。
}

/// 重建 [task] 的副本并替换 tagIds（供 §7 清理悬空引用）。
TaskRecord _withTagIds(TaskRecord task, List<String> tagIds) {
  return TaskRecord(
    id: task.id,
    projectId: task.projectId,
    parentId: task.parentId,
    title: task.title,
    description: task.description,
    notes: task.notes,
    startAt: task.startAt,
    endAt: task.endAt,
    status: task.status,
    priority: task.priority,
    sortOrder: task.sortOrder,
    createdAt: task.createdAt,
    updatedAt: task.updatedAt,
    deleted: task.deleted,
    tagIds: tagIds,
  );
}
