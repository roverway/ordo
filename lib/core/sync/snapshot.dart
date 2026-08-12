// 快照数据模型（docs/60-sync-design.md §3）。
//
// 纯 Dart 不可变数据类，字段严格对齐快照 JSON 格式（schemaVersion = 1）：
// - 时间字段一律 UTC 毫秒整数（与 DB 层一致，docs/40-data-model.md §4）；
// - deleted 在快照层为 bool（DB 层为 int 0/1）；
// - status / priority 为枚举 index（0–3，顺序即存储值，见 tables.dart 的
//   TaskStatus / TaskPriority）。
//
// fromJson/toJson 为手写映射（无代码生成）。fromJson **崩溃安全**：远端快照
// 可能来自新版本或损坏数据，未知/缺失/越界字段一律回退默认值（如 status 越界
// 回退 0、deleted 非 bool 容错、缺 tagIds 视为空）。结构级错误（非法 JSON /
// 根节点非对象 / gzip 损坏）由 snapshot_codec 层负责抛错。

/// 任务状态合法值上界（tables.dart TaskStatus 共 4 个：0–3）。
const int _kStatusMax = 3;

/// 任务优先级合法值上界（tables.dart TaskPriority 共 4 个：0–3）。
const int _kPriorityMax = 3;

/// 快照整体（§3）：schemaVersion + 设备元信息 + 三张参与同步的表。
///
/// 不可变：所有字段 final，列表字段请勿就地修改（合并引擎总是构造新对象）。
class SnapshotData {
  const SnapshotData({
    required this.schemaVersion,
    required this.deviceId,
    required this.exportedAt,
    this.projects = const [],
    this.tasks = const [],
    this.tags = const [],
  });

  /// 快照格式版本，当前为 1（§3）。合法性由 snapshot_codec 校验。
  final int schemaVersion;

  /// 导出本快照的设备 ID（UUID）。
  final String deviceId;

  /// 导出时间（UTC 毫秒），用于时钟偏差检测（§11）。
  final int exportedAt;

  /// 项目记录列表。
  final List<ProjectRecord> projects;

  /// 任务记录列表（tagIds 内嵌，§3）。
  final List<TaskRecord> tasks;

  /// 标签记录列表。
  final List<TagRecord> tags;

  /// 解析快照 JSON。字段级崩溃安全：缺失/类型异常字段回退默认值，
  /// 列表元素非对象时跳过。
  factory SnapshotData.fromJson(Map<String, dynamic> json) {
    return SnapshotData(
      schemaVersion: _readInt(json, 'schemaVersion', fallback: 0),
      deviceId: _readString(json, 'deviceId', fallback: ''),
      exportedAt: _readInt(json, 'exportedAt', fallback: 0),
      projects: _readObjectList(
        json,
        'projects',
      ).map(ProjectRecord.fromJson).toList(),
      tasks: _readObjectList(json, 'tasks').map(TaskRecord.fromJson).toList(),
      tags: _readObjectList(json, 'tags').map(TagRecord.fromJson).toList(),
    );
  }

  /// 序列化为快照 JSON（与 §3 逐字段对齐）。
  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'deviceId': deviceId,
      'exportedAt': exportedAt,
      'projects': projects.map((r) => r.toJson()).toList(),
      'tasks': tasks.map((r) => r.toJson()).toList(),
      'tags': tags.map((r) => r.toJson()).toList(),
    };
  }
}

/// 项目记录（docs/40-data-model.md §2.1，快照字段见 §3）。
class ProjectRecord {
  const ProjectRecord({
    required this.id,
    required this.name,
    required this.color,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
    this.description = '',
  });

  /// UUID。
  final String id;

  /// 项目名。
  final String name;

  /// ARGB 颜色值。
  final int color;

  /// 描述（可选，DB 默认 ''）。
  final String description;

  /// 项目间排序。
  final int sortOrder;

  /// 创建时间（UTC 毫秒）。
  final int createdAt;

  /// 更新时间（UTC 毫秒，同步字段，LWW 依据）。
  final int updatedAt;

  /// 墓碑标记（true = 已删除）。
  final bool deleted;

  factory ProjectRecord.fromJson(Map<String, dynamic> json) {
    return ProjectRecord(
      id: _readString(json, 'id', fallback: ''),
      name: _readString(json, 'name', fallback: ''),
      color: _readInt(json, 'color', fallback: 0),
      description: _readString(json, 'description', fallback: ''),
      sortOrder: _readInt(json, 'sortOrder', fallback: 0),
      createdAt: _readInt(json, 'createdAt', fallback: 0),
      updatedAt: _readInt(json, 'updatedAt', fallback: 0),
      deleted: _readBool(json, 'deleted', fallback: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'description': description,
      'sortOrder': sortOrder,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deleted': deleted,
    };
  }
}

/// 任务记录（docs/40-data-model.md §2.2，快照字段见 §3）。
///
/// 层级不存 level 字段，由 parentId 链推导；tagIds 内嵌（联表不参与同步）。
class TaskRecord {
  const TaskRecord({
    required this.id,
    required this.projectId,
    required this.title,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
    this.parentId,
    this.description = '',
    this.notes = '',
    this.startAt,
    this.endAt,
    this.status = 0,
    this.priority = 0,
    this.tagIds = const [],
  });

  /// UUID。
  final String id;

  /// 所属项目 ID。
  final String projectId;

  /// 父任务 ID（NULL = 1 级任务）。
  final String? parentId;

  /// 标题。
  final String title;

  /// 描述（纯文本 v1）。
  final String description;

  /// 备注（纯文本 v1）。
  final String notes;

  /// 开始时间（UTC 毫秒，可选）。
  final int? startAt;

  /// 截止时间（UTC 毫秒，可选）。
  final int? endAt;

  /// 状态枚举 index 0–3（§3.1）。
  final int status;

  /// 优先级枚举 index 0–3（§3.2）。
  final int priority;

  /// 同级内排序。
  final int sortOrder;

  /// 创建时间（UTC 毫秒）。
  final int createdAt;

  /// 更新时间（UTC 毫秒，同步字段，LWW 依据）。
  final int updatedAt;

  /// 墓碑标记（true = 已删除）。
  final bool deleted;

  /// 关联标签 ID 列表（§3 内嵌；合并后经 reconcileTagIds 清理悬空引用，§7）。
  final List<String> tagIds;

  factory TaskRecord.fromJson(Map<String, dynamic> json) {
    return TaskRecord(
      id: _readString(json, 'id', fallback: ''),
      projectId: _readString(json, 'projectId', fallback: ''),
      parentId: _readNullableString(json, 'parentId'),
      title: _readString(json, 'title', fallback: ''),
      description: _readString(json, 'description', fallback: ''),
      notes: _readString(json, 'notes', fallback: ''),
      startAt: _readNullableInt(json, 'startAt'),
      endAt: _readNullableInt(json, 'endAt'),
      status: _readStatus(json),
      priority: _readPriority(json),
      sortOrder: _readInt(json, 'sortOrder', fallback: 0),
      createdAt: _readInt(json, 'createdAt', fallback: 0),
      updatedAt: _readInt(json, 'updatedAt', fallback: 0),
      deleted: _readBool(json, 'deleted', fallback: false),
      tagIds: _readStringList(json, 'tagIds'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'parentId': parentId,
      'title': title,
      'description': description,
      'notes': notes,
      'startAt': startAt,
      'endAt': endAt,
      'status': status,
      'priority': priority,
      'sortOrder': sortOrder,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deleted': deleted,
      'tagIds': tagIds,
    };
  }
}

/// 标签记录（docs/40-data-model.md §2.3，快照字段见 §3）。
class TagRecord {
  const TagRecord({
    required this.id,
    required this.name,
    required this.color,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.deleted,
  });

  /// UUID。
  final String id;

  /// 标签名（不区分大小写唯一）。
  final String name;

  /// ARGB 颜色值。
  final int color;

  /// 标签间排序。
  final int sortOrder;

  /// 创建时间（UTC 毫秒）。
  final int createdAt;

  /// 更新时间（UTC 毫秒，同步字段，LWW 依据）。
  final int updatedAt;

  /// 墓碑标记（true = 已删除）。
  final bool deleted;

  factory TagRecord.fromJson(Map<String, dynamic> json) {
    return TagRecord(
      id: _readString(json, 'id', fallback: ''),
      name: _readString(json, 'name', fallback: ''),
      color: _readInt(json, 'color', fallback: 0),
      sortOrder: _readInt(json, 'sortOrder', fallback: 0),
      createdAt: _readInt(json, 'createdAt', fallback: 0),
      updatedAt: _readInt(json, 'updatedAt', fallback: 0),
      deleted: _readBool(json, 'deleted', fallback: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'sortOrder': sortOrder,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'deleted': deleted,
    };
  }
}

// ---------------------------------------------------------------------------
// 崩溃安全解析辅助函数（仅 snapshot 层内部使用）。
// ---------------------------------------------------------------------------

/// 读 int 字段：int/num 直接取整，bool 转 0/1，其余（含缺失）回退 [fallback]。
int _readInt(Map<String, dynamic> json, String key, {required int fallback}) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is bool) return value ? 1 : 0;
  return fallback;
}

/// 读可空 int 字段：null / 缺失 / 类型异常一律返回 null。
int? _readNullableInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

/// 读 bool 字段：bool 直取；int/num 按 0 假非 0 真（兼容 DB 层 0/1）；
/// 其余（含缺失）回退 [fallback]。
bool _readBool(
  Map<String, dynamic> json,
  String key, {
  required bool fallback,
}) {
  final value = json[key];
  if (value is bool) return value;
  if (value is num) return value != 0;
  return fallback;
}

/// 读 String 字段：非 String（含缺失）回退 [fallback]。
String _readString(
  Map<String, dynamic> json,
  String key, {
  required String fallback,
}) {
  final value = json[key];
  if (value is String) return value;
  return fallback;
}

/// 读可空 String 字段：非 String（含缺失）一律返回 null。
String? _readNullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  return null;
}

/// 读状态枚举 index：越界 / 缺失回退 0（与 tables.dart TaskStatusConverter 一致）。
int _readStatus(Map<String, dynamic> json) {
  final value = _readInt(json, 'status', fallback: 0);
  if (value < 0 || value > _kStatusMax) return 0;
  return value;
}

/// 读优先级枚举 index：越界 / 缺失回退 0（与 tables.dart TaskPriorityConverter 一致）。
int _readPriority(Map<String, dynamic> json) {
  final value = _readInt(json, 'priority', fallback: 0);
  if (value < 0 || value > _kPriorityMax) return 0;
  return value;
}

/// 读 String 列表：非 List（含缺失）视为空；非 String 元素丢弃。
List<String> _readStringList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) return const [];
  return value.whereType<String>().toList();
}

/// 读对象列表：非 List（含缺失）视为空；非 Map 元素丢弃。
List<Map<String, dynamic>> _readObjectList(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value is! List) return const [];
  return value.whereType<Map<String, dynamic>>().toList();
}
