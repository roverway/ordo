import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:drift/drift.dart';

import '../daos/project_dao.dart';
import '../daos/settings_dao.dart';
import '../daos/tag_dao.dart';
import '../daos/task_dao.dart';
import '../database.dart';
import '../tables.dart';
import '../../utils/tree.dart';
import '../../utils/uuid.dart';

/// 内置收件箱项目固定 id（产品决策 #3：未选项目的任务落入收件箱）。
const String inboxProjectId = 'inbox';

/// 内置收件箱项目颜色（设计常量，颜色不入 ARB，AGENTS.md §3-8）。
const int inboxProjectColor = 0xFF6C5CE7;

/// Repository 领域异常。
class RepositoryException implements Exception {
  RepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

// ─────────────────────────── 墓碑（40-data-model §7 / 60-sync-design §8） ─────
//
// 本地 DB 不保留已删行（删除即物理硬删），删除通过**墓碑集合**传播到远端：
// - 墓碑集合持久化在 settings 表，key = `sync_tombstones`（值 = JSON 数组）；
// - 条目格式 `{"type":"project"|"task"|"tag","id":"...","updatedAt":<UTC ms>}`，
//   与 lib/core/sync 侧（SyncSettingsKeys.tombstones）约定一致；
// - Repository 层不 import lib/core/sync/（避免反向依赖，docs/30-architecture
//   §1），故此处用私有常量维护 key 字符串（值必须与 SyncSettingsKeys.tombstones
//   相同）；SyncEngine 导出快照时把墓碑并入为 deleted=true 记录（D1）。

/// 墓碑集合 settings key（与 SyncSettingsKeys.tombstones 约定一致）。
const String _kSyncTombstonesKey = 'sync_tombstones';

/// 墓碑条目类型（快照层字段 type 的取值）。
const String _kTombstoneTypeProject = 'project';
const String _kTombstoneTypeTask = 'task';
const String _kTombstoneTypeTag = 'tag';

/// 墓碑条目（docs/40-data-model.md §7 / 60-sync-design.md §8）。
///
/// type ∈ project/task/tag；id 为被删记录 UUID；updatedAt 为删除时刻
/// （UTC 毫秒，LWW 依据）。序列化格式与 SyncEngine 侧约定一致。
class TombstoneEntry {
  const TombstoneEntry({
    required this.type,
    required this.id,
    required this.updatedAt,
  });

  /// 类型：project / task / tag。
  final String type;

  /// 被删记录 UUID。
  final String id;

  /// 删除时刻（UTC 毫秒）。
  final int updatedAt;

  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'updatedAt': updatedAt,
  };

  /// 崩溃安全解析：类型异常字段回退默认值。
  factory TombstoneEntry.fromJson(Map<String, dynamic> json) {
    return TombstoneEntry(
      type: json['type'] is String ? json['type'] as String : '',
      id: json['id'] is String ? json['id'] as String : '',
      updatedAt: json['updatedAt'] is num
          ? (json['updatedAt'] as num).toInt()
          : 0,
    );
  }
}

/// 全量导出数据（DB 活跃行，docs/60-sync-design.md §3 快照来源）。
///
/// Repository 层只暴露纯 DB 数据类型，由 SyncEngine 组装 SnapshotData
/// （D2：Repository 不 import lib/core/sync/）。
class RepositoryExportData {
  const RepositoryExportData({
    this.projects = const [],
    this.tasks = const [],
    this.tags = const [],
    this.taskTagIds = const {},
  });

  /// 全部活跃项目（deleted=0）。
  final List<Project> projects;

  /// 全部活跃任务（deleted=0）。
  final List<Task> tasks;

  /// 全部活跃标签（deleted=0）。
  final List<Tag> tags;

  /// 每任务当前关联的 tagId 列表（task_tags 联表，不参与同步、快照内嵌）。
  final Map<String, List<String>> taskTagIds;
}

/// 合并结果应用操作（docs/60-sync-design.md §4 应用规则 / D2）。
///
/// 单事务内应用：deleted=true → 物理硬删（DB 本就不保留墓碑行，这里兜底）；
/// 其余 → upsert（快照 updatedAt 为权威值，不覆盖为当前时间）；taskTagIds
/// 全量重建 task_tags 联表。
class MergedApplyOperation {
  const MergedApplyOperation({
    this.upsertProjects = const [],
    this.upsertTasks = const [],
    this.upsertTags = const [],
    this.hardDeleteProjectIds = const [],
    this.hardDeleteTaskIds = const [],
    this.hardDeleteTagIds = const [],
    this.taskTagLinks = const {},
  });

  final List<Project> upsertProjects;
  final List<Task> upsertTasks;
  final List<Tag> upsertTags;
  final List<String> hardDeleteProjectIds;
  final List<String> hardDeleteTaskIds;
  final List<String> hardDeleteTagIds;

  /// taskId → tagId 列表，全量重建（先删该 task 的所有关联再批量插入）。
  final Map<String, List<String>> taskTagLinks;
}

/// 当前 UTC 毫秒（docs/40-data-model.md §4）。
int _nowMs() => DateTime.now().toUtc().millisecondsSinceEpoch;

/// 数据层唯一写入口（docs/30-architecture.md §3）。
///
/// - 所有写操作统一更新 `updatedAt`（UTC 毫秒）。
/// - 级联删除/移动均在同一事务内完成。
/// - 校验（深度/防环/排序一致性）在写前强制，失败抛 [RepositoryException]。
class TodoRepository {
  TodoRepository({AppDatabase? database})
    : database = database ?? AppDatabase.open();

  final AppDatabase database;

  late final ProjectDao projects = ProjectDao(database);
  late final TaskDao tasks = TaskDao(database);
  late final TagDao tags = TagDao(database);
  late final SettingsDao settings = SettingsDao(database);

  /// 数据变更回调（编辑自动同步接线，FR-SYNC-02 / docs/60-sync-design.md §10.2）。
  ///
  /// - **仅用户写操作**触发（create/update/move/delete 各实体）；同步内部写入
  ///   （applyMerged / mergeTombstones / pruneTombstones）**绝不**触发
  ///   （避免 同步→编辑→同步 死循环）；
  /// - 非 final 可变字段：由装配层（main.dart）在 ProviderContainer 创建后
  ///   手工赋值 `onDataChanged = syncTriggers.onEdit`，避免 Repository ↔
  ///   sync 层 Provider 循环依赖（docs/30-architecture §1：Repository 不
  ///   import lib/core/sync/，本回调只是普通函数类型）；
  /// - 写方法在**事务提交后** await 回调（不阻塞事务本身）。
  Future<void> Function()? onDataChanged;

  // ─────────────────────────── Projects ───────────────────────────

  /// 新建项目（name 1–100 字符；description 最多 500 字符；sortOrder 自动追加到末尾）。
  Future<Project> createProject({
    required String name,
    required int color,
    String description = '',
  }) async {
    _checkTextLength(name, 1, 100, '项目名');
    _checkTextLength(description, 0, 500, '项目描述');
    final now = _nowMs();
    final project = ProjectsCompanion.insert(
      id: newUuid(),
      name: name,
      color: color,
      description: Value(description),
      sortOrder: await _nextProjectSortOrder(),
      createdAt: now,
      updatedAt: now,
    );
    await projects.insert(project);
    await onDataChanged?.call();
    return (await projects.getById(project.id.value))!;
  }

  /// 更新项目（name/color/description），统一刷新 updatedAt。
  Future<void> updateProject(
    String id, {
    String? name,
    int? color,
    String? description,
  }) async {
    final existing = await projects.getById(id);
    if (existing == null) throw RepositoryException('项目不存在：$id');
    final entry = ProjectsCompanion(
      name: name != null
          ? Value(_checkTextLength(name, 1, 100, '项目名'))
          : const Value.absent(),
      color: color != null ? Value(color) : const Value.absent(),
      description: description != null
          ? Value(_checkTextLength(description, 0, 500, '项目描述'))
          : const Value.absent(),
      updatedAt: Value(_nowMs()),
    );
    await projects.updateById(id, entry);
    await onDataChanged?.call();
  }

  /// 项目排序移动：[newIndex] 为最终列表中的位置（0-based）。
  Future<void> moveProject(String id, int newIndex) async {
    await database.transaction(() async {
      final all = await projects.getAll();
      final index = all.indexWhere((p) => p.id == id);
      if (index < 0) throw RepositoryException('项目不存在：$id');
      final list = [...all]..removeAt(index);
      final clamped = newIndex.clamp(0, list.length);
      list.insert(clamped, all[index]);
      final now = _nowMs();
      for (var i = 0; i < list.length; i++) {
        final p = list[i];
        if (p.sortOrder == i) continue;
        await projects.updateById(
          p.id,
          ProjectsCompanion(sortOrder: Value(i), updatedAt: Value(now)),
        );
      }
    });
    await onDataChanged?.call();
  }

  /// 确保内置收件箱项目存在（幂等，产品决策 #3）。
  ///
  /// - 行不存在 → 新建（id 固定为 [inboxProjectId]，sortOrder 置 0 置顶）；
  /// - 行存在且未删除（deleted=0）→ 直接跳过，**不强制改名**（用户手动改名尊重保留）；
  /// - 行存在但已删除（deleted=1，同步墓碑）→ 恢复：deleted=0 并刷新名称/颜色，
  ///   保留原有 sortOrder（避免与其他项目撞序）。
  ///
  /// [displayName] 为收件箱展示名（ARB 文案），由 UI/Provider 层传入；
  /// Repository 不依赖 BuildContext/l10n。
  Future<Project> ensureInboxProject(String displayName) async {
    _checkTextLength(displayName, 1, 100, '收件箱名称');
    final existing = await projects.getById(inboxProjectId);
    final now = _nowMs();
    if (existing == null) {
      await projects.insert(
        ProjectsCompanion.insert(
          id: inboxProjectId,
          name: displayName,
          color: inboxProjectColor,
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await onDataChanged?.call();
    } else if (existing.deleted != 0) {
      // 同步墓碑恢复：仅当行被标记删除时重建展示内容，保留 sortOrder。
      await projects.updateById(
        inboxProjectId,
        ProjectsCompanion(
          name: Value(displayName),
          color: Value(inboxProjectColor),
          deleted: const Value(0),
          updatedAt: Value(now),
        ),
      );
      await onDataChanged?.call();
    }
    return (await projects.getById(inboxProjectId))!;
  }

  /// 删除项目：级联硬删其下全部任务（含子树）与关联 task_tags，同一事务。
  ///
  /// 同步行为（40-data-model.md §7）：被删项目与其下每任务各写一条墓碑
  /// （settings `sync_tombstones`），供快照导出传播删除。
  Future<void> deleteProject(String id) async {
    await database.transaction(() async {
      final existing = await projects.getById(id);
      if (existing == null) throw RepositoryException('项目不存在：$id');

      final allTasks = await tasks.getAllByProject(id);
      final ids = allTasks.map((t) => t.id).toList();
      await tags.deleteTaskTagsForTasks(ids);
      await tasks.deleteManyByIds(ids);
      await projects.deleteById(id);

      final now = _nowMs();
      await _appendTombstones([
        TombstoneEntry(type: _kTombstoneTypeProject, id: id, updatedAt: now),
        for (final t in allTasks)
          TombstoneEntry(type: _kTombstoneTypeTask, id: t.id, updatedAt: now),
      ]);
    });
    await onDataChanged?.call();
  }

  // ───────────────────────────── Tasks ─────────────────────────────

  /// 新建任务。
  ///
  /// - [projectId] 缺省时默认落入内置收件箱（产品决策 #3）。若收件箱行缺失/为
  ///   墓碑且未传 [inboxDisplayName]，将抛出 [RepositoryException]（展示名须由
  ///   调用方从 ARB 提供，Repository 不做 i18n）。
  /// - [parentId] 非空时校验父任务存在且 `depth(parent) < 3`（§5.1）。
  /// - [endAt] 设置时要求 `endAt >= startAt`（§5.4）。
  /// - [priority] 缺省为无优先级（滴答式 4 档，§3.2）。
  Future<Task> createTask({
    String? projectId,
    String? inboxDisplayName,
    String? parentId,
    required String title,
    String description = '',
    String notes = '',
    int? startAt,
    int? endAt,
    TaskStatus status = TaskStatus.todo,
    TaskPriority priority = TaskPriority.none,
  }) async {
    _checkTextLength(title, 1, 200, '任务标题');
    _checkTimeRange(startAt, endAt);

    // 未指定项目 → 收件箱（自动 ensure，幂等）。
    final effectiveProjectId = await _resolveTaskProjectId(
      projectId,
      inboxDisplayName,
    );

    final project = await projects.getById(effectiveProjectId);
    if (project == null) {
      throw RepositoryException('项目不存在：$effectiveProjectId');
    }

    final now = _nowMs();
    if (parentId != null) {
      final parent = await tasks.getActiveById(parentId);
      if (parent == null) throw RepositoryException('父任务不存在：$parentId');
      if (parent.projectId != effectiveProjectId) {
        throw RepositoryException('父任务不属于该项目');
      }
      final siblings = await tasks.getDirectChildren(
        effectiveProjectId,
        parentId,
      );
      final parentDepth = depthOf(
        parent,
        indexTasksById(await tasks.getAllByProject(effectiveProjectId)),
      );
      if (parentDepth >= 3) {
        throw RepositoryException('超过 3 级层级上限，无法创建子任务');
      }
      final task = TasksCompanion.insert(
        id: newUuid(),
        projectId: effectiveProjectId,
        parentId: Value(parentId),
        title: title,
        description: Value(description),
        notes: Value(notes),
        startAt: Value(startAt),
        endAt: Value(endAt),
        status: status,
        priority: Value(priority),
        sortOrder: siblings.length,
        createdAt: now,
        updatedAt: now,
      );
      await tasks.insert(task);
      await onDataChanged?.call();
      return (await tasks.getById(task.id.value))!;
    }

    // 1 级任务。
    final roots = await tasks.getDirectChildren(effectiveProjectId, null);
    final task = TasksCompanion.insert(
      id: newUuid(),
      projectId: effectiveProjectId,
      title: title,
      description: Value(description),
      notes: Value(notes),
      startAt: Value(startAt),
      endAt: Value(endAt),
      status: status,
      priority: Value(priority),
      sortOrder: roots.length,
      createdAt: now,
      updatedAt: now,
    );
    await tasks.insert(task);
    await onDataChanged?.call();
    return (await tasks.getById(task.id.value))!;
  }

  /// 更新任务字段（只更新传入项），统一刷新 updatedAt。
  ///
  /// 状态仅在任务**无子任务**时允许修改（有子任务状态由子任务派生，
  /// AGENTS.md §3-2）。
  Future<void> updateTask(
    String id, {
    String? title,
    String? description,
    String? notes,
    int? startAt,
    int? endAt,
    TaskStatus? status,
    TaskPriority? priority,
  }) async {
    final existing = await tasks.getActiveById(id);
    if (existing == null) throw RepositoryException('任务不存在：$id');

    if (title != null) _checkTextLength(title, 1, 200, '任务标题');
    if (status != null) {
      final children = await tasks.getDirectChildren(existing.projectId, id);
      if (children.isNotEmpty) {
        throw RepositoryException('有子任务的任务状态由子任务派生，不可手动修改');
      }
    }
    final effectiveStart = startAt ?? existing.startAt;
    final effectiveEnd = endAt ?? existing.endAt;
    _checkTimeRange(effectiveStart, effectiveEnd);

    final entry = TasksCompanion(
      title: title != null ? Value(title) : const Value.absent(),
      description: description != null
          ? Value(description)
          : const Value.absent(),
      notes: notes != null ? Value(notes) : const Value.absent(),
      startAt: Value(startAt),
      endAt: Value(endAt),
      status: status != null ? Value(status) : const Value.absent(),
      priority: priority != null ? Value(priority) : const Value.absent(),
      updatedAt: Value(_nowMs()),
    );
    await tasks.updateById(id, entry);
    await onDataChanged?.call();
  }

  /// 移动任务：[newParentId] 为 null 表示提升为 1 级任务。
  ///
  /// 校验（§5）：
  /// - 防环：目标不得是节点自身或其后代（§5.2）；
  /// - 深度：`depthOf(target) + subtreeDepthOf(node) <= 3`（§5.1）；
  /// - 同一事务内更新 parentId + 重排新旧两组 sortOrder（§5.3）。
  Future<void> moveTask(
    String taskId, {
    String? newParentId,
    required int newIndex,
  }) async {
    await database.transaction(() async {
      final task = await tasks.getActiveById(taskId);
      if (task == null) throw RepositoryException('任务不存在：$taskId');

      final all = await tasks.getAllByProject(task.projectId);
      final byId = indexTasksById(all);
      final childrenIndex = indexChildrenByParent(all);

      if (newParentId == taskId) {
        throw RepositoryException('不能移动到自身');
      }
      if (newParentId != null) {
        final parent = byId[newParentId];
        if (parent == null) throw RepositoryException('父任务不存在：$newParentId');
        if (parent.projectId != task.projectId) {
          throw RepositoryException('不能移动到其他项目的任务下');
        }
        if (isDescendantOf(parent, task, byId)) {
          throw RepositoryException('不能移动到自身的子任务下（防环）');
        }
        final targetDepth = depthOf(parent, byId);
        final nodeSubtree = subtreeDepthOf(task, childrenIndex);
        if (targetDepth + nodeSubtree > 3) {
          throw RepositoryException('移动后层级超过 3 级上限');
        }
      } else {
        // 提升为 1 级：depth(target)=0，subtreeDepth 必然 ≤3，无需额外校验。
      }

      // 新旧两组（newParentId 等于当前父级时为纯重排）。
      final oldGroup =
          childrenIndex[task.parentId]?.where((t) => t.id != taskId).toList() ??
          <Task>[];
      final newGroup =
          childrenIndex[newParentId]?.where((t) => t.id != taskId).toList() ??
          <Task>[];
      oldGroup.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      newGroup.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      // 无父任务 → 新父级列表用 1 级任务（排序同源，重排即可）。
      final targetGroup = List<Task>.of(newGroup);
      final index = newIndex.clamp(0, targetGroup.length);
      targetGroup.insert(index, task);

      final now = _nowMs();

      // 写节点本身（parentId + 新 sortOrder + updatedAt）。
      await tasks.updateById(
        taskId,
        TasksCompanion(
          parentId: Value(newParentId),
          sortOrder: Value(index),
          updatedAt: Value(now),
        ),
      );

      // 重排新组（节点自身已更新，跳过）。
      for (var i = 0; i < targetGroup.length; i++) {
        final t = targetGroup[i];
        if (t.id == taskId || t.sortOrder == i) continue;
        await tasks.updateById(
          t.id,
          TasksCompanion(sortOrder: Value(i), updatedAt: Value(now)),
        );
      }

      // 重排旧组（新组与旧组为同一组时跳过）。
      if (task.parentId != newParentId) {
        for (var i = 0; i < oldGroup.length; i++) {
          final t = oldGroup[i];
          if (t.sortOrder == i) continue;
          await tasks.updateById(
            t.id,
            TasksCompanion(sortOrder: Value(i), updatedAt: Value(now)),
          );
        }
      }
    });
    await onDataChanged?.call();
  }

  /// 收件箱项目下全部未删除任务（扁平列表，含 1 级与子树），按 sortOrder 升序。
  ///
  /// 首页目前展示 1 级任务列表 + 完成勾选；子树任务一并返回，UI 层按需过滤。
  /// 收件箱行需先经 [ensureInboxProject] 确保存在（Provider 层负责）。
  Stream<List<Task>> watchInboxTasks() => tasks.watchByProject(inboxProjectId);

  /// 删除任务：级联硬删所有后代（含自身）+ 关联 task_tags，同一事务。
  ///
  /// 同步行为（40-data-model.md §7）：被删任务（含后代）各写一条墓碑。
  Future<void> deleteTask(String taskId) async {
    await database.transaction(() async {
      final task = await tasks.getActiveById(taskId);
      if (task == null) throw RepositoryException('任务不存在：$taskId');

      final all = await tasks.getAllByProject(task.projectId);
      final childrenIndex = indexChildrenByParent(all);
      final subtreeIds = <String>[];
      void collect(String id) {
        subtreeIds.add(id);
        for (final child in childrenIndex[id] ?? const <Task>[]) {
          collect(child.id);
        }
      }

      collect(taskId);
      await tags.deleteTaskTagsForTasks(subtreeIds);
      await tasks.deleteManyByIds(subtreeIds);

      final now = _nowMs();
      await _appendTombstones([
        for (final id in subtreeIds)
          TombstoneEntry(type: _kTombstoneTypeTask, id: id, updatedAt: now),
      ]);
    });
    await onDataChanged?.call();
  }

  // ────────────────────────────── Tags ──────────────────────────────

  /// 新建标签（name 不区分大小写唯一，§5.4）。
  Future<Tag> createTag({required String name, required int color}) async {
    _checkTextLength(name, 1, 50, '标签名');
    final existing = await tags.getByName(name);
    if (existing != null) throw RepositoryException('标签名已存在（不区分大小写）：$name');
    final now = _nowMs();
    final all = await tags.getAll();
    final tag = TagsCompanion.insert(
      id: newUuid(),
      name: name,
      color: color,
      sortOrder: all.length,
      createdAt: now,
      updatedAt: now,
    );
    await tags.insert(tag);
    await onDataChanged?.call();
    return (await tags.getById(tag.id.value))!;
  }

  /// 更新标签（name/color）。
  Future<void> updateTag(String id, {String? name, int? color}) async {
    final existing = await tags.getById(id);
    if (existing == null) throw RepositoryException('标签不存在：$id');
    if (name != null) {
      _checkTextLength(name, 1, 50, '标签名');
      final dup = await tags.getByName(name);
      if (dup != null && dup.id != id) {
        throw RepositoryException('标签名已存在（不区分大小写）：$name');
      }
    }
    await tags.updateById(
      id,
      TagsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        color: color != null ? Value(color) : const Value.absent(),
        updatedAt: Value(_nowMs()),
      ),
    );
    await onDataChanged?.call();
  }

  /// 删除标签：硬删标签 + 删除 task_tags 引用行（任务保留，§7）。
  ///
  /// 同步行为（40-data-model.md §7）：写标签墓碑；合并后 reconciliation
  /// 清理悬空 tagIds（60-sync-design.md §7）。
  Future<void> deleteTag(String id) async {
    await database.transaction(() async {
      final existing = await tags.getById(id);
      if (existing == null) throw RepositoryException('标签不存在：$id');
      await tags.deleteTaskTagsForTag(id);
      await tags.deleteById(id);
      await _appendTombstones([
        TombstoneEntry(type: _kTombstoneTypeTag, id: id, updatedAt: _nowMs()),
      ]);
    });
    await onDataChanged?.call();
  }

  // ───────────────────────── 墓碑集合（同步引擎 D1/D2） ───────────────────────

  /// 读取墓碑集合（settings `sync_tombstones`，崩溃安全：非 JSON/损坏视为空）。
  Future<List<TombstoneEntry>> readTombstones() async {
    final raw = await settings.get(_kSyncTombstonesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(TombstoneEntry.fromJson)
          .where((e) => e.id.isNotEmpty)
          .toList();
    } on FormatException {
      return const [];
    }
  }

  /// 合并墓碑条目（(type,id) 去重、取最大 updatedAt），幂等。事务内完成。
  ///
  /// 供 SyncEngine 应用合并结果后调用：merge 结果中 deleted=true 的墓碑
  /// 保留/更新进本地墓碑集合（要传播给远端，D1）。
  Future<void> mergeTombstones(Iterable<TombstoneEntry> entries) async {
    await database.transaction(() async {
      await _mergeTombstonesInner(entries);
    });
  }

  /// 清理 updatedAt 早于 [olderThan]（UTC 毫秒）的墓碑（60-sync-design §8：
  /// >90 天清理；清理仅影响墓碑集合，不影响本地 DB 与远端）。
  Future<void> pruneTombstones(int olderThan) async {
    await database.transaction(() async {
      final kept = (await readTombstones())
          .where((e) => e.updatedAt >= olderThan)
          .toList();
      await _writeTombstones(kept);
    });
  }

  /// 全量导出活跃数据（docs/60-sync-design.md §3 / D2）。
  ///
  /// 返回全部活跃（deleted=0）projects/tasks/tags + 每 task 的 tagIds 映射；
  /// 由 SyncEngine 组装 SnapshotData（含墓碑集合并入）。Repository 层不
  /// import lib/core/sync/，此处只暴露纯 DB 数据类型。
  Future<RepositoryExportData> exportAll() async {
    final projects = await this.projects.getAll();
    final tasks = await this.tasks.getAllActive();
    final tags = await this.tags.getAll();
    final taskTagIds = <String, List<String>>{};
    for (final t in tasks) {
      taskTagIds[t.id] = await this.tags.tagIdsForTask(t.id);
    }
    return RepositoryExportData(
      projects: projects,
      tasks: tasks,
      tags: tags,
      taskTagIds: taskTagIds,
    );
  }

  /// 单事务应用合并结果（docs/60-sync-design.md §4 应用规则 / D2）。
  ///
  /// - upsert：按 id 存在则更新、不存在则插入；**updatedAt 以快照值为权威**，
  ///   绝不覆盖为当前时间（LWW 依赖，40-data-model.md §4）；
  /// - hardDelete：物理删除兜底（DB 本就不保留墓碑行）；
  /// - taskTagLinks：先删该 task 的全部关联再批量插入（全量重建）。
  ///
  /// 防御性过滤：引用已删/不存在项目或标签的悬空记录在事务内剔除
  /// （reconcileTagIds 只清理 tagIds，不清理 projectId，见 60-sync-design §7）。
  Future<void> applyMerged(MergedApplyOperation ops) async {
    await database.transaction(() async {
      // 1. 项目/标签先写（task 与 task_tags 有外键依赖）。
      for (final p in ops.upsertProjects) {
        await database
            .into(database.projects)
            .insertOnConflictUpdate(p.toCompanion(false));
      }
      for (final t in ops.upsertTags) {
        await database
            .into(database.tags)
            .insertOnConflictUpdate(t.toCompanion(false));
      }

      // 2. 有效项目集合（upsert 的 + 库中已有的）→ 过滤悬空任务的 projectId。
      final validProjectIds = <String>{
        for (final p in ops.upsertProjects) p.id,
        for (final p in await projects.getAll()) p.id,
      };
      // 3. 有效标签集合（upsert 的 + 库中已有的）→ 过滤悬空 tagId 引用。
      final validTagIds = <String>{
        for (final t in ops.upsertTags) t.id,
        for (final t in await tags.getAll()) t.id,
      };

      for (final t in ops.upsertTasks) {
        if (!validProjectIds.contains(t.projectId)) {
          // 项目已被删除（LWW 墓碑胜）而任务被另一端更晚修改的边缘情形：
          // 项目删除语义级联其下任务，故丢弃该悬空任务而非插入触发外键失败。
          debugPrint('sync: 丢弃悬空任务 ${t.id}（项目 ${t.projectId} 不存在）');
          continue;
        }
        await database
            .into(database.tasks)
            .insertOnConflictUpdate(t.toCompanion(false));
      }

      // 4. task_tags 全量重建（仅对实际 upsert 的任务；tagId 过滤悬空引用）。
      final upsertedTaskIds = <String>{
        for (final t in ops.upsertTasks)
          if (validProjectIds.contains(t.projectId)) t.id,
      };
      for (final entry in ops.taskTagLinks.entries) {
        if (!upsertedTaskIds.contains(entry.key)) continue;
        await (database.delete(
          database.taskTags,
        )..where((tt) => tt.taskId.equals(entry.key))).go();
        final tagIds = entry.value.where(validTagIds.contains).toList();
        if (tagIds.isEmpty) continue;
        await database.batch((b) {
          b.insertAll(database.taskTags, [
            for (final tagId in tagIds)
              TaskTagsCompanion.insert(taskId: entry.key, tagId: tagId),
          ]);
        });
      }

      // 5. 物理硬删（先解除联表引用，再删行，顺序满足外键约束）。
      await tags.deleteTaskTagsForTasks(ops.hardDeleteTaskIds);
      await tasks.deleteManyByIds(ops.hardDeleteTaskIds);
      for (final tagId in ops.hardDeleteTagIds) {
        await tags.deleteTaskTagsForTag(tagId);
        await tags.deleteById(tagId);
      }
      for (final projectId in ops.hardDeleteProjectIds) {
        // 项目删除级联其下任务（40-data-model §7）：先清其任务与联表引用，
        // 否则 projects 外键约束会阻止删除。
        final tasksInProject = await tasks.getAllByProject(projectId);
        final ids = tasksInProject.map((t) => t.id).toList();
        await tags.deleteTaskTagsForTasks(ids);
        await tasks.deleteManyByIds(ids);
        await projects.deleteById(projectId);
      }
    });
  }

  /// 追加墓碑条目（(type,id) 去重、取最大 updatedAt）。事务内调用。
  Future<void> _appendTombstones(Iterable<TombstoneEntry> entries) =>
      _mergeTombstonesInner(entries);

  /// 合并墓碑条目核心实现（假定已在事务内）。
  Future<void> _mergeTombstonesInner(Iterable<TombstoneEntry> entries) async {
    final list = entries.toList();
    if (list.isEmpty) return;
    final existing = await readTombstones();
    final map = <String, TombstoneEntry>{
      for (final e in existing) '${e.type}:${e.id}': e,
    };
    for (final e in list) {
      final key = '${e.type}:${e.id}';
      final current = map[key];
      if (current == null || e.updatedAt > current.updatedAt) {
        map[key] = e;
      }
    }
    await _writeTombstones(map.values);
  }

  /// 整体覆盖墓碑集合。
  Future<void> _writeTombstones(Iterable<TombstoneEntry> entries) {
    return settings.set(
      _kSyncTombstonesKey,
      jsonEncode([for (final e in entries) e.toJson()]),
    );
  }

  // ───────────────────────────── 校验辅助 ─────────────────────────────

  String _checkTextLength(String value, int min, int max, String label) {
    final len = value.runes.length;
    if (len < min || len > max) {
      throw RepositoryException('$label长度需在 $min–$max 字符之间');
    }
    return value;
  }

  void _checkTimeRange(int? startAt, int? endAt) {
    if (startAt != null && endAt != null && endAt < startAt) {
      throw RepositoryException('截止时间不能早于开始时间');
    }
  }

  Future<int> _nextProjectSortOrder() async {
    final all = await projects.getAll();
    return all.isEmpty ? 0 : (all.last.sortOrder + 1);
  }

  /// 解析任务所属项目 id：未传 [projectId] 时默认内置收件箱（产品决策 #3）。
  ///
  /// - 收件箱行存在且未删除 → 直接复用其固定 id；
  /// - 收件箱行缺失或为墓碑 → 需经 [ensureInboxProject] 重建，但创建需要展示名，
  ///   Repository 不感知 l10n（AGENTS.md §3-8），故展示名由调用方传入
  ///   [inboxDisplayName]；未提供时抛出 [RepositoryException]（UI 流程应保证
  ///   通过 [inboxProjectProvider] 先行 ensure）。
  Future<String> _resolveTaskProjectId(
    String? projectId,
    String? inboxDisplayName,
  ) async {
    if (projectId != null) return projectId;
    final existing = await projects.getById(inboxProjectId);
    if (existing != null && existing.deleted == 0) return inboxProjectId;
    if (inboxDisplayName == null) {
      throw RepositoryException('收件箱项目不存在，请先调用 ensureInboxProject 创建');
    }
    return (await ensureInboxProject(inboxDisplayName)).id;
  }
}
